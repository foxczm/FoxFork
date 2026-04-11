extends Node3D
class_name Lobby

signal player_joined_lobby(player_id: int)
signal player_left_lobby(player_id: int)

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var current_map : Map
var connected_players : Array[int] = [] # The Lobby's master list
var starting_map = 'sb_lobby' #exits to fight race conditions

func _ready() -> void:
	register_spawnable_maps()
	if not multiplayer.is_server(): return
	
	await get_tree().create_timer(1.0).timeout
	
	call_deferred("change_map", "sb_lobby") #FIX

func register_spawnable_maps(): #<ALL>
	spawner.clear_spawnable_scenes()
	
	for key in ServerDatabase.Maps:
		var scene : PackedScene = ServerDatabase.Maps[key]
		if scene and scene.resource_path != "":
			spawner.add_spawnable_scene(scene.resource_path)

func change_map(map : String): 
	if !multiplayer.is_server(): return
	if current_map: current_map.queue_free()
	
	var new_map : Map = ServerDatabase.Maps[map].instantiate()
	new_map.name = name
	
	add_child(new_map)
	current_map = new_map
	
	# --- NEW: Await the map's setup ---
	await current_map.map_ready
	
	# Now that the map and UI are 100% loaded, push all existing players to it!
	for player_id in connected_players:
		player_joined_lobby.emit(player_id)

func on_player_joined(player_id: int) -> void:
	# 1. Add them to the master list
	if not connected_players.has(player_id):
		connected_players.append(player_id)
		
	# 2. If they joined mid-game (map is already fully loaded), emit immediately
	if current_map and current_map.is_map_ready:
		player_joined_lobby.emit(player_id)

func on_player_left(player_id: int) -> void:
	# Keep the master list clean
	connected_players.erase(player_id)
	player_left_lobby.emit(player_id)

func game_end():
	pass
