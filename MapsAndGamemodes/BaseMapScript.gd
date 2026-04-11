@abstract
class_name Map extends Node3D
#implementspawnpoint system and gamemode system
#create a trello of what we need to do and a general flow chart
#call start_gamemode to start the game

signal map_ready # The signal the Lobby is waiting for

var player_spawner : MultiplayerSpawner
var player_data_base : Dictionary[int, Dictionary]
var is_map_ready : bool = false # Lobby checks this for mid-game joiners

func _ready() -> void:
	player_spawner = MultiplayerSpawner.new()
	player_spawner.name = "player_spawner"
	add_child(player_spawner)
	
	player_spawner.spawn_path = get_path()
	player_spawner.spawn_limit = 58
	
	player_spawner.spawn_function = _spawn_player
	register_players()
	
	var parent_lobby = get_parent()
	if parent_lobby is Lobby:
		# Connect directly to your abstract functions now! No queue needed.
		parent_lobby.player_joined_lobby.connect(_on_player_joined)
		parent_lobby.player_left_lobby.connect(_on_player_left)
	
	custom_ready()
	
	if !multiplayer.is_server(): return
	call_deferred("_finalize_setup")

func _finalize_setup() -> void:
	is_map_ready = true
	map_ready.emit() # Tell the Lobby: "Send me the players!"
	
	if multiplayer.is_server():
		start_gamemode()

func _process(delta: float) -> void:
	custom_process(delta)

func _game_ended(): #<1>
	if !multiplayer.is_server(): return
	pass

func register_players(): #<ALL> registers MERCS
	player_spawner.clear_spawnable_scenes()
	
	for key in ServerDatabase.Mercs:
		var scene : PackedScene = ServerDatabase.Mercs[key]
		if scene and scene.resource_path != "":
			player_spawner.add_spawnable_scene(scene.resource_path)

func _spawn_player(spawn_data:Dictionary):
	#TODO throw error if dict does not match
	var merc_spanwed : PackedScene = ServerDatabase.Mercs[spawn_data["merc_type"]]
	var merc_real : Merc = merc_spanwed.instantiate()
	
	merc_real.name = str(spawn_data["peer_id"])
	merc_real.set_multiplayer_authority(int(spawn_data["peer_id"]))
	merc_real.position = spawn_data["position"]
	
	merc_real.died.connect(player_died)
	return merc_real #DONT FOGET THIS BASTAD

func get_lobby_player_ids(): return int(name)

@abstract func start_gamemode()
@abstract func end_gamemode()
@abstract func player_died(merc : Merc)
@abstract func _on_player_joined(player_id: int)
@abstract func _on_player_left(player_id: int)
@abstract func custom_ready()
@abstract func custom_process(delta : float)
