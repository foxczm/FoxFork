extends Node
class_name LobbyContainer

const LOBBY = preload("res://MultiplayerStuff/Server/Lobby/Lobby.tscn")

#RUNS ONLY ON SERVER
var lobbies : Dictionary[String, Array] = {} #lobbyid = [player_id, ...]
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner

#might have to have a bool, if match started then always spawn the map if not there, this is so people late to joining gets synced up

func _ready():
	multiplayer_spawner.spawn_function = _custom_lobby_spawn
	if !multiplayer.is_server(): return
	multiplayer.peer_disconnected.connect(_on_player_disconnected)

# The server calls this to build the lobby package
@rpc("any_peer", "call_remote", "reliable")
func create_new_lobby(lobby_id: String, players_in_lobby: Array[int]):
	if multiplayer.is_server():
		var data = { "id": lobby_id, "players": players_in_lobby }
		
		lobbies[lobby_id] = players_in_lobby
		ServerDatabase.update_lobbies(lobbies)
		var lob : Lobby = multiplayer_spawner.spawn(data)
		
		if lobbies.size() == 1:
			lob.call_deferred("change_map", "hm_home")
		#else:
			#lob.call_deferred("change_map", "sb_lobby")
# This runs on EVERY machine when the lobby spawns
func _custom_lobby_spawn(data: Dictionary) -> Node:
	var lobby_scene: Lobby = LOBBY.instantiate()
	lobby_scene.name = str(data["id"]).validate_node_name()
	
	var offset = ServerDatabase.Lobbies.size() * 10000
	
	lobby_scene.position = Vector3(offset, 0, 0)
	if not multiplayer.is_server() and multiplayer.get_unique_id() not in data["players"]:
		lobby_scene.hide() #HACK here we start >;,}
		lobby_scene.process_mode = Node.PROCESS_MODE_DISABLED
		
	return lobby_scene

@rpc("any_peer","call_remote",'reliable')
func add_player_to_lobby(lobby_id : String, player_id : int):
	if !multiplayer.is_server():
		add_player_to_lobby.rpc_id(1, lobby_id, player_id)
		return
	
	if lobbies.has(lobby_id):
		if player_id not in lobbies[lobby_id]:
			lobbies[lobby_id].append(player_id)
			ServerDatabase.update_lobbies(lobbies)
			wake_up_lobby.rpc_id(player_id, lobby_id)
			
			var active_lobby : Lobby = get_node_or_null(lobby_id.validate_node_name())
			if active_lobby:
				active_lobby.on_player_joined(player_id)
			
		else: print(str(player_id) + ' already joined')
	else:
		print("lobby does not exist :(")

# We don't need an RPC here if it's only called by the server internally,
# but you can add one later if players can manually click a "Leave Lobby" button.
@rpc("any_peer", "call_remote", "reliable")
func remove_player_from_lobby(lobby_id: String, player_id: int):
	# 1. If a client calls this, route it to the server
	if !multiplayer.is_server():
		remove_player_from_lobby.rpc_id(1, lobby_id, player_id)
		return
	# 2. Server handles the actual removal
	if lobbies.has(lobby_id):
		if player_id in lobbies[lobby_id]:
			lobbies[lobby_id].erase(player_id)
			
			# Update the dumb ServerDatabase single-source-of-truth
			ServerDatabase.update_lobbies(lobbies)
			
			# Tell the Map that they left so it can delete their character/stats!
			var active_lobby : Lobby = get_node_or_null(lobby_id.validate_node_name())
			if active_lobby:
				active_lobby.on_player_left(player_id)
				
			print("Player ", player_id, " removed from ", lobby_id)

@rpc("any_peer", "call_remote", "reliable")
func change_lobby(new_lobby_id: String, player_id: int) -> void:
	# 1. Route client requests to the server
	if !multiplayer.is_server():
		change_lobby.rpc_id(1, new_lobby_id, player_id)
		return
		
	# 2. Make sure the destination actually exists
	if not lobbies.has(new_lobby_id):
		print("Cannot change lobby: Destination lobby does not exist.")
		return

	# 3. Find the player's current lobby
	var old_lobby_id: String = ""
	for l_id in lobbies.keys():
		if player_id in lobbies[l_id]:
			old_lobby_id = l_id
			break

	# 4. Prevent redundant work if they are already there
	if old_lobby_id == new_lobby_id:
		print("Player " + str(player_id) + " is already in lobby: " + new_lobby_id)
		return

	# 5. Execute the swap
	if old_lobby_id != "":
		remove_player_from_lobby(old_lobby_id, player_id)
		# Put the old lobby to sleep on the client side so it disappears
		put_lobby_to_sleep.rpc_id(player_id, old_lobby_id)

	# 6. Add them to the new lobby (This already calls wake_up_lobby for the client!)
	add_player_to_lobby(new_lobby_id, player_id)

@rpc("authority", "call_remote", "reliable")
func put_lobby_to_sleep(lobby_id: String): # nighty night
	var inactive_lobby: Lobby = get_node_or_null(lobby_id.validate_node_name())
	if inactive_lobby:
		inactive_lobby.hide()
		inactive_lobby.process_mode = Node.PROCESS_MODE_DISABLED

@rpc("authority", "call_remote", "reliable")
func wake_up_lobby(lobby_id: String): #wakey waky, its time for schoo
	var active_lobby :Lobby = get_node_or_null(lobby_id.validate_node_name())
	if active_lobby:
		active_lobby.show()
		#print("position = ", active_lobby.position, " ", lobby_id)
		active_lobby.process_mode = Node.PROCESS_MODE_INHERIT

func _on_create_lobby_button_pressed() -> void:
	if !multiplayer.is_server():
		var array_of_player :Array[int] = []
		create_new_lobby.rpc_id(1, "server_lobby_" + str(randi_range(1,9999)), array_of_player)

func _on_player_disconnected(peer_id: int):
	# Search our local lobbies dictionary to find where they were
	for lobby_id in lobbies.keys():
		if peer_id in lobbies[lobby_id]:
			remove_player_from_lobby(lobby_id, peer_id)
			return # Assuming a player can only be in one lobby at a time
