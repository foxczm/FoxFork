extends Panel

signal vote_finished(winning_map: String)

@onready var vote_label: RichTextLabel = $VoteLabel

var map_votes : Dictionary = {}
var map_index_list : Array[String] = [] # Keeps maps in a strict numbered order
var _server_player_votes : Dictionary = {}

var is_voting_active: bool = false
var vote_time_remaining: int = 0
var last_announced_winner: String = ""

# Finds the Lobby node this panel belongs to so we can verify the lobby ID
@onready var parent_lobby = owner if owner is Lobby else get_parent()

func _ready() -> void:
	# 1. Build an ordered list so "1" always means the same map for everyone
	for key in ServerDatabase.Maps.keys():
		if key != 'hm_home':
			map_index_list.append(key)
			map_votes[key] = 0
		
	_update_ui()
	
	# 2. Only the server needs to listen to the chat command signal
	if multiplayer.is_server():
		ServerDatabase.player_voted.connect(_on_server_player_voted)

# Reduces time remaining locally for the UI
func _process(delta: float) -> void:
	if is_voting_active and vote_time_remaining > 0:
		pass # The visual countdown is handled by a looping 1-second timer below

# ==========================================
# SERVER LOGIC (Voting Process)
# ==========================================

# Call this from your Lobby script (Server-side) to begin the vote!
func initiate_vote(duration_seconds: int = 30) -> void:
	if not multiplayer.is_server(): return
	
	# Reset states
	_server_player_votes.clear()
	for key in map_votes.keys():
		map_votes[key] = 0
		
	last_announced_winner = ""
	
	# Tell all clients to start their local UI countdowns
	for player_id in parent_lobby.connected_players:
		rpc_id(player_id, "sync_vote_start", duration_seconds)
	sync_vote_start(duration_seconds) # Update the server's local UI
	
	# Start the server's authoritative timer
	await get_tree().create_timer(duration_seconds).timeout
	_end_vote()

func _end_vote() -> void:
	if not multiplayer.is_server(): return
	
	var winning_map = _calculate_winning_map()
	
	# Tell the clients to lock it down and show the winner
	for player_id in parent_lobby.connected_players:
		rpc_id(player_id, "sync_vote_end", winning_map)
	sync_vote_end(winning_map)
	
	# Tell your Lobby script to switch the map!
	vote_finished.emit(winning_map)

func _calculate_winning_map() -> String:
	var highest_votes = -1
	var tied_maps: Array[String] = []
	
	# Find the highest vote count and catch any ties
	for map_name in map_votes:
		var votes = map_votes[map_name]
		if votes > highest_votes:
			highest_votes = votes
			tied_maps = [map_name]
		elif votes == highest_votes:
			tied_maps.append(map_name)
			
	# If there's a tie, pick randomly from the tied maps!
	if tied_maps.size() > 1:
		return tied_maps[randi() % tied_maps.size()]
	elif tied_maps.size() == 1:
		return tied_maps[0]
		
	# Fallback just in case
	return map_index_list[0]

func _on_server_player_voted(vote_lobby_id: String, sender_id: int, vote_string: String) -> void:
	# Ignore if this vote happened in a different lobby or if voting is closed
	if parent_lobby.name != vote_lobby_id.validate_node_name() or not is_voting_active: 
		return
		
	var vote_num = int(vote_string)
	
	# Verify they typed a valid number (1 to Max Maps)
	if vote_num > 0 and vote_num <= map_index_list.size():
		var chosen_map = map_index_list[vote_num - 1] 
		_server_player_votes[sender_id] = chosen_map
		
		# Send a private chat message confirming their vote
		ServerDatabase.receive_chat_message.rpc_id(sender_id, 0, "Vote registered for " + chosen_map)
		
		_recalculate_votes()
	else:
		var err_msg = "Invalid map number. Type /vote 1-" + str(map_index_list.size())
		ServerDatabase.receive_chat_message.rpc_id(sender_id, 0, err_msg)

func _recalculate_votes() -> void:
	# Reset totals
	for key in map_votes.keys():
		map_votes[key] = 0
		
	# Tally the current votes
	for peer_id in _server_player_votes:
		var voted_map = _server_player_votes[peer_id]
		if map_votes.has(voted_map):
			map_votes[voted_map] += 1
			
	# Blast the new totals to all lobby friends
	for player_id in parent_lobby.connected_players:
		rpc_id(player_id, "sync_vote_totals", map_votes)
	sync_vote_totals(map_votes)

# ==========================================
# SYNC & UI LOGIC (Runs on Everyone)
# ==========================================

@rpc("authority", "call_local", "reliable")
func sync_vote_start(duration: int) -> void:
	is_voting_active = true
	vote_time_remaining = duration
	last_announced_winner = ""
	show() # Make sure the panel is visible!
	_tick_countdown()

@rpc("authority", "call_local", "reliable")
func sync_vote_end(winning_map: String) -> void:
	is_voting_active = false
	vote_time_remaining = 0
	last_announced_winner = winning_map
	_update_ui()
	
	# Optional: Automatically hide the vote panel after 5 seconds
	await get_tree().create_timer(5.0).timeout
	hide()

@rpc("authority", "call_local", "reliable")
func sync_vote_totals(new_totals: Dictionary) -> void:
	map_votes = new_totals
	_update_ui()

func _tick_countdown() -> void:
	if not is_voting_active: return
	
	_update_ui()
	vote_time_remaining -= 1
	
	if vote_time_remaining >= 0:
		await get_tree().create_timer(1.0).timeout
		_tick_countdown()

func _update_ui() -> void:
	var display_text = "[color=607D8B][b]Vote for next map[/b][/color]\n"
	
	if is_voting_active:
		display_text += "[color=orange]Time Remaining: " + str(vote_time_remaining) + "s[/color]\n"
		display_text += "[color=gray]type /vote 1-" + str(map_index_list.size()) + " to vote[/color]\n\n"
	else:
		if last_announced_winner != "":
			display_text += "[color=green]Voting Closed! Winner: " + last_announced_winner + "[/color]\n\n"
		else:
			display_text += "[color=gray]Voting is currently closed.[/color]\n\n"
	
	# Loop through the ordered list to generate the lines
	for i in range(map_index_list.size()):
		var map_name = map_index_list[i]
		var votes = map_votes[map_name]
		
		# Example: "1: sg_quadrants (2)"
		if map_name == last_announced_winner:
			display_text += "[color=yellow][b]" + str(i + 1) + ": " + map_name + " (" + str(votes) + ")[/b][/color]\n"
		else:
			display_text += str(i + 1) + ": " + map_name + " (" + str(votes) + ")\n"
		
	vote_label.text = display_text
