extends Node3D

@export var tracer_color: Color = Color(1.0, 0.9, 0.2) # Bright yellow
@export var tracer_width: float = 0.05
@export var fade_duration: float = 0.15 # How fast it shrinks (seconds)

@rpc("any_peer","call_local","unreliable")
func _create_tracer_effect(global_start: Vector3, global_end: Vector3) -> void:
	# If we shoot at a wall zero inches away, don't draw anything
	var distance = global_start.distance_to(global_end)
	if distance < 0.1: return 

	# --- SETUP THE MESH ---
	var mesh_instance = MeshInstance3D.new()
	
	# 1. THE MAGIC BULLET: Force this node to ignore all parent transforms.
	# It will now operate strictly in absolute global coordinates.
	mesh_instance.set_as_top_level(true) 
	
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(1, 1, 1) # Base 1x1x1 size so scale works perfectly
	mesh_instance.mesh = box_mesh
	
	# Make it glow and ignore lighting
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = tracer_color
	mesh_instance.material_override = material

	# 2. ADD TO CURRENT SCENE
	# Always add 3D objects to the current_scene, not the root Window.
	get_tree().current_scene.add_child(mesh_instance)

	# --- POSITION AND ROTATE ---
	# Put the center of the mesh halfway between the gun and the impact point
	mesh_instance.global_position = global_start.lerp(global_end, 0.5)
	
	# Point the Z-axis of the mesh directly at the impact point
	var up = Vector3.UP if abs(global_start.direction_to(global_end).y) < 0.99 else Vector3.RIGHT
	mesh_instance.look_at(global_end, up)

	# --- SCALE & TWEEN (THE SHRINK EFFECT) ---
	# Start scale: X/Y are the width, Z is the exact distance traveled
	mesh_instance.scale = Vector3(tracer_width, tracer_width, distance)
	
	var tween = create_tween()
	# We animate the scale to Vector3(0, 0, distance). 
	# This shrinks the width to nothing, but keeps the length the same!
	tween.tween_property(mesh_instance, "scale", Vector3(0.0, 0.0, distance), fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Delete the node automatically when the animation finishes
	tween.tween_callback(mesh_instance.queue_free)
