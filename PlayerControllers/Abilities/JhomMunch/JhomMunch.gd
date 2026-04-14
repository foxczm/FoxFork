extends WeaponAbility

@onready var hand: RemoteTransform3D = $Hand
@onready var grenade: RigidBody3D = $Grenade
@onready var fuse_timer: Timer = $FuseTimer
@onready var cpu_particles_3d: CPUParticles3D = $Grenade/CPUParticles3D
@onready var explosion_radius: Area3D = $Grenade/ExplosionRadius
@onready var anim_player: AnimationPlayer = $AnimationPlayer

@export var cool_down := 5.0
@export var fuse_time := 4.0
@export var throw_strength = 5.0
@export var damage = 70.0
@export var self_dmg: float = 50.0

var holding_about_to_throw : bool = false
var thrown : bool = false

func _process(_delta: float) -> void:
	if !currently_active: return
	if Input.is_action_just_pressed("left_click") and not thrown:
		holding_about_to_throw = true
		anim_player.play("hold_to_throw")
		fuse_timer.start(fuse_time)
		
	if Input.is_action_just_released("left_click") and holding_about_to_throw and !thrown:
		holding_about_to_throw = false
		thrown = true
		shoot()
	

func shoot():
	# Detach the grenade from the hand and throw it
	(get_parent() as Merc).take_damage(self_dmg)
	print(merc.health)
	anim_player.play("throw")
	await anim_player.animation_finished
	hand.set_deferred("remote_path", null)
	grenade.freeze = false
	grenade.apply_central_impulse(-merc.camera.global_basis.z * throw_strength) 

func equip():
	show()
	anim_player.play("equip")
	anim_player.queue("idle")
	
func dequip():
	anim_player.play("dequip")
	await anim_player.animation_finished
	hide()

@rpc("any_peer", "call_local", "reliable")
func explode():
	# Only the authority should calculate and send damage
	if is_multiplayer_authority():
		for i in explosion_radius.get_overlapping_bodies():
			if i != null and i is Merc:
				i.take_damage.rpc_id(i.name.to_int(), damage) 
	
	# Everything below this runs locally for all clients (Visuals/Cleanup)
	if cpu_particles_3d:
		cpu_particles_3d.emitting = true
	
	grenade.set_deferred("freeze", true)
	
	await cpu_particles_3d.finished
	reset_grenade()

func reset_grenade():
	
	#Kill leftover momentum so it doesn't fly off when un-frozen later
	grenade.linear_velocity = Vector3.ZERO
	grenade.angular_velocity = Vector3.ZERO
	
	grenade.global_transform = hand.global_transform
	
	#Re-link the RemoteTransform3D so the grenade follows the hand again
	hand.set_deferred("remote_path", hand.get_path_to(grenade))
	
	grenade.visible = true
	thrown = false
	
	#playing animations for smooth
	equip()

func _on_fuse_timer_timeout() -> void:
	if grenade and is_multiplayer_authority():
		explode.rpc()
