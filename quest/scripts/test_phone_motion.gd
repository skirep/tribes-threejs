extends SceneTree
const Motion = preload("res://scripts/phone_motion.gd")
func _initialize() -> void:
	var m := Motion.new()
	# A quarter turn must rotate the view, including when no gravity is available.
	for i in range(120):
		m.update(Vector3(0,PI/2,0),Vector3.ZERO,1.0/120.0)
	assert((m.view_basis()*Vector3.FORWARD).distance_to(Vector3.LEFT)<0.001)
	# Complete 360-degree turns stay normalized and do not hit Euler angle limits.
	for i in range(360):
		m.update(Vector3(0,PI/2,0),Vector3.ZERO,1.0/120.0)
	assert(m.view_basis().is_equal_approx(Basis.IDENTITY))
	# Consistent gravity must not undo an actual pitch movement.
	m.recenter()
	m.update(Vector3.ZERO,Vector3.DOWN*9.81,1.0/120.0)
	for i in range(120):
		var truth := Quaternion(Vector3.RIGHT,(i+1)*PI/240.0)
		var gravity := truth.inverse()*(Vector3.DOWN*9.81)
		m.update(Vector3(PI/2,0,0),gravity,1.0/120.0)
	assert((m.view_basis()*Vector3.FORWARD).distance_to(Vector3.UP)<0.001)
	m.recenter()
	assert(m.view_basis().is_equal_approx(Basis.IDENTITY))
	m.set_enabled(false)
	m.update(Vector3(10,10,10),Vector3.DOWN*9.81,0.1)
	assert(m.view_basis().is_equal_approx(Basis.IDENTITY))
	# Touch look works even with the gyro disabled or unavailable.
	m.drag(Vector2(90,20))
	assert(not m.view_basis().is_equal_approx(Basis.IDENTITY))
	assert(absf(m.view_basis().determinant()-1.0)<0.0001)
	m.recenter()
	m.set_enabled(true)
	m.update(Vector3.UP,Vector3.ZERO,5.0)
	assert(m.attitude.get_angle()<0.101)
	print("PHONE_MOTION_OK: rotation, gravity, full turns, touch, recenter and resume guard")
	quit(0)
