extends Control

@onready var chat_display: RichTextLabel = $VBoxContainer/ChatDisplay
@onready var chat_input: LineEdit = $VBoxContainer/ChatInput

var fade_tween: Tween

func _ready() -> void:
	chat_input.hide()
	chat_display.modulate.a = 0.0 # Start fully transparent
	
	chat_input.text_submitted.connect(_on_chat_text_submitted)
	ServerDatabase.chat_message_received.connect(_on_server_message_received)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# Let them open chat with Enter OR Slash
		if (event.keycode == KEY_SLASH or event.keycode == KEY_ENTER) and not chat_input.has_focus():
			chat_input.show()
			chat_input.grab_focus()
			chat_input.clear() # Make sure it's completely empty!
			get_viewport().set_input_as_handled()
			
			# Keep chat fully visible while typing
			_show_chat_solid()

func _on_chat_text_submitted(new_text: String) -> void:
	chat_input.clear()
	chat_input.hide()
	chat_input.release_focus()
	
	# Start fading out since we are done typing
	_fade_chat_out()
	
	if new_text.strip_edges().is_empty():
		return
		
	ServerDatabase.send_chat_message.rpc_id(1, new_text)

func _on_server_message_received(sender_id: int, message: String) -> void:
	# A sender_id of 0 means it's a System message!
	var sender_name = "System" if sender_id == 0 else "Player " + str(sender_id)
	chat_display.append_text("\n[b]%s:[/b] %s" % [sender_name, message])
	
	# Show the chat briefly, unless they are currently typing (we don't want to fade if they are typing)
	if not chat_input.has_focus():
		_fade_chat_out(true)

# --- TWEEN LOGIC ---

func _show_chat_solid() -> void:
	if fade_tween:
		fade_tween.kill() # Stop any active fading
	chat_display.modulate.a = 1.0

func _fade_chat_out(spike_first: bool = false) -> void:
	if fade_tween:
		fade_tween.kill()
		
	fade_tween = create_tween()
	
	if spike_first:
		# Instantly pop the alpha to 1.0 when a message is received
		fade_tween.tween_property(chat_display, "modulate:a", 1.0, 0.05)
		
	fade_tween.tween_interval(4.0) # Wait 4 seconds
	fade_tween.tween_property(chat_display, "modulate:a", 0.0, 1.0) # Fade out over 1 second
