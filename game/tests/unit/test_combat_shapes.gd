extends "res://tests/unit/test_combat_base.gd"
## AttackShape geometry + telegraph/collision identity.

func test_circle_polygon_dimensions() -> void:
	var p := make_pattern(AttackPattern.Shape.CIRCLE)
	p.radius = 40.0
	p.segments = 24
	var poly := AttackShape.build_polygon(p)
	assert_eq(poly.size(), 24, "segment count")
	for v in poly:
		assert_almost_eq(v.length(), 40.0, 0.001, "on radius")

func test_cone_polygon_dimensions() -> void:
	var p := make_pattern(AttackPattern.Shape.CONE)
	p.radius = 100.0
	p.cone_angle_degrees = 60.0
	var poly := AttackShape.build_polygon(p)
	assert_vec_almost_eq(poly[0], Vector2.ZERO, 0.001, "apex at origin")
	var max_angle := 0.0
	for i in range(1, poly.size()):
		assert_almost_eq(poly[i].length(), 100.0, 0.001, "arc at length")
		max_angle = maxf(max_angle, absf(rad_to_deg(poly[i].angle())))
	assert_almost_eq(max_angle, 30.0, 0.01, "half angle")
	assert_true(AttackShape.contains_point(poly, Vector2(50, 0)), "inside along aim")
	assert_false(AttackShape.contains_point(poly, Vector2(-10, 0)), "behind apex outside")
	assert_false(AttackShape.contains_point(poly, Vector2(50, 40)), "outside angle")

func test_line_polygon_dimensions() -> void:
	var p := make_pattern(AttackPattern.Shape.LINE)
	p.line_length = 200.0
	p.line_width = 20.0
	var poly := AttackShape.build_polygon(p)
	assert_eq(poly.size(), 4)
	var rect := Rect2(poly[0], Vector2.ZERO)
	for v in poly:
		rect = rect.expand(v)
	assert_vec_almost_eq(rect.position, Vector2(0, -10), 0.001)
	assert_vec_almost_eq(rect.size, Vector2(200, 20), 0.001)

func test_telegraph_polygon_equals_collision_polygon() -> void:
	var target := make_target(Vector2(260, 140))
	for shape in [AttackPattern.Shape.CIRCLE, AttackPattern.Shape.CONE, AttackPattern.Shape.LINE]:
		var runner := make_runner(Vector2(100, 100))
		var p := make_pattern(shape)
		p.origin = AttackPattern.Origin.SELF
		p.origin_offset = Vector2(5, -3)
		p.telegraph_time = 1.0
		runner.run(p)
		var areas := runner.get_spawned()
		assert_eq(areas.size(), 1, "one area")
		var area := areas[0] as AttackArea
		await wait_physics_frames(2)
		var tele := area.get_telegraph_polygon_global()
		var coll := area.get_collision_polygon_global()
		assert_true(tele.size() >= 3, "polygon built")
		assert_eq(tele.size(), coll.size(), "same vertex count")
		for i in tele.size():
			assert_vec_almost_eq(tele[i], coll[i], 0.0001, "vertex %d shape %d" % [i, shape])
		assert_eq(area.collision.polygon, AttackShape.build_polygon(p), "collision uses AttackShape polygon")
		assert_eq(area.visual.polygon, area.collision.polygon, "same local polygon")
		# rotated toward the target, positioned at origin + offset
		assert_almost_eq(area.global_rotation, (target.global_position - runner.global_position).angle(), 0.0001, "aim")
		assert_vec_almost_eq(area.global_position, Vector2(105, 97), 0.0001, "origin + offset")
		runner.cancel()
