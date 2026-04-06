extends WeaponAbility

func _process(delta: float) -> void:
	if !is_multiplayer_authority(): pass

func activate(delta, abilities : Array[Ability]):
	pass

func shoot():
	pass
