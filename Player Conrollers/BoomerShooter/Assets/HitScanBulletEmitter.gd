extends Spatial

var hit_effect = preload("res://effects/BulletHitEffect.tscn")
var laser = preload("res://environment/assets/Weapons/HitScanBulletlaserr.tres")

export var distance = 10000
export var weapon = ""
export var color = Color(0,0,0,0)
export var spread = 2
var bodies_to_exclude = []
var damage = 1
var original_rotation = rotation_degrees

onready var meshObj = $ImmediateGeometry

func _ready():
	original_rotation = rotation_degrees

func _process(delta):
	rotation_degrees = lerp(rotation_degrees, original_rotation, .2)
	
func set_damage(_damage: int):
	damage = _damage
	
func set_bodies_to_exclude(_bodies_to_exclude: Array):
	bodies_to_exclude = _bodies_to_exclude
	
func fire():
	rotate_x(deg2rad(rand_range(-spread, spread)))
	rotate_y(deg2rad(rand_range(-spread, spread)))
	laser.emission = color
	var space_state = get_world().get_direct_space_state()
	var our_pos = global_transform.origin
	var result = space_state.intersect_ray(our_pos, our_pos - global_transform.basis.z * distance, bodies_to_exclude, 1 + 4, true, true)
#	draw_line(our_pos, result.position)
	if result and result.collider.has_method("hurt"):
		result.collider.hurt(damage, result.normal, weapon)
	elif result:
		var hit_effect_inst = hit_effect.instance()
		get_tree().get_root().add_child(hit_effect_inst)
		hit_effect_inst.global_transform.origin = result.position
		
		if result.normal.angle_to(Vector3.UP) < 0.00005:
			return
		if result.normal.angle_to(Vector3.DOWN) < 0.00005:
			hit_effect_inst.rotate(Vector3.RIGHT, PI)
			return
		
		var y = result.normal
		var x = y.cross(Vector3.UP)
		var z = x.cross(y)
		
		hit_effect_inst.global_transform.basis = Basis(x, y, z)


func draw_line(start, end):
	show()
	var timer := Timer.new()
	add_child(timer)
	timer.wait_time = .08
	timer.one_shot = true
	timer.start()
	timer.connect("timeout", self, "_on_timer_timeout")
	meshObj.clear()
	meshObj.begin(Mesh.PRIMITIVE_LINES, null)
	meshObj.add_vertex(to_local(start))
	meshObj.add_vertex(to_local(end))
#	meshObj.add_vertex(to_local(end + Vector3(0,.2,0)))
#	meshObj.set_color(Color(90,3,3,.5))
	meshObj.end()

func _on_timer_timeout() -> void:
	hide()

 

