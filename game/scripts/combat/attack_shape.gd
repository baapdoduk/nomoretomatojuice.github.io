class_name AttackShape
extends RefCounted
## Single source of truth for attack geometry.
## build_polygon() returns ONE local-space polygon (origin at (0,0), aimed along +X)
## that AttackArea hands to both its Telegraph (drawing) and its CollisionPolygon2D
## (damage). Both nodes share the same parent transform, so the warning and the
## damage area are identical by construction.

## Every polygon of the attack's warning / hit geometry (local space).
## Area attacks: [build_polygon()]. Projectile attacks: one lane per projectile
## covering its whole flight (centre path 0..speed*lifetime, padded by the
## projectile radius on every side), rotated by its fan angle.
static func build_polygons(pattern: AttackPattern) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if pattern == null:
		return out
	if not pattern.is_projectile_attack():
		out.append(build_polygon(pattern))
		return out
	var r := pattern.projectile_radius
	var length := pattern.projectile_speed * pattern.projectile_lifetime
	var lane := PackedVector2Array([Vector2(-r, -r), Vector2(length + r, -r), Vector2(length + r, r), Vector2(-r, r)])
	for a in projectile_angles(pattern):
		out.append(Transform2D(a, Vector2.ZERO) * lane)
	return out

## Fan angle offsets (radians, relative to the aim) of a projectile pattern.
static func projectile_angles(pattern: AttackPattern) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := maxi(1, pattern.projectile_count)
	var spread := deg_to_rad(pattern.projectile_spread_degrees)
	for i in count:
		out.append(0.0 if count == 1 else -spread * 0.5 + spread * float(i) / float(count - 1))
	return out

## Local-space polygon of an AREA attack (counter-clockwise, no repeated closing point).
static func build_polygon(pattern: AttackPattern) -> PackedVector2Array:
	if pattern == null:
		return PackedVector2Array()
	match pattern.shape:
		AttackPattern.Shape.CONE:
			return cone(pattern.radius, pattern.cone_angle_degrees, pattern.segments)
		AttackPattern.Shape.LINE:
			return line(pattern.line_length, pattern.line_width)
		_:
			return circle(pattern.radius, pattern.segments)

static func circle(radius: float, segments: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := maxi(6, segments)
	for i in n:
		pts.append(Vector2.from_angle(TAU * float(i) / float(n)) * radius)
	return pts

## Apex at (0,0), opening along +X, arc at `length`.
static func cone(length: float, angle_degrees: float, segments: int = 32) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2.ZERO])
	var half := deg_to_rad(clampf(angle_degrees, 1.0, 359.0)) * 0.5
	var n := maxi(2, int(ceil(float(maxi(6, segments)) * (half * 2.0) / TAU)) + 1)
	for i in n + 1:
		var a := lerpf(-half, half, float(i) / float(n))
		pts.append(Vector2.from_angle(a) * length)
	return pts

## Rectangle from (0, -w/2) to (length, w/2).
static func line(length: float, width: float) -> PackedVector2Array:
	var hw := width * 0.5
	return PackedVector2Array([Vector2(0, -hw), Vector2(length, -hw), Vector2(length, hw), Vector2(0, hw)])

## Transforms a local polygon into global space.
static func to_global(xform: Transform2D, polygon: PackedVector2Array) -> PackedVector2Array:
	return xform * polygon

## Point-in-polygon test in the polygon's own space (used by tests / tools).
static func contains_point(polygon: PackedVector2Array, point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon)
