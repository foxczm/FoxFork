@abstract class_name Merc extends CharacterBody3D

## THIS THE BASE CLASS, DO NOT CHANGE AN OF THIS UNLESS ITS IN THE INSPECTOR
const ABILITY_UI = preload("res://Misc/UI/ability_ui.tscn")
var abilites_ui : AbilitiesUI

@export_category("REQUIRED OBJECTS")
@export var camera : Camera3D

@export_group("Universal Properties")
@export var health :float = 100.0
@export var gravity := 9.8
@export var friction := .1
@export var air_acceleration := .3
@export var speed := 1.0
@export var visual_body : Node3D
@export var visual_hand : Node3D
@export var merc_UI_color : Color
@export var camera_fov : float = 90.0

var target_position: Vector3 #what other people see
var target_rotation: Vector3

@export var abilities : Array[Ability]
#reminder abilities  can have their own ui

var dead = false
var ability_ui 
signal died(_self) #Server will disable input on character
signal took_damage

func _ready() -> void:
	target_position = global_position
	target_rotation = global_rotation
	
	_setup_synchronizer()
	
	if is_multiplayer_authority():
		camera.make_current()
		get_tree().physics_frame.connect(check_abilities)
		custom_ready()
		abilites_ui = ABILITY_UI.instantiate()
		add_child(abilites_ui)
		abilites_ui.generate_ui(self)
		if visual_body:
			visual_body.hide()
		if visual_hand:
			visual_hand.hide()
		
		show_visual_body_to_world.rpc()

@rpc("any_peer","call_remote","reliable")
func show_visual_body_to_world():
	if visual_body:
		visual_body.show()
	if visual_hand:
		visual_hand.show()

func _setup_synchronizer() -> void:
	var synchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MercSynchronizer" # Naming it helps prevent pathing desyncs
	
	var config = SceneReplicationConfig.new()
	
	# --- ON CHANGE PROPERTIES (Zero Bandwidth Cost unless modified) ---
	var static_props = [":health", ":gravity", ":friction", ":air_acceleration", ":speed"]
	for prop in static_props:
		var path = NodePath(prop)
		config.add_property(path)
		# Only send a packet if the value actually changes
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	
	## --- ALWAYS PROPERTIES (Costs bandwidth, required for standard multiplayer) ---
	#var dynamic_props = [":position", ":rotation"]
	#for prop in dynamic_props:
		#var path = NodePath(prop)
		#config.add_property(path)
		## Send a packet every network tick
		#config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	#
	synchronizer.replication_config = config
	add_child(synchronizer)

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority(): 
		# --- THE LERPING MAGIC ---
		# 15 is the "lerp speed". Higher = snappier, Lower = smoother but delayed.
		var lerp_speed = 15.0 * delta
		
		# Smoothly slide the position
		global_position = global_position.lerp(target_position, lerp_speed)
		
		# Smoothly rotate. We use lerp_angle instead of normal lerp!
		# Normal lerp will cause a crazy "spin of death" when going from 359 degrees back to 0.
		global_rotation.x = lerp_angle(global_rotation.x, target_rotation.x, lerp_speed)
		global_rotation.y = lerp_angle(global_rotation.y, target_rotation.y, lerp_speed)
		global_rotation.z = lerp_angle(global_rotation.z, target_rotation.z, lerp_speed)
		
		return # Skip all the local movement code below
	
	if camera: camera.fov = camera_fov
	
	var input = Vector2.ZERO
	input.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	input.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	input = input.normalized()
	
	var movement_dir = transform.basis * Vector3(input.x, 0, input.y) * speed
	
	if is_on_floor():
		var current_friction: Vector2 = Vector2(velocity.x, velocity.z).rotated(PI) * friction
		var friction_dir = transform.basis * Vector3(current_friction.x, 0, current_friction.y)
		velocity += Vector3(current_friction.x, 0, current_friction.y)
		velocity += Vector3(movement_dir.x, 0, movement_dir.z)
	
	else:
		if is_on_wall(): 
			velocity = velocity.lerp(Vector3.ZERO, delta * 5) 
		sv_airaccelerate(movement_dir, delta)

	velocity.y -= gravity * delta
	custom_process(delta)
	move_and_slide()
	if is_multiplayer_authority():
		receive_pos_from_server.rpc(global_position, global_rotation)
	
	if global_position.y < -1000:
		dead = true
		death_effects.rpc()
		die.rpc_id(1)

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
		if i == null: return
		if !i.is_multiplayer_authority():
			i.set_multiplayer_authority(int(name), true)
		
		if i.trigger_key != 'Passive':
			# Convert key to the integer keycode (e.g. Q -> 81)
			var key_code = OS.find_keycode_from_string(i.trigger_key)
			
			# Finally, check the hardware state
			if Input.is_physical_key_pressed(key_code):
				i.activate(abilities, self)

func add_ability(ability : Ability):
	pass

func remove_ability(ability: Ability):
	pass

@rpc("any_peer", "call_remote", "unreliable")
func receive_pos_from_server(pos: Vector3, rot: Vector3):
	# Don't move them yet! Just update the target.
	target_position = pos
	target_rotation = rot

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
