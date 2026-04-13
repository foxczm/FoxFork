extends Control
#autoload
@onready var menu: Control = $Menu
@onready var chat_input: LineEdit = $Chat/VBoxContainer/ChatInput

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		menu.visible = !menu.visible
		if menu.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_button_pressed() -> void:
	get_tree().quit()
