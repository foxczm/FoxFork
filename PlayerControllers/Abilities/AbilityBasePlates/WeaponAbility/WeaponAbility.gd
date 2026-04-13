@abstract class_name WeaponAbility extends Ability

@abstract func shoot()
@abstract func equip()
@abstract func dequip()
var merc : Merc

##
## DO NOT FREAKING OVERRIDE ACTIVATE FOR THE WEAPON CLASS THIS EXISTS HERE 
##
func activate(abilities : Array[Ability], merc : Merc):
	if !currently_active:
		currently_active = true
		for i in abilities:
			if i is WeaponAbility and i != self:
				i.dequip()
				i.currently_active = false
		equip()
		self.merc = merc

func connected_process():
	pass
