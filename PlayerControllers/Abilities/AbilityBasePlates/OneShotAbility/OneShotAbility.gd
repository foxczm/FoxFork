@abstract extends Ability
class_name OneShotAbility

@export_group("One-Shot Settings")
@export var cooldown: float = 1.0

# Internal state tracking (Hidden from the inspector so beginners don't break it)
var _current_cooldown: float = 0.0
var _was_held: bool = false

func _physics_process(delta: float) -> void:
	# 1. Constantly tick down the cooldown timer
	if _current_cooldown > 0.0:
		_current_cooldown -= delta

	# 2. Reset the "held" lock if the player lets go of the key
	if trigger_key != "Passive":
		var key_code = OS.find_keycode_from_string(trigger_key)
		if not Input.is_physical_key_pressed(key_code):
			_was_held = false

# This intercepts the continuous stream from the Merc class
func activate(abilities: Array[Ability], merc: Merc) -> void:
	# If the ability is still on cooldown OR the player is just holding the button down, ignore
	if _current_cooldown > 0.0 or _was_held:
		return

	# Lock the ability so it doesn't rapid-fire on the very next physics frame
	_was_held = true
	_current_cooldown = cooldown

	# Fire the actual custom logic!
	_on_activate_just_pressed(abilities, merc)

# Club members will override THIS function in their custom abilities
@abstract func _on_activate_just_pressed(abilities: Array[Ability], merc: Merc)
