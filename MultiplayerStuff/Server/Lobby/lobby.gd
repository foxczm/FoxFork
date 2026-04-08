extends Node3D
class_name Lobby

signal player_joined_lobby(player_id: int)
signal player_left_lobby(player_id: int)

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var current_map : Map

func _ready() -> void:
	register_spawnable_maps()
	if not multiplayer.is_server(): return
	
	await get_tree().create_timer(1.0).timeout 
	call_deferred("change_map", 'lobby')

func register_spawnable_maps(): #<ALL>
	spawner.clear_spawnable_scenes()
	
	for key in ServerDatabase.Maps:
		var scene : PackedScene = ServerDatabase.Maps[key]
		if scene and scene.resource_path != "":
			spawner.add_spawnable_scene(scene.resource_path)

func change_map(map : String): #maps hold gamemodes #<1>
	if !multiplayer.is_server(): return
	if current_map: current_map.queue_free()
	
	var new_map : Map = ServerDatabase.Maps[map].instantiate()
	new_map.name = name
	
	add_child(new_map)
	current_map = new_map

func on_player_joined(player_id: int) -> void:
	player_joined_lobby.emit(player_id)

func on_player_left(player_id: int) -> void:
	player_left_lobby.emit(player_id)

func game_end():
	pass
