extends Node
#and manager ;)
#if i wanted permanent stuff, look into just a simple cfg file for the future


#region DataBase

signal server_maps_updated #TODO
signal players_updated
signal lobbies_updated 
signal chat_message_received(sender_id: int, message: String)
signal player_voted(lobby_id: String, sender_id: int, vote_number: String)

var Maps : Dictionary [String, PackedScene] = {
	"sb_lobby" = load("res://MapsAndGamemodes/Maps/sb_Lobby/sb_lobby.tscn"),
	"hm_home" = load("res://MultiplayerStuff/home -._-/hm_home.tscn")
} 

var Mercs : Dictionary [String, PackedScene] = {
	"default" = load("res://PlayerControllers/Mercs/Default/FirstPersonController.tscn"),
	"homebody" = load("res://PlayerControllers/Mercs/HomeBody/HomeBody.tscn")
}

var Characters : Dictionary [String, PackedScene] = {} 
var Players : Dictionary [int, Dictionary] #id, [gamertag, lobby]
var Lobbies : Dictionary[String, Array] = {} #lobbyid = [player_id, ...]

var port = 6789
var address = "localhost"
#var address = "csdev03.d.umn.edu"
#var chat 
#endregion

#region Manager
func add_player(peer_id : int): 
	Players[peer_id] = {}
	rpc("sync_players", Players)

func remove_player(peer_id : int):
	Players.erase(peer_id)
	rpc("sync_players", Players)

@rpc("authority","call_remote","reliable")
func sync_players(_players):
	Players = _players
	players_updated.emit()


func update_lobbies(_lobbies):
	rpc("sync_lobbies", _lobbies)

# "authority" means ONLY the server is allowed to trigger this on clients
@rpc("authority","call_local","reliable")
func sync_lobbies(_lobbies):
	Lobbies = _lobbies
	lobbies_updated.emit()
@rpc("any_peer", "call_remote", "reliable")
func send_chat_message(message: String):
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	var sender_lobby = ""
	
	# 1. Figure out WHICH lobby this player belongs to
	for lobby_id in Lobbies.keys():
		if sender_id in Lobbies[lobby_id]:
			sender_lobby = lobby_id
			break
			
	if sender_lobby == "":
		printerr("Player ", sender_id, " sent a message but is not in a lobby.")
		return

	# 2. Intercept Commands
	if message.begins_with("/"):
		_process_command(sender_id, sender_lobby, message)
		return 
		
	# 3. Route normal chat to ONLY the players in that lobby
	for player_id in Lobbies[sender_lobby]:
		receive_chat_message.rpc_id(player_id, sender_id, message)

func _process_command(sender_id: int, lobby_id: String, command_string: String):
	# Split the command by spaces. e.g., "/vote sb_lobby" -> ["/vote", "sb_lobby"]
	var args = command_string.split(" ", false)
	var main_command = args[0].to_lower()
	
	match main_command:
		"/vote":
			if args.size() > 1:
				# Tell the server's active lobbies that someone voted
				player_voted.emit(lobby_id, sender_id, args[1])
			else:
				receive_chat_message.rpc_id(sender_id, 0, "Usage: /vote [number]")
				
		"/start":
			print("Player ", sender_id, " force-started lobby: ", lobby_id)
			# NetworkDirector.lobby_container.start_match(lobby_id)
			
		_:
			# Catch-all for unknown commands
			receive_chat_message.rpc_id(sender_id, 0, "Unknown command: " + main_command)

@rpc("authority", "call_remote", "reliable")
func receive_chat_message(sender_id: int, message: String):
	chat_message_received.emit(sender_id, message)


#endregion

func _ready() -> void:
	if !multiplayer.is_server(): return
	multiplayer.peer_connected.connect(_on_client_connected)

func _on_client_connected(peer_id : int):
	if !multiplayer.is_server(): return
	rpc_id(peer_id, "sync_lobbies", Lobbies)
	rpc_id(peer_id, "sync_players", Players)
