extends PlayerTestCase
## SideViewMotor: jump arc, coyote time, jump buffer, variable height, dash.


func _measure_jump_height(p: Player, hold_frames: int) -> float:
	var start_y := p.global_position.y
	var min_y := start_y
	press_jump()
	for i in 90:
		await wait_physics_frames(1)
		if i + 1 >= hold_frames:
			release_jump()
		min_y = minf(min_y, p.global_position.y)
	release_jump()
	return start_y - min_y


func test_jump_apex_matches_formula() -> void:
	var p := await make_side_player_on_floor()
	assert_true(p.is_on_floor(), "settled on floor")
	var cfg := p.config
	var expected := cfg.jump_velocity * cfg.jump_velocity / (2.0 * cfg.gravity)
	var h := await _measure_jump_height(p, 999)
	assert_almost_eq(h, expected, 5.0, "apex ~ v^2/2g (73.5 px)")
	assert_true(p.is_on_floor(), "landed again")


func test_short_tap_jumps_lower_than_held() -> void:
	var p := await make_side_player_on_floor()
	var held := await _measure_jump_height(p, 999)
	await wait_physics_frames(5)
	var tapped := await _measure_jump_height(p, 2)
	assert_true(tapped < held * 0.5, "tap %.1f should be well below held %.1f" % [tapped, held])
	assert_true(tapped > 4.0, "tap still leaves the ground (%.1f)" % tapped)


func _setup_ledge() -> Array:
	# Floor ends at x = 0; pit below.
	make_block(Rect2(-2000, 0, 2000, 40))
	var p := make_player(Player.MovementMode.SIDE_VIEW, Vector2(-40, -1))
	var jumps := [0]
	p.jumped.connect(func() -> void: jumps[0] += 1)
	await wait_physics_frames(3)
	input.move = Vector2.RIGHT
	var left := await wait_until(func() -> bool: return not p.is_on_floor(), 2.0)
	assert_true(left, "walked off the ledge")
	input.move = Vector2.ZERO
	return [p, jumps]


func test_coyote_jump_inside_window() -> void:
	var r: Array = await _setup_ledge()
	var p: Player = r[0]
	await wait_physics_frames(4)  # ~0.067 s after leaving (< 0.12 s)
	press_jump()
	await wait_physics_frames(2)
	assert_eq(r[1][0], 1, "coyote jump accepted")
	assert_true(p.velocity.y < -300.0, "moving up after coyote jump (vy=%.1f)" % p.velocity.y)


func test_coyote_jump_rejected_after_window() -> void:
	var r: Array = await _setup_ledge()
	var p: Player = r[0]
	await wait_physics_frames(12)  # 0.2 s after leaving (> 0.12 s)
	press_jump()
	await wait_physics_frames(2)
	assert_eq(r[1][0], 0, "late jump rejected")
	assert_true(p.velocity.y > 0.0, "still falling")


func _drop_and_press(press_before_landing: float) -> int:
	make_block(Rect2(-2000, 0, 4000, 40))
	var p := make_player(Player.MovementMode.SIDE_VIEW, Vector2(0, -150))
	var jumps := [0]
	p.jumped.connect(func() -> void: jumps[0] += 1)
	var cfg := p.config
	# Fall time from rest: t = sqrt(2h/g). Press `press_before_landing` s earlier.
	var fall_time := sqrt(2.0 * 150.0 / cfg.gravity)
	var press_frame := int(round((fall_time - press_before_landing) * 60.0))
	await wait_physics_frames(press_frame)
	assert_false(p.is_on_floor(), "still airborne when pressing")
	press_jump()
	await wait_physics_frames(1)
	release_jump()
	input.jump_held = true  # keep holding for full height
	await wait_physics_frames(30)
	input.jump_held = false
	return jumps[0]


func test_jump_buffer_fires_on_landing() -> void:
	var n := await _drop_and_press(0.07)
	assert_eq(n, 1, "buffered press (0.07 s early) jumps on landing")


func test_jump_buffer_expires() -> void:
	var n := await _drop_and_press(0.3)
	assert_eq(n, 0, "press 0.3 s before landing is forgotten")


func test_dash_duration_distance_cooldown() -> void:
	var p := await make_side_player_on_floor()
	var cfg := p.config
	var dashes := [0]
	p.dashed.connect(func(_d: Vector2) -> void: dashes[0] += 1)
	var x0 := p.global_position.x
	press_dash()
	await wait_physics_frames(1)
	assert_true(p.is_dashing(), "dashing")
	assert_true(p.health.is_invulnerable(), "dash grants i-frames")
	var frames := 1
	while p.is_dashing() and frames < 60:
		await wait_physics_frames(1)
		frames += 1
	var duration := (frames - 1) / 60.0
	assert_almost_eq(duration, cfg.dash_duration, 1.5 / 60.0, "dash duration")
	var dist := p.global_position.x - x0
	assert_almost_eq(dist, cfg.dash_speed * cfg.dash_duration, 10.0, "dash distance")
	# Cooldown: pressing right after the dash does nothing.
	press_dash()
	await wait_physics_frames(2)
	assert_eq(dashes[0], 1, "second dash blocked by cooldown")
	assert_true(p.get_motor().get_dash_cooldown_left() > 0.0, "cooldown running")
	await wait_seconds(cfg.dash_cooldown)
	press_dash()
	await wait_physics_frames(2)
	assert_eq(dashes[0], 2, "dash available after cooldown")


func test_air_dash_once_until_landing() -> void:
	var cfg: PlayerConfig = load("res://resources/player/default_player_config.tres").duplicate()
	cfg.dash_cooldown = 0.05
	cfg.dash_duration = 0.05
	var p := await make_side_player_on_floor(0.0, cfg)
	var dashes := [0]
	p.dashed.connect(func(_d: Vector2) -> void: dashes[0] += 1)
	press_jump()
	await wait_physics_frames(6)
	press_dash()
	await wait_physics_frames(8)
	press_dash()
	await wait_physics_frames(4)
	assert_eq(dashes[0], 1, "only one air dash")
	release_jump()
	await wait_until(func() -> bool: return p.is_on_floor(), 3.0)
	press_dash()
	await wait_physics_frames(2)
	assert_eq(dashes[0], 2, "dash restored after landing")


func test_one_way_platform_land_and_drop() -> void:
	make_block(Rect2(-2000, 0, 4000, 40))
	make_block(Rect2(-60, -50, 120, 8), true)
	var p := make_player(Player.MovementMode.SIDE_VIEW, Vector2(0, -1))
	await wait_physics_frames(3)
	press_jump()  # jumps up through the platform from below
	await wait_physics_frames(60)
	release_jump()
	await wait_until(func() -> bool: return p.is_on_floor(), 2.0)
	assert_almost_eq(p.global_position.y, -50.0, 2.0, "standing on one-way platform")
	input.move = Vector2(0, 1)
	press_jump()
	await wait_physics_frames(2)
	release_jump()
	input.move = Vector2.ZERO
	await wait_physics_frames(40)
	assert_almost_eq(p.global_position.y, 0.0, 2.0, "dropped through to the floor")
