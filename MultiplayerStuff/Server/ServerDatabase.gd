extends Node
#and manager ;)
#if i wanted permanent stuff, look into just a simple cfg file for the future


#region DataBase

signal server_maps_updated #TODO
signal lobbies_updated 


var Maps : Dictionary [String, PackedScene] = {} #DNS (does not sync atm)
var Mercs : Dictionary [String, PackedScene] = {} #DNS
var Characters : Dictionary [String, PackedScene] = {} #DNS
var Players : Dictionary [int, Dictionary] #id, [gamertag, lobby]
var lobbies : Dictionary[String, Array] = {} #lobbyid = [player_id, ...]

var port = "10.42.0.1"
var address = 6789
#var chat 
#endregion

#region PRESET DATABASE
var PRESETMAPS : Dictionary [String, PackedScene] = {
	"lobby" = load("res://MapsAndGamemodes/Maps/Lobby/sb_lobby.tscn")
	
}

var PRESETMERCS : Dictionary [String, PackedScene] = {
	"default" = load("res://PlayerControllers/Mercs/Default/FirstPersonController.tscn")
}

const TRIGGER_KEYS = [
	"None", "E", "Q", "F", "R", "G", "H", "V", "B", "N", "M", "T", "Y", "X", 
	"C", "Z", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "Shift", 
	"Ctrl", "Alt", "Space", "Tab", "CapsLock", "Enter", 
	"F1", "F2", "F3", "F4", "F5", "F6", "F12"
]

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

func update_lobbies(_lobbies):
	rpc("sync_lobbies", _lobbies)

# "authority" means ONLY the server is allowed to trigger this on clients
@rpc("authority","call_local","reliable")
func sync_lobbies(_lobbies):
	lobbies = _lobbies
	lobbies_updated.emit()

#endregion

func _ready() -> void:
	Maps = PRESETMAPS
	Mercs = PRESETMERCS
