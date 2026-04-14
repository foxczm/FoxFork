class_name Merc extends CharacterBody3D

signal died(_self) #Server will disable input on character
signal took_damage

## THIS THE BASE CLASS, DO NOT CHANGE AN OF THIS UNLESS ITS IN THE INSPECTOR
const ABILITY_UI = preload("res://Misc/UI/ability_ui.tscn")
const MERC_LABEL = preload("res://MultiplayerStuff/Client/MercLabel.tscn")
@onready var heal_delay: Timer = $HealDelay

@export_category("REQUIRED OBJECTS")
@export var camera : Camera3D

@export_group("Universal Properties")
@export var health :float = 100.0
@export var health_per_sec = 5.0
@export var gravity := 9.8
@export var friction := .1
@export var air_acceleration := .3
@export var speed := 1.0
@export var visual_body : Node3D
@export var visual_hand : Node3D
@export var merc_UI_color : Color
@export var camera_fov : float = 90.0
@export var debug_mode : bool = false


@export var abilities : Array[Ability]
#reminder abilities  can have their own ui

var abilites_ui : AbilitiesUI
var name_label_instance
var target_position: Vector3 #what other people see
var target_rotation: Vector3

var dead = false
var ability_ui 
var team: String = "default"
var player_teams: Dictionary = {}
var timer : Timer


const TEAM_COLORS = {
	"default": Color.WHITE,
	"red": Color.RED,
	"blue": Color.BLUE
}

func _ready() -> void:
	
	
	# ==========================================
	# DEBUG MODE SETUP
	# ==========================================
	if debug_mode:
		# 1. Create a dummy server so RPCs and Authority work locally
		var peer = ENetMultiplayerPeer.new()
		peer.create_server(9999) # Arbitrary port
		multiplayer.multiplayer_peer = peer
		
		# Force name to 1 (Server ID) so label and damage logic work
		name = "1"
		set_multiplayer_authority(1)
		
		# 2. Spawn a debug floor
		var debug_floor = CSGBox3D.new()
		debug_floor.size = Vector3(100, 1, 100) # Big platform
		debug_floor.use_collision = true
		debug_floor.top_level = true # Prevents the floor from moving WITH the player
		debug_floor.global_position = global_position - Vector3(0, 1, 0)
		
		# Optional: Add a checkerboard or basic color so you can see movement
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color.DARK_GRAY
		debug_floor.material = mat
		
		add_child(debug_floor)
		
		# 3. Add a sun so the scene isn't pitch black
		var debug_light = DirectionalLight3D.new()
		debug_light.top_level = true
		debug_light.rotation_degrees = Vector3(-45, 45, 0)
		add_child(debug_light)
		
		print("--- DEBUG MODE ACTIVE: Local Server & Floor Generated ---")

	# ==========================================
	# STANDARD SETUP
	# ==========================================
	target_position = global_position
	target_rotation = global_rotation
	
	_setup_synchronizer()
	
	name_label_instance = MERC_LABEL.instantiate()
	add_child(name_label_instance)
	
	# Position it slightly above the player (Adjust the Y value based on your model height)
	name_label_instance.position = Vector3(0, 1.6, 0) 
	
	# Pass the player's network ID into the label so it knows whose name to grab
	name_label_instance.setup(name.to_int())
	
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
		name_label_instance.hide() #hide it local
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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
	
	if dead: return
	if camera: camera.fov = camera_fov
	
	var input = Vector2.ZERO
	
	if ClientUI.chat_input.text == "":
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
	if ClientUI.menu.visible: return
	if dead: return
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

# ==========================================
# ABILITY MANAGEMENT (SERVER ONLY)
# ==========================================

func add_ability(ability: Ability) -> void:
	if not multiplayer.is_server(): return
	# The server tells EVERYONE (including itself) to attach this specific node
	_sync_add_ability.rpc(ability.get_path())
	
func remove_ability(ability: Ability) -> void:
	if not multiplayer.is_server(): return
	
	# The server tells EVERYONE to remove this specific node
	_sync_remove_ability.rpc(ability.get_path())

# ==========================================
# TEAM FIGHTING STUFF
# ==========================================

func sync_team_database(new_database: Dictionary) -> void:
	player_teams = new_database
	
	# Update our own team based on our multiplayer ID (Node name)
	var my_id = name.to_int()
	if player_teams.has(my_id):
		team = player_teams[my_id]
		
		# Update the UI color
		if name_label_instance and TEAM_COLORS.has(team):
			name_label_instance.modulate = TEAM_COLORS[team]

# ==========================================
# ABILITY SYNCHRONIZATION (ALL PEERS)
# ==========================================

@rpc("any_peer", "call_local", "reliable")
func _sync_add_ability(ability_path: NodePath) -> void:
	# 1. Find the physical ability node in the world using its path
	var ability_node = get_node_or_null(ability_path)
	if not ability_node: 
		push_error("Sync Error: Could not find Ability at path: ", ability_path)
		return
		
	# 2. Resolve keybinds
	ability_node.equip_ability(abilities)
	ability_node.show()
	for i in ability_node.get_children():
		if i is Node3D:
			i.show()
	
	# 3. Add to the local tracking array
	if not abilities.has(ability_node):
		abilities.append(ability_node)
		
	# 4. Attach it to the Merc (Only reparent if it isn't already attached)
	if ability_node.get_parent() != self:
		ability_node.reparent(self) 
		
	# 5. Refresh the local UI
	if abilites_ui and abilites_ui.has_method("generate_ui"):
		abilites_ui.generate_ui(self)
	
	ability_node.activate(abilities, self)

@rpc("any_peer", "call_local", "reliable")
func _sync_remove_ability(ability_path: NodePath) -> void:
	var ability_node = get_node_or_null(ability_path)
	if not ability_node: return
	
	if abilities.has(ability_node):
		# 1. Remove from the local tracking array
		abilities.erase(ability_node)
		
		# 2. Trigger the cleanup function you wrote earlier
		ability_node.dequip_ability()
		
		# 3. Refresh the local UI so it disappears from the screen
		if abilites_ui and abilites_ui.has_method("generate_ui"):
			abilites_ui.generate_ui(self)


@rpc("any_peer", "call_remote", "unreliable")
func receive_pos_from_server(pos: Vector3, rot: Vector3):
	# Don't move them yet! Just update the target.
	target_position = pos
	target_rotation = rot

@rpc("any_peer", "call_remote", "reliable")
func take_damage(damage: float):
	# 1. Securely get the ID of the person who shot you
	var attacker_id = multiplayer.get_remote_sender_id()
	
	# 2. Check the local database for their team
	if player_teams.has(attacker_id):
		var attacker_team = player_teams[attacker_id]
		
		# 3. Filter friendly fire
		if attacker_team == team and team != "default":
			return # Block the damage!
			
	# Apply damage if they pass the check
	health -= damage
	
	# TELL EVERYONE TO FLASH THIS PLAYER YELLOW
	_sync_flash_damage.rpc() 
	
	if health <= 0 and not dead:
		dead = true
		death_effects.rpc()
		die.rpc_id(1)
	else:
		emit_signal("took_damage")

@rpc("authority", "call_local", "unreliable")
func _sync_flash_damage() -> void:
	if not visual_body: return
	
	# 1. Create a bright, unshaded yellow material
# 1. Create a semi-transparent yellow material
	var flash_mat = StandardMaterial3D.new()
	# The 4th number (0.4) is the alpha/opacity. 0.0 is invisible, 1.0 is solid.
	flash_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.4) 
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA # Required for opacity to work
	
	# 2. Iterate through every single child inside the visual body
	_apply_overlay_recursive(visual_body, flash_mat)
	
	# 3. Wait for the flash duration
	await get_tree().create_timer(0.15).timeout
	
	# 4. Strip the overlay off everything
	if is_instance_valid(visual_body):
		_apply_overlay_recursive(visual_body, null)


# --- The Recursive Search Function ---
func _apply_overlay_recursive(current_node: Node, mat: Material) -> void:
	# If the node can be rendered in 3D, apply the overlay
	if current_node is GeometryInstance3D:
		current_node.material_overlay = mat
		
	# Recursively call this exact function on all children of the current node
	for child in current_node.get_children():
		_apply_overlay_recursive(child, mat)

@rpc("any_peer", "call_local")
func death_effects():
	pass

@rpc("authority", "call_remote", "reliable")
func die():
	emit_signal("died", self)

func custom_process(delta : float):
	if health >= 250.0:
		health = 250.0
	else:
		if heal_delay.is_stopped():
			take_damage(health_per_sec*-1)
			print(health)
			heal_delay.start()
		
		
	pass
	pass #use this for addons, physics process is used for default movement
func custom_ready():
	pass
