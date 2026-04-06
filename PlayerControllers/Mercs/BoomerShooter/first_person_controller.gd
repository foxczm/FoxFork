extends CharacterBody3D
@onready var camera_3d: Camera3D = $Camera3D
@onready var input_synchronizer: MultiplayerSynchronizer = $InputSynchronizer


enum STATE {GROUNDED, AIR, GRAPPLE}
var cur_state = STATE.GROUNDED

var mouse_sensitivity = 0.002
var jump_strength = 2
var friction = .1
var air_acceleration = .3
var jump_buffer = .1
var speed = 1
@export var input : Vector2
var do_jump = false


func _enter_tree():
	# Set the authority based on the Node name (which is "1", "2", etc.)
	# This ensures both Server and Client agree on who owns this node immediately.
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	if is_multiplayer_authority():
		$Camera3D.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		input_synchronizer.set_multiplayer_authority(str(name).to_int())
	
func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		$UI/Velocity.text = str(snapped((velocity.length()), 0.01))
		if input_synchronizer: input = input_synchronizer.input_direction
		
		var movement_dir = transform.basis * Vector3(input.x, 0, input.y) * speed #makes sure the forward is the forward you are facing
		jump_buffer -= delta
		if do_jump: 
			do_jump = false
			jump_buffer = .1
		
		match cur_state:
			STATE.GROUNDED:
				var current_friction: Vector2 = Vector2(velocity.x, velocity.z).rotated(PI) * friction
				var friction_dir = transform.basis * Vector3(current_friction.x, 0, current_friction.y)
				velocity += Vector3(current_friction.x, 0, current_friction.y)
				velocity += Vector3(movement_dir.x, 0, movement_dir.z)
				if jump_buffer >= 0:
					velocity.y += jump_strength
					jump_buffer = .1
			STATE.AIR:
				if is_on_wall(): velocity.lerp(Vector3.ZERO, delta * 5)
				sv_airaccelerate(movement_dir, delta)
		if cur_state != STATE.GRAPPLE:
			if is_on_floor(): cur_state = STATE.GROUNDED
			else: cur_state = STATE.AIR

		velocity.y -= 9.8 * delta
		move_and_slide()


func sv_airaccelerate(movement_dir, delta):
	var air_strength
	if cur_state == STATE.GRAPPLE: air_strength = 2
	else: air_strength = 3
	
	movement_dir = movement_dir * air_strength
	var wish_speed = movement_dir.length()
	
	if wish_speed > 1:
		wish_speed = 1
	
	var current_speed = velocity.dot(movement_dir)
	var add_speed = wish_speed - current_speed
	if add_speed <= 0:
		return
	
	var accel_speed = 10 * 10 * delta
	if accel_speed > add_speed:
		accel_speed = add_speed
	
	velocity += accel_speed * movement_dir
	
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera_3d.rotate_x(-event.relative.y * mouse_sensitivity)
