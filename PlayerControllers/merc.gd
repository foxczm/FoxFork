@abstract class_name Merc extends CharacterBody3D

## THIS THE BASE CLASS, DO NOT CHANGE AN OF THIS UNLESS ITS IN THE INSPECTOR

@export_category("REQUIRED OBJECTS")
@export var camera : Camera3D

@export_group("Universal Properties")
@export var health :float = 100.0
@export var jump_strength = 2
@export var gravity = 9.8
@export var friction = .1
@export var air_acceleration = .3
@export var jump_buffer = .1
@export var speed = 1
#Vector 3 velocity
#Vector 3 Position

@export var abilities : Array[Ability]
#reminder abilities  can have their own ui

var dead = false

signal died(_self) #Server will disable input on character
signal took_damage

func _ready() -> void:
	if is_multiplayer_authority():
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().physics_frame.connect(check_abilities)
		custom_ready()
var do_jump : bool = false

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): 
		return
	
	var input = Vector2.ZERO
	input.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	input.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	input = input.normalized()
	
	if Input.is_physical_key_pressed(KEY_SPACE):
		do_jump = true

	# 3. PHYSICS & MOVEMENT
	
	
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y) * speed
	jump_buffer -= delta
	
	if do_jump: 
		do_jump = false
		jump_buffer = .1
	
	if is_on_floor():
		var current_friction: Vector2 = Vector2(velocity.x, velocity.z).rotated(PI) * friction
		var friction_dir = transform.basis * Vector3(current_friction.x, 0, current_friction.y)
		velocity += Vector3(current_friction.x, 0, current_friction.y)
		velocity += Vector3(movement_dir.x, 0, movement_dir.z)
		
		if jump_buffer >= 0:
			velocity.y += jump_strength
			jump_buffer = -1.0 #dont fly infinite
	else:
		if is_on_wall(): 
			velocity = velocity.lerp(Vector3.ZERO, delta * 5) 
		sv_airaccelerate(movement_dir, delta)

	velocity.y -= gravity * delta
	move_and_slide()

func sv_airaccelerate(movement_dir, delta):
	var air_strength = 3
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
	if !is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

#merc
func check_abilities() -> void:
	if abilities.size() <= 0: return
	for i in abilities:
		if !i.is_multiplayer_authority():
			i.set_multiplayer_authority(int(name), true)
		
		# Convert key to the integer keycode (e.g. Q -> 81)
		var key_code = OS.find_keycode_from_string(i.trigger_key)
		
		# Finally, check the hardware state
		if Input.is_physical_key_pressed(key_code):
			i.activate(abilities, self)

@rpc("any_peer","call_remote", 'reliable')
func take_damage(damage):
	health -= damage
	if health <= 0 and not dead:
		dead = true
		death_effects.rpc()
		die.rpc_id(1)
	else:
		emit_signal("took_damage")

@rpc("any_peer", "call_local")
func death_effects():
	pass

@rpc("authority", "call_remote", "reliable")
func die():
	emit_signal("died", self)

@abstract func custom_process(delta : float) #use this for addons, physics process is used for default movement
@abstract func custom_ready()
