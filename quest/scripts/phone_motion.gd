extends RefCounted
## Relative screen-space orientation: Android sensor axes are already remapped
## to display rotation by Godot. Apply local angular velocity without Euler locks.
var enabled := true
var attitude := Quaternion.IDENTITY
var touch_offset := Quaternion.IDENTITY
var gravity_reference := Vector3.ZERO

func update(angular_velocity: Vector3, gravity: Vector3, delta: float) -> void:
	if not enabled or delta <= 0.0:
		return
	# Do not integrate a large stale step after a system pause.
	var dt := minf(delta,0.1)
	var speed := angular_velocity.length()
	if speed > 0.0001:
		attitude = (attitude * Quaternion(angular_velocity/speed,speed*dt)).normalized()
	# Gentle gravity feedback limits tilt drift. Heading remains relative; the
	# explicit Center button resets yaw drift without requiring a compass.
	if gravity.length() > 1.0:
		var observed := (attitude * gravity.normalized()).normalized()
		if gravity_reference.is_zero_approx():
			gravity_reference = observed
		else:
			var correction := Quaternion(observed,gravity_reference)
			attitude = (Quaternion.IDENTITY.slerp(correction,1.0-exp(-0.6*dt)) * attitude).normalized()

func drag(relative: Vector2) -> void:
	var yaw := Quaternion(Vector3.UP,-relative.x*0.004)
	var pitch := Quaternion(Vector3.RIGHT,-relative.y*0.004)
	touch_offset = (yaw * touch_offset * pitch).normalized()

func recenter() -> void:
	attitude = Quaternion.IDENTITY
	touch_offset = Quaternion.IDENTITY
	gravity_reference = Vector3.ZERO

func set_enabled(value: bool) -> void:
	enabled = value
	gravity_reference = Vector3.ZERO

func view_basis() -> Basis:
	return Basis((touch_offset*attitude).normalized())
