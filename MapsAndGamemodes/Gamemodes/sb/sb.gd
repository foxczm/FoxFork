extends Map
class_name SB
#sandbox

@export var player_spawn : Node3D
var player_stats : Dictionary[int, Dictionary]

func _process(delta: float) -> void:
	pass

func start_gamemode():
	await get_tree().create_timer(1.5).timeout
	for i in ServerDatabase.lobbies[name]:
		player_spawner.spawn({"merc_type" = "default", "position" = Vector3.ZERO, "peer_id" = i})

func end_gamemode():
	pass
