extends Spatial

onready var anim_player = $AnimationPlayer
onready var bullet_emitters_base : Spatial = $BulletEmitters
onready var bullet_emitters = $BulletEmitters.get_children()

export var automatic = false

export var shake_amount = 0.0
export var max_x = 5.0
export var max_y = 5.0
export var reduction = 1.0

var fire_point : Spatial
var bodies_to_exclude : Array = []

export var damage = 5

export var attack_rate = 0.2
var attack_timer : Timer
var can_attack = true

signal fired
signal shake

func _ready():
	attack_timer = Timer.new()
	attack_timer.wait_time = attack_rate
	attack_timer.connect("timeout", self, "finish_attack")
	attack_timer.one_shot = true
	add_child(attack_timer)
	
func init(_fire_point: Spatial, _bodies_to_exclude: Array):
	fire_point = _fire_point
	bodies_to_exclude = _bodies_to_exclude
	for bullet_emitter in bullet_emitters:
		bullet_emitter.set_damage(damage)
		bullet_emitter.set_bodies_to_exclude(bodies_to_exclude)
		
func attack(attack_input_just_pressed: bool, attack_input_held: bool):
	if !can_attack:
		return
	if automatic and !attack_input_held:
		return
	elif !automatic and !attack_input_just_pressed:
		return
	anim_player.stop()
	anim_player.play("fire")
	can_attack = false
#	attack_timer.start()
	 
func real_fire(): # check if you can add seperate things, maybe add seperate classes to the weapons 
	var start_transform = bullet_emitters_base.global_transform
	bullet_emitters_base.global_transform = fire_point.global_transform
	for bullet_emitter in bullet_emitters:
		bullet_emitter.fire()
	bullet_emitters_base.global_transform = start_transform #muzzle position 
	emit_signal("fired")
	emit_signal("shake", shake_amount, max_x, max_y, reduction)
	
func finish_attack(): 
	can_attack = true
	
func set_active():
	$AnimationPlayer.play("equip")
	can_attack = false
	$CrossHair.show()
	
func set_inactive():
	can_attack = false
#	hide()
	$CrossHair.hide()
	
func is_idle():
	return !anim_player.is_playing() or anim_player.current_animation == "idle"
	
func can_attack():
	can_attack = true
