extends Map
class_name DM
#deathmatch

const LEADER_BOARD = preload("res://MapsAndGamemodes/Gamemodes/PresetGamemodeWidgets/Leaderboard/LeaderBoard.tscn")
const DM_UI = preload("res://MapsAndGamemodes/Gamemodes/PresetGamemodeWidgets/VersusUI/VSUI.tscn")
const CHAR_SELECT = preload("res://MapsAndGamemodes/Gamemodes/PresetGamemodeWidgets/CharacterSelect/CharacterSelect.tscn")

var leaderboard: LeaderBoard 
var match_ui: VSUI
var char_select_ui # Reference to the local UI
var master_character_database: Dictionary = {} # Maps peer_id -> merc_type string

@export var spawn_points: Array[Node3D] = [] 
@export var respawn_delay: float = 5.0 
@export var gamemode_length = 10.0

var respawn_trackers: Dictionary[int, Dictionary] = {}
var match_started: bool = false 
var time_left: float = 0.0 # Track time for the UI

func _ready() -> void:
	leaderboard = LEADER_BOARD.instantiate()
	add_child(leaderboard)
	
	# Instantiate the UI on all clients
	match_ui = DM_UI.instantiate()
	add_child(match_ui)
	
	# Instantiate Character Select UI
	char_select_ui = CHAR_SELECT.instantiate()
	add_child(char_select_ui)
	
	char_select_ui.character_locked_in.connect(_on_local_character_locked_in)

func _process(delta: float) -> void:
	# --- UI & TIME LOGIC (Runs on Server AND Clients) ---
	if match_started:
		time_left -= delta
		
		# Calculate scores for the UI
		var my_id = multiplayer.get_unique_id()
		var my_kills = 0
		var top_kills = 0
		
		if leaderboard and leaderboard.stats:
			# Get local player's kills safely
			if leaderboard.stats.has(my_id):
				my_kills = leaderboard.stats[my_id].get("kills", 0)
			
			# Find the highest kills in the lobby
			for player_data in leaderboard.stats.values():
				var kills = player_data.get("kills", 0)
				if kills > top_kills:
					top_kills = kills
		
		# Feed the UI
		if match_ui:
			match_ui.update_ui(my_kills, top_kills, max(time_left, 0.0))

	# --- RESPAWN LOGIC (Server Only) ---
	if !multiplayer.is_server() or !match_started: 
		return
		
	# Check server game-end condition
	if time_left <= 0.0 and match_started:
		_finish_match()
		return
	
	for player_id in respawn_trackers.keys():
		var tracker = respawn_trackers[player_id]
		
		if tracker["is_dead"]:
			tracker["respawn_timer"] -= delta
			if tracker["respawn_timer"] <= 0.0:
				_respawn_player(player_id)

func player_died(merc: Merc):
	if !multiplayer.is_server(): return
	var player_id = merc.name.to_int()
	
	# Update Map logic (Respawns)
	if respawn_trackers.has(player_id):
		respawn_trackers[player_id]["is_dead"] = true
		respawn_trackers[player_id]["respawn_timer"] = respawn_delay
	
	# Update Leaderboard logic
	if leaderboard:
		leaderboard.record_death(player_id)
		
	merc.queue_free()

func _respawn_player(player_id: int):
	# 1. Check if they have a character selected
	var chosen_merc = master_character_database.get(player_id, "")
	if chosen_merc == "": 
		return # They haven't picked yet, do NOT spawn them
		
	respawn_trackers[player_id]["is_dead"] = false
	
	if leaderboard:
		leaderboard.set_player_alive(player_id)
	
	if not has_node(str(player_id)):
		var spawn_pos = Vector3.ZERO
		if spawn_points.size() > 0:
			var random_spawn = spawn_points.pick_random()
			if random_spawn:
				spawn_pos = random_spawn.position 
				
		player_spawner.spawn({
			"merc_type": chosen_merc, 
			"position": spawn_pos,
			"peer_id": player_id
		})

func _on_player_joined(player_id: int) -> void:
	if not multiplayer.is_server(): return
	
	respawn_trackers[player_id] = { "is_dead": true, "respawn_timer": 0.0 }
	
	if leaderboard:
		leaderboard.add_player(player_id)
		
	# Start character selection process for the new player
	start_char_select.rpc_id(player_id)

func _on_player_left(player_id: int) -> void:
	if !multiplayer.is_server(): return
	
	respawn_trackers.erase(player_id)
	master_character_database.erase(player_id) # Clean up memory
	
	if leaderboard:
		leaderboard.remove_player(player_id)
	
	var merc_node = get_node_or_null(str(player_id))
	if merc_node:
		merc_node.queue_free()

func start_gamemode():
	if !multiplayer.is_server(): return
	# Start the match on ALL clients simultaneously
	_sync_start_match.rpc(gamemode_length)

@rpc("authority", "call_local", "reliable")
func _sync_start_match(length: float) -> void:
	time_left = length
	match_started = true

# ==========================================
# CLIENT SIDE LOGIC
# ==========================================

func _on_local_character_locked_in(chosen_merc: String):
	# Hide the UI locally
	char_select_ui.hide()
	# Tell the server what we picked
	submit_character_choice.rpc_id(1, chosen_merc)

@rpc("authority", "call_remote", "reliable")
func start_char_select():
	char_select_ui.show()

func _unhandled_input(event: InputEvent) -> void:
	# Handle the 'M' key (Change Character)
	if Input.is_action_just_pressed("change_character"):
		if char_select_ui: 
			char_select_ui.show()
			
		# Tell the server we want to switch, which requires killing us
		request_suicide_for_switch.rpc_id(1)

# ==========================================
# SERVER SIDE LOGIC
# ==========================================

@rpc("any_peer", "call_remote", "reliable")
func submit_character_choice(merc_type: String):
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Update the server's database
	master_character_database[sender_id] = merc_type
	
	# If they were waiting to respawn (like on first join), force a spawn immediately
	if respawn_trackers.has(sender_id) and respawn_trackers[sender_id]["is_dead"]:
		respawn_trackers[sender_id]["respawn_timer"] = 0.0

@rpc("any_peer", "call_remote", "reliable")
func request_suicide_for_switch():
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Find their physical body in the world
	var merc_node = get_node_or_null(str(sender_id))
	
	if merc_node and not merc_node.dead:
		# Force kill them. This will trigger player_died(), which handles 
		# the respawn_trackers logic and puts them in the respawn queue
		merc_node.health = 0
		merc_node.dead = true
		merc_node.death_effects.rpc()
		merc_node.emit_signal("died", merc_node)

func _finish_match():
	# Lock the game loop
	match_started = false 
	
	# Calculate winners and show them on all clients
	if leaderboard:
		var top_players = leaderboard.get_top_players(3)
		leaderboard.show_end_game_showcase.rpc(top_players)
		
	# Wait for 10 seconds so people can see the results
	await get_tree().create_timer(10.0).timeout
	
	# Finally, end the game entirely
	_game_ended()
