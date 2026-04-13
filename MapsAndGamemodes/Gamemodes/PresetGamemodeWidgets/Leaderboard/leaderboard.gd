extends Control
class_name LeaderBoard

@onready var v_box_container: VBoxContainer = $Panel/VBoxContainer

# Tracks networking stats. Example: { 1: {"kills": 0, "deaths": 0, "is_dead": false} }
var stats: Dictionary = {}
var is_showcasing: bool = false # Prevents hiding the UI during the end-game showcase

func _ready() -> void:
	hide()

func _process(_delta: float) -> void:
	# If the match is over and we are showcasing, lock the leaderboard open
	if is_showcasing:
		return

	# Toggles visibility based on input (e.g., holding 'Tab')
	if stats.has(multiplayer.get_unique_id()):
		if Input.is_action_pressed("show_leaderboard"):
			show()
		else:
			hide()

# --- NEW HELPER: Fetch gamertag from ServerDatabase ---
func get_gamertag(id: int) -> String:
	if ServerDatabase.Players.has(id):
		# Grabs the gamertag, defaults back to ID if for some reason it's missing
		return str(ServerDatabase.Players[id].get("gamertag", id)) 
	return str(id)

# ==========================================
# SERVER API (Called by the Map Script)
# ==========================================

func add_player(player_id: int) -> void:
	if not multiplayer.is_server(): return
	# Players start dead until the map spawns them
	stats[player_id] = { "kills": 0, "deaths": 0, "is_dead": true }
	_sync_stats.rpc(stats)

func remove_player(player_id: int) -> void:
	if not multiplayer.is_server(): return
	stats.erase(player_id)
	_sync_stats.rpc(stats)

func record_death(player_id: int) -> void:
	if not multiplayer.is_server(): return
	if stats.has(player_id):
		stats[player_id]["deaths"] += 1
		stats[player_id]["is_dead"] = true
		_sync_stats.rpc(stats)

func record_kill(player_id: int) -> void:
	if not multiplayer.is_server(): return
	if stats.has(player_id):
		stats[player_id]["kills"] += 1
		_sync_stats.rpc(stats)

func set_player_alive(player_id: int) -> void:
	if not multiplayer.is_server(): return
	if stats.has(player_id):
		stats[player_id]["is_dead"] = false
		_sync_stats.rpc(stats)

func get_top_players(limit: int = 3) -> Array:
	var sorted_players = stats.keys()
	
	# Sort descending by kills. If tied, sort ascending by deaths.
	sorted_players.sort_custom(func(a, b):
		var kills_a = stats[a]["kills"]
		var kills_b = stats[b]["kills"]
		if kills_a != kills_b:
			return kills_a > kills_b 
		return stats[a]["deaths"] < stats[b]["deaths"]
	)
	
	# Return up to 'limit' players
	return sorted_players.slice(0, min(limit, sorted_players.size()))

# ==========================================
# NETWORKING & UI
# ==========================================

@rpc("authority", "call_local", "reliable")
func _sync_stats(new_stats: Dictionary) -> void:
	stats = new_stats
	if not is_showcasing:
		update_ui()

func update_ui() -> void:
	# 1. Clear out the old list
	for child in v_box_container.get_children():
		child.queue_free()
		
	# 2. Build the new list
	for player_id in stats.keys():
		var player_data = stats[player_id]
		
		var kills = player_data["kills"]
		var deaths = player_data["deaths"]
		var status = "DEAD" if player_data.get("is_dead", true) else "ALIVE"
		
		var player_name = get_gamertag(player_id) # USE THE HELPER
		
		var label = Label.new()
		label.text = "%s | Kills: %d | Deaths: %d | %s" % [player_name, kills, deaths, status]
		v_box_container.add_child(label)

@rpc("authority", "call_local", "reliable")
func show_end_game_showcase(top_players: Array) -> void:
	is_showcasing = true
	show() # Force the UI open
	
	# Clear the standard list
	for child in v_box_container.get_children():
		child.queue_free()
		
	# Add a title
	var title = Label.new()
	title.text = "=== MATCH OVER ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box_container.add_child(title)
	
	# Add some spacing
	v_box_container.add_child(Control.new())
	
	# Showcase the Top 3
	for i in range(top_players.size()):
		var p_id = top_players[i]
		var p_data = stats[p_id]
		var p_name = get_gamertag(p_id) # USE THE HELPER
		var label = Label.new()
		
		if i == 0:
			label.text = "🏆 1ST PLACE: %s - %d Kills / %d Deaths 🏆" % [p_name, p_data["kills"], p_data["deaths"]]
			label.add_theme_color_override("font_color", Color("gold"))
		elif i == 1:
			label.text = "🥈 2ND PLACE: %s - %d Kills / %d Deaths" % [p_name, p_data["kills"], p_data["deaths"]]
			label.add_theme_color_override("font_color", Color("silver"))
		elif i == 2:
			label.text = "🥉 3RD PLACE: %s - %d Kills / %d Deaths" % [p_name, p_data["kills"], p_data["deaths"]]
			label.add_theme_color_override("font_color", Color("cd7f32")) # Bronze
			
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v_box_container.add_child(label)
