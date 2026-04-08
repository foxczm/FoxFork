extends Map
class_name SB
#sandbox

@onready var sandbox_leaderboard_ui: Control = $"."

@onready var leader_board: Panel = $SBUI/LeaderBoard

@export var player_spawn : Node3D
@export var respawn_delay : float = 5.0 # How long they wait in seconds

var player_stats : Dictionary[int, Dictionary]

func _process(delta: float) -> void:
	# 1. Only the server manages respawns
	if !multiplayer.is_server(): return
	
	# 2. Check every player's stats every frame
	for player_id in player_stats.keys():
		var stats = player_stats[player_id]
		
		# 3. If they are dead, tick down the timer
		if stats["is_dead"]:
			stats["respawn_timer"] -= delta
			
			# 4. Timer is up! Respawn them.
			if stats["respawn_timer"] <= 0.0:
				_respawn_player(player_id)

func start_gamemode():
	pass

func end_gamemode():
	pass

func player_died(merc : Merc):
	if !multiplayer.is_server(): return
	# Grab the player ID from the Merc's name (which is set _spawn_player)
	var player_id = merc.name.to_int()
	
	# Update the database
	if player_stats.has(player_id):
		player_stats[player_id]["is_dead"] = true
		player_stats[player_id]["respawn_timer"] = respawn_delay
		player_stats[player_id]["deaths"] += 1 
		
	merc.queue_free()

func _respawn_player(player_id: int):
	# 1. Reset their death status
	player_stats[player_id]["is_dead"] = false
	
	# 2. Spawn them back into the world
	if not has_node(str(player_id)):
		player_spawner.spawn({
			"merc_type": "default", 
			"position": Vector3.ZERO, # Or use player_spawn.global_position
			"peer_id": player_id
		})
		print("Player ", player_id, " respawned!")

func _on_player_joined(player_id: int) -> void:
	if !multiplayer.is_server(): return
	
	print("Player ", player_id, " joined the SB Map!")
	
	player_stats[player_id] = {
		"kills": 0,
		"deaths": 0,
		"is_dead": false,
		"respawn_timer": 0.0
	}
	
	if not has_node(str(player_id)):
		player_spawner.spawn({"merc_type" = "default", "position" = Vector3.ZERO, "peer_id" = player_id})

func _on_player_left(player_id: int) -> void:
	if !multiplayer.is_server(): return
	
	print("Player ", player_id, " left the SB Map!")
	
	player_stats.erase(player_id)
	
	var merc_node = get_node_or_null(str(player_id))
	if merc_node:
		merc_node.queue_free()
