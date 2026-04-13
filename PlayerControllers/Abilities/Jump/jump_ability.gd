extends Ability

@export_category("Jump Ability Settings")
@export var auto_bhop: bool = false ## If true, holding the button continuously jumps
@export var jump_cooldown: float = 0.25 ## Time before you can jump again
@export var jump_buffer_time: float = 0.15 ## How early you can press jump before hitting the ground
@export var jump_strength : float = 2.0
var current_cooldown: float = 0.0
var current_buffer: float = 0.0

# State tracking to tell the difference between a click and a hold
var is_held_this_frame: bool = false
var was_held_last_frame: bool = false

# We store the merc so _physics_process can check if it's on the floor
var current_merc: CharacterBody3D = null

func _physics_process(delta: float) -> void:
	if current_cooldown > 0:
		current_cooldown -= delta
		
	if current_buffer > 0:
		current_buffer -= delta
		
	# Attempt the jump if we have a buffered input and no cooldown
	if current_merc and current_buffer > 0 and current_cooldown <= 0:
		if current_merc.is_on_floor():
			current_merc.velocity.y += jump_strength
			
			# Consume the buffer so we don't double jump, and start the cooldown
			current_buffer = 0.0 
			current_cooldown = jump_cooldown
			
	# If the player is still holding the button, activate() will turn this back to true.
	was_held_last_frame = is_held_this_frame
	is_held_this_frame = false


func activate(abilities: Array[Ability], merc: Merc) -> void:
	is_held_this_frame = true
	current_merc = merc
	# If this is a brand NEW press, OR if they are allowed to hold it down:
	if !was_held_last_frame or auto_bhop:
		# Fill the jump buffer! 
		current_buffer = jump_buffer_time
