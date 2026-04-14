extends Ability
class_name JhomPassiveHeal


@export_group("Health Regen Settings")
@export var health_per_sec: float = 5.0
@export var merc:Merc

# This is called by Merc every single frame
func activate(abilities: Array[Ability], merc: Merc) -> void:
	while true:
		if merc.health == 250.0:
			merc.health = 250.0
		else:
			(get_parent() as Merc).take_damage(health_per_sec*-1)
			print(merc.health)
		pass
