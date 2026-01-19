extends Spatial

enum WEAPON_SLOTS {MACHETE, SHOTGUN, MG, SNIPER, ROCKET_LAUNCHER}
var slots_unlocked = {
	WEAPON_SLOTS.MACHETE:true,
	WEAPON_SLOTS.SHOTGUN:false,
	WEAPON_SLOTS.MG:false,
	WEAPON_SLOTS.SNIPER:true,
	WEAPON_SLOTS.ROCKET_LAUNCHER:false,
}

onready var anim_player = $AnimationPlayer
onready var weapons = $Weapons.get_children()
onready var alert_area_hearing = $AlertAreaHearing
onready var alert_area_los = $AlertAreaLos
var cur_slot = 0 
var fire_point : Spatial
var bodies_to_exclude : Array = []
var cur_weapon = null

func init(_fire_point: Spatial, _bodies_to_exclude: Array):
	fire_point = _fire_point
	bodies_to_exclude = _bodies_to_exclude
	for weapon in weapons:
		if weapon.has_method("init"):
			weapon.init(_fire_point, _bodies_to_exclude)
			
	weapons[WEAPON_SLOTS.MG].connect("fired", self, "alert_nearby_enemies")
	weapons[WEAPON_SLOTS.SHOTGUN].connect("fired", self, "alert_nearby_enemies")
	weapons[WEAPON_SLOTS.ROCKET_LAUNCHER].connect("fired", self, "alert_nearby_enemies")
	switch_to_weapon_slot(WEAPON_SLOTS.MACHETE)

func attack(attack_input_just_pressed: bool, attack_input_held: bool):
	if cur_weapon.has_method("attack"):
		cur_weapon.attack(attack_input_just_pressed, attack_input_held)
	
func switch_to_next_weapon():
	cur_slot = (cur_slot + 1) % slots_unlocked.size()
	if !slots_unlocked[cur_slot]:
		switch_to_next_weapon()
	else:
		switch_to_weapon_slot(cur_slot)
	
func switch_to_last_weapon():
	cur_slot = posmod((cur_slot - 1), slots_unlocked.size())
	if !slots_unlocked[cur_slot]:
		switch_to_last_weapon()
	else:
		switch_to_weapon_slot(cur_slot)
		
func switch_to_weapon_slot(slot_index):
	if slot_index < 0 or slot_index >= slots_unlocked.size():
		return
	if !slots_unlocked[cur_slot]:
		return
	disable_all_weapons() #makes other weapons invisible when switched
	cur_weapon = weapons[slot_index]
	if cur_weapon.has_method("set_active"):
		cur_weapon.set_active()
	else:
		#placeholder
		cur_weapon.show()
	
func disable_all_weapons():
	for weapon in weapons:
		if weapon.has_method("set_inactive"):
			weapon.set_inactive()
		else:
			weapon.hide()

func update_animation(velocity: Vector3, grounded: bool):
#	if cur_weapon.has_method("is_idle") and !cur_weapon.is_idle():
#		anim_player.play("idle")
	if !grounded or velocity.length() < 10.0:
		anim_player.play("idle", 0.05)
	anim_player.play("moving")
	
func alert_nearby_enemies():
	var nearby_enemies = alert_area_los.get_overlapping_bodies()
	for nearby_enemy in nearby_enemies:
		if nearby_enemy.has_method("alert"):
			nearby_enemy.alert(false)
			
func get_pickup(pickup_type, amount):
	match pickup_type:
		Pickup.PICKUP_TYPE.MG:
			if !slots_unlocked[WEAPON_SLOTS.MG]:
				slots_unlocked[WEAPON_SLOTS.MG] = true
				switch_to_weapon_slot(WEAPON_SLOTS.MG)
				cur_slot = 2
		Pickup.PICKUP_TYPE.SHOTGUN:
			if !slots_unlocked[WEAPON_SLOTS.SHOTGUN]:
				slots_unlocked[WEAPON_SLOTS.SHOTGUN] = true
				switch_to_weapon_slot(WEAPON_SLOTS.SHOTGUN)
				cur_slot = 1
		Pickup.PICKUP_TYPE.ROCKET_LAUNCHER:
			if !slots_unlocked[WEAPON_SLOTS.ROCKET_LAUNCHER]:
				slots_unlocked[WEAPON_SLOTS.ROCKET_LAUNCHER] = true
				switch_to_weapon_slot(WEAPON_SLOTS.ROCKET_LAUNCHER)
				cur_slot = 4
