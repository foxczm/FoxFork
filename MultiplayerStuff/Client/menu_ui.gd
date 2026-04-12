extends Control

var current_lobby : String
@onready var vhs_off_anim: AnimatedSprite2D = $"../VHSOffAnim"


func _ready() -> void:
	ServerDatabase.connect("lobbies_updated", update_lobby_ui)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("menu"):
		visible = !visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func update_lobby_ui():
	for i : String in ServerDatabase.Lobbies:
		if ServerDatabase.Lobbies[i].has(multiplayer.get_unique_id()):
			current_lobby = i

func _on_leave_lobby_pressed() -> void:
	vhs_off_anim.play("off")
	await vhs_off_anim.animation_finished
