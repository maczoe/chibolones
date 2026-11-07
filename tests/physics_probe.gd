extends SceneTree
## Physics probe: a dropped sphere must never fall through the board surface.
## Regression for the Jolt gotcha found during the POC: a body that spawns
## intersecting the static box can escape through it, so colliders must be
## aligned with the visible surface and marbles must spawn clear of it.
## Run: godot --headless --path . --script res://tests/physics_probe.gd

var failed := false


func _initialize() -> void:
	_run()


func _run() -> void:
	await physics_frame
	# Case A: flat, unrotated box, ball well above the surface.
	var root_a := Node3D.new()
	root.add_child(root_a)
	var body := StaticBody3D.new()
	root_a.add_child(body)
	var cshape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	cshape.shape = box
	cshape.position.y = -0.5  # top face at y = 0, like the board surface
	body.add_child(cshape)
	var ball := _ball()
	root_a.add_child(ball)
	ball.position = Vector3(0, 1.0, 0)
	var min_y_a := ball.position.y
	for i in 90:
		await physics_frame
		min_y_a = minf(min_y_a, ball.position.y)
	_check("A flat", ball, min_y_a)

	# Case B: box under a parent tilted like the board, ball clear of surface.
	var tilt := Node3D.new()
	tilt.rotation_degrees = Vector3(6, 0, 0)
	root.add_child(tilt)
	var body2 := StaticBody3D.new()
	tilt.add_child(body2)
	var cshape2 := CollisionShape3D.new()
	cshape2.shape = box
	cshape2.position.y = -0.5
	body2.add_child(cshape2)
	var ball2 := _ball()
	tilt.add_child(ball2)
	ball2.position = Vector3(0, 0.14, -2)
	var min_y_b := ball2.position.y
	for i in 90:
		await physics_frame
		min_y_b = minf(min_y_b, ball2.position.y)
	_check("B tilted", ball2, min_y_b)

	if failed:
		quit(1)
	else:
		print("PHYSICS PROBE OK")
		quit(0)


func _check(label: String, ball: RigidBody3D, min_y: float) -> void:
	# The ball may keep rolling downhill forever; falling through does not.
	if min_y < -0.01:
		push_error("PHYSICS PROBE FAIL: %s fell through (min_y=%.3f)" % [label, min_y])
		print("PHYSICS PROBE FAIL: %s fell through (min_y=%.3f)" % [label, min_y])
		failed = true
	else:
		print("%s: never below y=%.3f" % [label, min_y])


func _ball() -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = 1.0
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.09
	cs.shape = sh
	b.add_child(cs)
	return b
