extends Control
class_name LobbyViewer
@onready var v_box_container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
const LOBBY_INFO = preload("res://MultiplayerStuff/Server/Lobby/lobby_info.tscn")
@onready var background: ColorRect = $Background
@onready var animation: AnimatedSprite2D = $Animation
@onready var panel: Panel = $Panel

func _ready() -> void:
	ServerDatabase.connect("lobbies_updated", create_lobby_views)
	create_lobby_views()

func open():
	var tween = create_tween()
	tween.tween_property(background, "modulate:a", 1.0, .3)
	await tween.finished
	animation.play("on")
	animation.show()
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close():
	var tween = create_tween()
	tween.tween_property(background, "modulate:a", 0.0, .3)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func create_lobby_views():
	for i in v_box_container.get_children():
		i.queue_free()
	
	for i in ServerDatabase.Lobbies:
		var lobby_info : LobbyInfo = LOBBY_INFO.instantiate()
		lobby_info.init(i, ServerDatabase.Lobbies[i]) #HACK
		v_box_container.add_child(lobby_info)


func _on_create_lobby_button_pressed() -> void:
	var lobby_container :LobbyContainer= get_tree().get_first_node_in_group("LobbyContainer")
	if lobby_container:
		lobby_container._on_create_lobby_button_pressed()
