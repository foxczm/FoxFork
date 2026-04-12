extends Node3D
class_name Lobby

signal player_joined_lobby(player_id: int)
signal player_left_lobby(player_id: int)

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var camera_follow_path: CameraFollowPath = $CameraFollowPath
@onready var map_voting: Panel = $MapVoting

var current_map : Map
var next_map : String = "sb_lobby"
var connected_players : Array[int] = [] # The Lobby's master list
var starting_map = 'sb_lobby' #exits to fight race conditions
var time_till_map_vote := 5.0
var is_changing_map : bool = false

func _ready() -> void:
	register_spawnable_maps()
	if not multiplayer.is_server(): return

func register_spawnable_maps(): #<ALL>
	spawner.clear_spawnable_scenes()
	
	for key in ServerDatabase.Maps:
		var scene : PackedScene = ServerDatabase.Maps[key]
		if scene and scene.resource_path != "":
			spawner.add_spawnable_scene(scene.resource_path)

func change_map(map_name : String): 
	if !multiplayer.is_server(): return
	
	# Prevent double-calls from ruining the transition
	if is_changing_map: return
	is_changing_map = true
	
	if current_map: 
		# Disconnect signals so late-joiners aren't routed to a dying map
		player_joined_lobby.disconnect(current_map._on_player_joined)
		player_left_lobby.disconnect(current_map._on_player_left)
		remove_child(current_map)
		current_map.queue_free()
		current_map = null # Explicitly nullify it so it instantly fails 'if current_map' checks
	
	var new_map : Map = ServerDatabase.Maps[map_name].instantiate()
	
	new_map.name = name #so far i havent had any issues with this naming scheme, it seems to be stable
	
	add_child(new_map)
	current_map = new_map
	
	await current_map.map_ready
	
	# Transition complete! Unlock the lobby.
	is_changing_map = false
	
	# Now that it's safe, push everyone into the new map
	for player_id in connected_players:
		player_joined_lobby.emit(player_id)
	
	# Start the vote timer for the next transition
	await get_tree().create_timer(time_till_map_vote).timeout
	map_voting.initiate_vote(4)

func on_player_joined(player_id: int) -> void:
	# 1. Add them to the master list
	if not connected_players.has(player_id):
		connected_players.append(player_id)
		
	# 2. If they joined mid-game (map is already fully loaded), emit immediately
	if current_map and current_map.is_map_ready and not is_changing_map:
		player_joined_lobby.emit(player_id)

func on_player_left(player_id: int) -> void:
	# Keep the master list clean
	connected_players.erase(player_id)
	player_left_lobby.emit(player_id)

func game_end():
	#animssss  and stuff
	change_map(next_map)

func _on_map_voting_vote_finished(winning_map: String) -> void:
	next_map = winning_map
