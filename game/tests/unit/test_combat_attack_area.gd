extends "res://tests/unit/test_combat_base.gd"
## AttackArea: telegraph harmless, damage only inside the active window, once per activation.

func test_no_damage_during_telegraph_then_once_in_active() -> void:
	var target := make_target(Vector2(200, 100))
	var health := target_health(target)
	var runner := make_runner(Vector2(100, 100))
	var p := make_pattern(AttackPattern.Shape.CIRCLE)
	p.origin = AttackPattern.Origin.TARGET
	p.telegraph_time = 0.5
	p.active_time = 0.5
	runner.run(p)
	var area := runner.get_spawned()[0] as AttackArea
	var t0 := Engine.get_physics_frames()
	var active_frame := [-1]
	area.active_started.connect(func() -> void: active_frame[0] = Engine.get_physics_frames())
	await wait_physics_frames(frames(0.5) - 2)
	assert_eq(health.current, 5, "no damage during telegraph")
	assert_eq(area.phase, AttackArea.Phase.TELEGRAPH)
	assert_true(area.get_telegraph_progress() > 0.85, "progress near 1 at end of telegraph")
	await wait_physics_frames(4)
	assert_eq(health.current, 4, "hit once when active")
	assert_almost_eq(active_frame[0] - t0, frames(0.5), 1.0, "active starts after telegraph_time")
	await wait_physics_frames(frames(0.3))
	assert_eq(health.current, 4, "still one hit during the same activation")
	await wait_physics_frames(frames(0.3))
	assert_false(is_instance_valid(area) and not area.is_queued_for_deletion(), "area freed after active window")
	assert_eq(health.current, 4)

func test_target_outside_shape_not_hit() -> void:
	var target := make_target(Vector2(60, 100))  # behind the cone apex
	var other := Node2D.new()
	other.position = Vector2(300, 100)
	add_test_node(other)
	var runner := make_runner(Vector2(100, 100))
	runner.target = other  # aim to the right, away from the stand-in
	var p := make_pattern(AttackPattern.Shape.CONE)
	p.origin = AttackPattern.Origin.SELF
	p.radius = 150.0
	p.telegraph_time = 0.1
	p.active_time = 0.3
	runner.run(p)
	await wait_physics_frames(frames(0.5))
	assert_eq(target_health(target).current, 5, "outside cone: no damage")

func test_entering_after_active_window_not_hit() -> void:
	var target := make_target(Vector2(400, 400))
	var runner := make_runner(Vector2(100, 100))
	runner.target = target
	var p := make_pattern(AttackPattern.Shape.CIRCLE)
	p.origin = AttackPattern.Origin.SELF
	p.telegraph_time = 0.2
	p.active_time = 0.2
	runner.run(p)
	var area := runner.get_spawned()[0] as AttackArea
	area.active_ended.connect(func() -> void: target.global_position = Vector2(100, 100))
	await wait_physics_frames(frames(0.8))
	assert_eq(target_health(target).current, 5, "moved in after active ended: no damage")

func test_invulnerable_target_hit_later_in_same_activation() -> void:
	var target := make_target(Vector2(100, 100))
	var health := target_health(target)
	health.set_invulnerable_for(0.2)
	var runner := make_runner(Vector2(100, 100))
	var p := make_pattern()
	p.origin = AttackPattern.Origin.SELF
	p.telegraph_time = 0.0
	p.active_time = 0.5
	runner.run(p)
	await wait_physics_frames(frames(0.1))
	assert_eq(health.current, 5, "i-frames block")
	await wait_physics_frames(frames(0.3))
	assert_eq(health.current, 4, "hit once after i-frames end inside window")

func test_active_time_zero_still_damages_once() -> void:
	for tele in [0.2, 0.0]:
		var target := make_target(Vector2(100, 100))
		var runner := make_runner(Vector2(100, 100))
		var p := make_pattern()
		p.origin = AttackPattern.Origin.SELF
		p.telegraph_time = tele
		p.active_time = 0.0
		runner.run(p)
		await wait_physics_frames(frames(tele) + 6)
		assert_eq(target_health(target).current, 4, "active_time 0 hits once (telegraph %.1f)" % tele)
		assert_eq(runner.get_spawned().size(), 0, "area finished")
		target.queue_free()
		runner.queue_free()
		await wait_physics_frames(2)
