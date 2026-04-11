extends Map
class_name HM
@onready var trans_out_path: CameraFollowPath = $TransOutPath

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func start_gamemode():
	pass

func end_gamemode():
	pass #not gonna happen -._-

func player_died(merc : Merc):
	pass #not gonna happen -_.-

func _on_player_joined(peer_id: int):
	if !multiplayer.is_server(): return
	
	player_spawner.spawn({'merc_type' = 'default', "peer_id" = peer_id, "position" = Vector3.ZERO})
	
func _on_player_left(player_id: int):
	pass

func custom_ready():
	pass

func custom_process(delta : float):
	pass
