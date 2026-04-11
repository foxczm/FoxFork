extends Path3D
class_name CameraFollowPath

signal done_dolley

@export var easing_graph : Curve
@onready var path_follow_3d: PathFollow3D = $PathFollow3D
@onready var marker_3d: Marker3D = $CameraTargetPoint

func ease_dolley(duration: float):
	
	# DIAGNOSTIC 1: Is the node actually awake?
	if not can_process():
		printerr("🚨 ERROR: " + self.name + " (or its parent Lobby) is set to PROCESS_MODE_DISABLED! The Tween will pause forever.")
		# We force it to emit here so your whole game doesn't permanently freeze while testing
		done_dolley.emit() 
		return

	# DIAGNOSTIC 2: Did you assign the Curve in the Inspector?
	if easing_graph == null:
		printerr("🚨 ERROR: easing_graph is null! You forgot to add a Curve resource to the Inspector for this path.")
		done_dolley.emit()
		return
		
	# DIAGNOSTIC 3: Did the node reference break?
	if path_follow_3d == null:
		printerr("🚨 ERROR: path_follow_3d is null! Check your node paths.")
		done_dolley.emit()
		return
		
	# Kill any existing tweens on this node to prevent conflicts
	var tween = create_tween()
	
	# Tween a value (t) from 0.0 to 1.0 over the specified duration
	# We pass 't' into easing_graph.sample() to get the curved value, 
	# then apply it to progress_ratio.
	tween.tween_method(
		func(t: float): path_follow_3d.progress_ratio = easing_graph.sample(t),
		0.0, 
		1.0, 
		duration
	)
	await tween.finished
	done_dolley.emit()

func set_last_dolley_point(path :CameraFollowPath):
	curve.remove_point(-1)
	curve.add_point(to_local(path.to_global(path.curve.get_point_position(0))))
