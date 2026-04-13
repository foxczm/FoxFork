extends Ability
class_name SprintAbility

@export_group("Sprint Settings")
@export var speed_multiplier: float = 1.5
@export var fov_multiplier: float = 1.2
@export var transition_speed: float = 10.0 # Higher = faster snap, Lower = smoother glide

# Internal state tracking
var _is_sprinting: bool = false
var _is_recovering: bool = false # Tracks if we are smoothly easing back to normal
var _original_speed: float = 0.0
var _original_fov: float = 0.0
var _target_speed: float = 0.0
var _target_fov: float = 0.0
var _merc_ref: Merc = null

func _physics_process(delta: float) -> void:
	if _merc_ref == null: 
		return

	# 1. Listen for key release if we are currently sprinting
	if _is_sprinting:
		var key_code = OS.find_keycode_from_string(trigger_key)
		if not Input.is_physical_key_pressed(key_code):
			_stop_sprint()

	# 2. --- THE LERPING MAGIC ---
	if _is_sprinting:
		# Smoothly accelerate and push FOV out
		_merc_ref.speed = lerp(_merc_ref.speed, _target_speed, transition_speed * delta)
		_merc_ref.camera_fov = lerp(_merc_ref.camera_fov, _target_fov, transition_speed * delta)
		
	elif _is_recovering:
		# Smoothly decelerate and pull FOV back in
		_merc_ref.speed = lerp(_merc_ref.speed, _original_speed, transition_speed * delta)
		_merc_ref.camera_fov = lerp(_merc_ref.camera_fov, _original_fov, transition_speed * delta)
		
		# Stop recovering once we are microscopically close to the original values 
		# (prevents math errors and endless processing)
		if abs(_merc_ref.speed - _original_speed) < 0.05 and abs(_merc_ref.camera_fov - _original_fov) < 0.5:
			_merc_ref.speed = _original_speed
			_merc_ref.camera_fov = _original_fov
			_is_recovering = false

# This is called by Merc every single frame the key is held down
func activate(abilities: Array[Ability], merc: Merc) -> void:
	# If we are already sprinting, ignore the continuous stream
	if _is_sprinting:
		return

	_merc_ref = merc
	
	# CRITICAL: Only save the original stats if we are fully idle!
	# If they rapid-tap the sprint key while recovering, we don't want to 
	# accidentally save the half-lerped speed as their new permanent base speed.
	if not _is_recovering:
		_original_speed = merc.speed
		_original_fov = merc.camera_fov
		_target_speed = _original_speed * speed_multiplier
		_target_fov = _original_fov * fov_multiplier

	_is_sprinting = true
	_is_recovering = false # Cancel any ongoing deceleration

# Triggers the smooth lerp back to normal
func _stop_sprint() -> void:
	_is_sprinting = false
	_is_recovering = true
