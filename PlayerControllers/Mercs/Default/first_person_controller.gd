extends Merc

@onready var DEBUGUI = $DEBUGUI

#use this for addons, physics process is used for default movement
func custom_process(delta : float): 
	DEBUGUI.text = str(snapped((velocity.length()), 0.01))

func custom_ready():
	pass
