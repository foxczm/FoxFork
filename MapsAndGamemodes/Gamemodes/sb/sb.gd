extends Map
class_name SB
#sandbox
const SANDBOX_LEADERBOARD_UI = preload("res://MapsAndGamemodes/Gamemodes/sb/SandboxLeaderboardUI.tscn")

var sandbox_leaderboard

@export var player_spawn : Node3D
@export var respawn_delay : float = 5.0 # How long they wait in seconds
@export var gamemode_length = 10.0
var player_stats : Dictionary[int, Dictionary]

func custom_ready():
	sandbox_leaderboard = SANDBOX_LEADERBOARD_UI.instantiate()
	add_child(sandbox_leaderboard)
	if !multiplayer.is_server(): return
	await get_tree().create_timer(gamemode_length).timeout
	_game_ended()

func custom_process(delta : float):
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

func player_died(merc : Merc):
	if !multiplayer.is_server(): return
	# Grab the player ID from the Merc's name (which is set _spawn_player)
	var player_id = merc.name.to_int()
	
	# Update the database
	if player_stats.has(player_id):
		player_stats[player_id]["is_dead"] = true
		player_stats[player_id]["respawn_timer"] = respawn_delay
		player_stats[player_id]["deaths"] += 1 
		sync_player_stats.rpc(player_stats)
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
		sync_player_stats.rpc(player_stats)
	

func _on_player_left(player_id: int) -> void:
	if !multiplayer.is_server(): return
	
	print("Player ", player_id, " left the SB Map!")
	
	player_stats.erase(player_id)
	
	var merc_node = get_node_or_null(str(player_id))
	if merc_node:
		merc_node.queue_free()
	sync_player_stats.rpc(player_stats)

# Add this anywhere in SB.gd
@rpc("authority", "call_local", "reliable")
func sync_player_stats(new_stats: Dictionary) -> void:
	player_stats = new_stats
	
	# Push the fresh data to the UI!
	if sandbox_leaderboard and sandbox_leaderboard.has_method("update_ui"):
		sandbox_leaderboard.update_ui(player_stats)

func _on_player_joined(player_id: int) -> void:
	if not multiplayer.is_server(): return
	# They connected to the network! Set up their scoreboard stats right away.
	player_stats[player_id] = { "kills": 0, "deaths": 0, "is_dead": true, "respawn_timer": 0.0 }
	sync_player_stats.rpc(player_stats)

# Call this manually, or let Godot's built in tree-exiting catch it
func _exit_tree() -> void:
	if multiplayer.is_server():
		_cleanup_network_nodes()

func _cleanup_network_nodes() -> void:
	# Tell the spawner to cleanly despawn all active players across the network
	# before this Map node gets deleted.
	for child in player_spawner.get_children():
		child.queue_free()
