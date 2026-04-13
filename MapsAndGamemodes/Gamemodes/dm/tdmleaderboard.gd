extends LeaderBoard
class_name TDMLeaderBoard

const TEAM_COLORS = {
	"red": Color.RED,
	"blue": Color.BLUE,
	"default": Color.WHITE
}

# ==========================================
# SERVER API OVERRIDES & ADDITIONS
# ==========================================

func add_player(player_id: int) -> void:
	if not multiplayer.is_server(): return
	stats[player_id] = { "kills": 0, "deaths": 0, "is_dead": true, "team": "default" }
	_sync_stats.rpc(stats)

func set_player_team(player_id: int, team: String) -> void:
	if not multiplayer.is_server(): return
	if stats.has(player_id):
		stats[player_id]["team"] = team
		_sync_stats.rpc(stats)

# ==========================================
# UI OVERRIDES
# ==========================================

func update_ui() -> void:
	# 1. Clear out the old list
	for child in v_box_container.get_children():
		child.queue_free()
		
	# 2. Calculate Team Scores
	var team_scores = {"red": 0, "blue": 0}
	for p_id in stats:
		var t = stats[p_id].get("team", "default")
		if team_scores.has(t):
			team_scores[t] += stats[p_id]["kills"]

	# 3. Add Team Score Header
	var header = Label.new()
	header.text = "🔴 RED KILLS: %d   |   🔵 BLUE KILLS: %d" % [team_scores["red"], team_scores["blue"]]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box_container.add_child(header)
	
	# Visual divider
	v_box_container.add_child(HSeparator.new())
		
	# 4. Build the new player list, colored by team
	for player_id in stats.keys():
		var player_data = stats[player_id]
		var kills = player_data["kills"]
		var deaths = player_data["deaths"]
		var team = player_data.get("team", "default")
		var status = "DEAD" if player_data.get("is_dead", true) else "ALIVE"
		
		var player_name = get_gamertag(player_id) # INHERITED HELPER
		
		var label = Label.new()
		label.text = "%s | Kills: %d | Deaths: %d | %s" % [player_name, kills, deaths, status]
		
		if TEAM_COLORS.has(team):
			label.add_theme_color_override("font_color", TEAM_COLORS[team])
			
		v_box_container.add_child(label)

@rpc("authority", "call_local", "reliable")
func show_end_game_showcase(top_players: Array) -> void:
	is_showcasing = true
	show() # Force the UI open
	
	for child in v_box_container.get_children():
		child.queue_free()
		
	# Calculate Final Team Scores
	var team_scores = {"red": 0, "blue": 0}
	for p_id in stats:
		var t = stats[p_id].get("team", "default")
		if team_scores.has(t):
			team_scores[t] += stats[p_id]["kills"]
			
	# Add a title based on who won
	var title = Label.new()
	if team_scores["red"] > team_scores["blue"]:
		title.text = "🏆 RED TEAM WINS! 🏆"
		title.add_theme_color_override("font_color", TEAM_COLORS["red"])
	elif team_scores["blue"] > team_scores["red"]:
		title.text = "🏆 BLUE TEAM WINS! 🏆"
		title.add_theme_color_override("font_color", TEAM_COLORS["blue"])
	else:
		title.text = "🤝 MATCH TIED 🤝"
		
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box_container.add_child(title)
	
	var score_label = Label.new()
	score_label.text = "FINAL SCORE -> Red: %d  |  Blue: %d" % [team_scores["red"], team_scores["blue"]]
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box_container.add_child(score_label)
	
	v_box_container.add_child(HSeparator.new())
	
	# MVP Title
	var mvp_title = Label.new()
	mvp_title.text = "--- MATCH MVPs ---"
	mvp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v_box_container.add_child(mvp_title)
	
	# Showcase the Top 3 Players, colored by their team
	for i in range(top_players.size()):
		var p_id = top_players[i]
		var p_data = stats[p_id]
		var p_name = get_gamertag(p_id) # INHERITED HELPER
		var label = Label.new()
		
		label.text = "#%d: %s - %d Kills" % [i + 1, p_name, p_data["kills"]]
		
		var team = p_data.get("team", "default")
		if TEAM_COLORS.has(team):
			label.add_theme_color_override("font_color", TEAM_COLORS[team])
			
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v_box_container.add_child(label)
