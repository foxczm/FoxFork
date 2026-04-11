extends Node
#and manager ;)
#if i wanted permanent stuff, look into just a simple cfg file for the future


#region DataBase

signal server_maps_updated #TODO
signal players_updated
signal lobbies_updated 

var Maps : Dictionary [String, PackedScene] = {
	"sb_lobby" = load("res://MapsAndGamemodes/Maps/sb_Lobby/sb_lobby.tscn"),
	"hm_home" = load("res://MultiplayerStuff/home -._-/hm_home.tscn")
} 

var Mercs : Dictionary [String, PackedScene] = {
	"default" = load("res://PlayerControllers/Mercs/Default/FirstPersonController.tscn")
} 

var Characters : Dictionary [String, PackedScene] = {} 
var Players : Dictionary [int, Dictionary] #id, [gamertag, lobby]
var Lobbies : Dictionary[String, Array] = {} #lobbyid = [player_id, ...]

var port = 6789
#var address = "localhost"
var address = "csdev03.d.umn.edu"
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

#endregion

func _ready() -> void:
	if !multiplayer.is_server(): return
	multiplayer.peer_connected.connect(_on_client_connected)

func _on_client_connected(peer_id : int):
	if !multiplayer.is_server(): return
	rpc_id(peer_id, "sync_lobbies", Lobbies)
	rpc_id(peer_id, "sync_players", Players)
