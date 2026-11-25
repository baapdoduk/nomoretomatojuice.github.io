extends "res://tests/unit/test_combat_base.gd"
## AttackRunner: repeats, placement, projectiles, timing scale, cancel.

func _log_runner(runner: AttackRunner) -> Dictionary:
	var log := {"telegraph": [], "active": [], "resolved": [], "finished": []}
	runner.telegraph_started.connect(func(_p: AttackPattern, i: int) -> void: log["telegraph"].append([i, Engine.get_physics_frames()]))
	runner.active_started.connect(func(_p: AttackPattern, i: int) -> void: log["active"].append([i, Engine.get_physics_frames()]))
	runner.attacks_resolved.connect(func(_p: AttackPattern) -> void: log["resolved"].append(Engine.get_physics_frames()))
	runner.pattern_finished.connect(func(_p: AttackPattern) -> void: log["finished"].append(Engine.get_physics_frames()))
	return log

func test_sequential_drop_spawns_n_areas_at_interval_following_target() -> void:
	var target := make_target(Vector2(200, 100), 99)
	var runner := make_runner(Vector2(100, 100))
	var p: AttackPattern = load("res://resources/combat/sequential_drop.tres")
	assert_eq(p.repeat_count, 5, "resource: 5 drops")
	assert_almost_eq(p.repeat_interval, 0.35, 0.0001, "resource: 0.35 s")
	var positions: Array[Vector2] = []
	runner.area_spawned.connect(func(a: AttackArea) -> void: positions.append(a.global_position))
	var log := _log_runner(runner)
	var moved := [0]
	runner.telegraph_started.connect(func(_p: AttackPattern, _i: int) -> void:
		moved[0] += 1
		target.global_position += Vector2(30, 0))
	runner.run(p)
	await wait_until(func() -> bool: return log["telegraph"].size() >= 5, 4.0)
	assert_eq(log["telegraph"].size(), 5, "5 areas spawned")
	var t: Array = log["telegraph"]
	for i in range(1, t.size()):
		assert_eq(t[i][0], i, "repeat index order")
		assert_almost_eq(t[i][1] - t[0][1], i * 0.35 * 60.0, 1.0, "repeat %d at i*0.35 s" % i)
	for i in positions.size():
		assert_vec_almost_eq(positions[i], Vector2(200 + 30 * i, 100), 0.001, "drop %d follows target" % i)
	await wait_until(func() -> bool: return not log["finished"].is_empty(), 10.0)
	assert_eq(log["active"].size(), 5, "5 active windows")
	var expected_resolve := 4 * 0.35 + p.telegraph_time + p.active_time
	assert_almost_eq(log["resolved"][0] - t[0][1], expected_resolve * 60.0, 2.0, "resolved after last active window")
	assert_almost_eq(log["finished"][0] - log["resolved"][0], p.recovery_time * 60.0, 1.0, "recovery time")

func test_step_line_and_rotating_placement() -> void:
	var target := make_target(Vector2(200, 100))
	var runner := make_runner(Vector2(100, 100))
	var p := make_pattern(AttackPattern.Shape.CIRCLE)
	p.origin = AttackPattern.Origin.SELF
	p.repeat_count = 3
	p.repeat_targeting = AttackPattern.RepeatTargeting.STEP_LINE
	p.repeat_step_distance = 50.0
	runner.run(p)
	for i in 3:
		var pl := runner.compute_placement(i)
		assert_vec_almost_eq(pl[0], Vector2(100 + 50 * i, 100), 0.001, "step %d" % i)
	runner.cancel()
	var r := make_pattern(AttackPattern.Shape.LINE)
	r.origin = AttackPattern.Origin.SELF
	r.aim = AttackPattern.Aim.ROTATING
	r.fixed_angle_degrees = 10.0
	r.aim_step_degrees = 45.0
	r.repeat_count = 3
	runner.run(r)
	for i in 3:
		var pl2 := runner.compute_placement(i)
		assert_almost_eq(rad_to_deg(pl2[1]), 10.0 + 45.0 * i, 0.001, "rotating aim %d" % i)
	runner.cancel()
	target.queue_free()

func test_no_target_aims_forward() -> void:
	var runner := make_runner(Vector2(50, 50))
	runner.rotation = PI / 2.0
	var p := make_pattern(AttackPattern.Shape.LINE)
	p.origin = AttackPattern.Origin.TARGET  # falls back to self without a player
	runner.run(p)
	var area := runner.get_spawned()[0] as AttackArea
	assert_vec_almost_eq(area.global_position, Vector2(50, 50), 0.001, "origin falls back to self")
	assert_almost_eq(area.global_rotation, PI / 2.0, 0.0001, "aims along forward rotated by runner")
	runner.cancel()

func test_projectile_pattern_fires_fan_after_telegraph() -> void:
	var target := make_target(Vector2(300, 100), 99)
	var runner := make_runner(Vector2(100, 100))
	var p: AttackPattern = load("res://resources/combat/cone_volley.tres")
	var projectiles: Array[Projectile] = []
	runner.projectile_spawned.connect(func(pr: Projectile) -> void: projectiles.append(pr))
	runner.run(p)
	var area := runner.get_spawned()[0] as AttackArea
	assert_false(area.deals_damage, "projectile pattern: area is warning only")
	await wait_physics_frames(frames(p.telegraph_time) - 2)
	assert_eq(projectiles.size(), 0, "no projectiles during telegraph")
	await wait_physics_frames(4)
	assert_eq(projectiles.size(), p.projectile_count, "fan fired")
	var angles: Array[float] = []
	for pr in projectiles:
		angles.append(rad_to_deg(pr.velocity.angle()))
		assert_almost_eq(pr.velocity.length(), p.projectile_speed, 0.01, "speed")
		assert_eq(pr.source, runner.source, "source forwarded")
	assert_almost_eq(angles[0], -p.projectile_spread_degrees / 2.0, 0.01, "fan start")
	assert_almost_eq(angles[angles.size() - 1], p.projectile_spread_degrees / 2.0, 0.01, "fan end")
	await wait_physics_frames(frames(1.3))
	assert_eq(target_health(target).current, 98, "centre projectile hit the target once")

func test_timing_scale_applied_to_telegraph_and_recovery() -> void:
	GameState.set_setting(&"assist_combat_timing", true)
	var scale := GameState.get_combat_timing_scale()
	assert_true(scale > 1.0, "assist scale > 1")
	var runner := make_runner(Vector2(100, 100))
	var p := make_pattern()
	p.telegraph_time = 1.6
	p.active_time = 0.25
	p.recovery_time = 3.5
	var log := _log_runner(runner)
	runner.run(p)
	assert_almost_eq(runner.get_telegraph_time(), 1.6 * scale, 0.0001)
	assert_almost_eq(runner.get_recovery_time(), 3.5 * scale, 0.0001)
	await wait_until(func() -> bool: return not log["finished"].is_empty(), 15.0)
	var t0: int = log["telegraph"][0][1]
	assert_almost_eq(log["active"][0][1] - t0, 1.6 * scale * 60.0, 1.0, "scaled telegraph")
	assert_almost_eq(log["resolved"][0] - log["active"][0][1], 0.25 * 60.0, 1.0, "active unscaled")
	assert_almost_eq(log["finished"][0] - log["resolved"][0], 3.5 * scale * 60.0, 1.0, "scaled recovery")

func test_cancel_clears_areas_and_projectiles() -> void:
	var runner := make_runner(Vector2(100, 100))
	var p := make_pattern()
	p.repeat_count = 4
	p.repeat_interval = 0.1
	p.telegraph_time = 1.0
	runner.run(p)
	var finished := [0]
	runner.pattern_finished.connect(func(_p: AttackPattern) -> void: finished[0] += 1)
	await wait_physics_frames(frames(0.35))
	var fan := make_pattern()
	assert_eq(runner.get_spawned().size(), 4, "4 areas alive")
	var spawned := runner.get_spawned()
	runner.cancel()
	await wait_frames(2)
	for n in spawned:
		assert_false(is_instance_valid(n), "area freed by cancel")
	assert_false(runner.is_running)
	await wait_physics_frames(frames(1.0))
	assert_eq(runner.get_child_count(), 0, "nothing spawned after cancel")
	assert_eq(finished[0], 0, "no pattern_finished after cancel")
	# projectiles are cleared too
	fan.projectile_speed = 50.0
	fan.projectile_count = 3
	fan.projectile_spread_degrees = 30.0
	fan.telegraph_time = 0.0
	fan.active_time = 0.5
	runner.run(fan)
	await wait_physics_frames(2)
	assert_eq(runner.get_spawned().size(), 4, "area + 3 projectiles")
	runner.cancel()
	await wait_frames(2)
	assert_eq(runner.get_child_count(), 0, "projectiles freed by cancel")

func test_projectile_telegraph_lanes_contain_projectile_paths() -> void:
	for path in ["res://resources/combat/cone_volley.tres", "res://resources/combat/line_shot.tres", "res://resources/combat/mogu_nata_volley.tres"]:
		var p: AttackPattern = load(path)
		var runner := make_runner(Vector2(200, 200))
		runner.rotation = 0.4  # no player: aims along forward rotated by the runner
		var lanes: Array = []
		runner.area_spawned.connect(func(a: AttackArea) -> void:
			for i in a.get_polygons().size():
				lanes.append(a.get_telegraph_polygon_global(i)))
		var projectiles: Array[Projectile] = []
		runner.projectile_spawned.connect(func(pr: Projectile) -> void: projectiles.append(pr))
		runner.run(p)
		assert_eq(lanes.size(), p.projectile_count, "one lane per projectile " + path)
		await wait_until(func() -> bool: return projectiles.size() == p.projectile_count, 5.0)
		var outside := 0
		var samples := 0
		while true:
			var alive := 0
			for i in projectiles.size():
				var pr := projectiles[i]
				if not is_instance_valid(pr) or pr.is_queued_for_deletion():
					continue
				alive += 1
				samples += 1
				var r := pr.radius * 0.99
				for o in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
					if not Geometry2D.is_point_in_polygon(pr.global_position + o, lanes[i]):
						outside += 1
			if alive == 0:
				break
			await wait_physics_frames(1)
		assert_true(samples > p.projectile_count * 20, "sampled whole flights " + path)
		assert_eq(outside, 0, "every projectile stays inside its lane " + path)
		runner.queue_free()
