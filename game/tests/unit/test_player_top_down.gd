extends PlayerTestCase
## TopDownMotor: 8-direction speed, dash direction, jump disabled by default.


func _speed_after(p: Player, move: Vector2, frames: int) -> float:
	input.move = move
	await wait_physics_frames(frames)
	var s := p.velocity.length()
	input.move = Vector2.ZERO
	await wait_physics_frames(30)
	return s


func test_diagonal_speed_equals_cardinal() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	await wait_physics_frames(2)
	assert_eq(p.motion_mode, CharacterBody2D.MOTION_MODE_FLOATING, "floating motion mode")
	var cardinal := await _speed_after(p, Vector2.RIGHT, 30)
	var diagonal := await _speed_after(p, Vector2(1, 1), 30)  # un-normalized on purpose
	assert_almost_eq(cardinal, p.config.move_speed, 0.5, "cardinal speed")
	assert_almost_eq(diagonal, cardinal, 0.5, "diagonal == cardinal")
	# Distance check: 1 s of diagonal movement covers move_speed px.
	var start := p.global_position
	input.move = Vector2(-1, -1).normalized()
	await wait_physics_frames(60)
	input.move = Vector2.ZERO
	var dist := p.global_position.distance_to(start)
	assert_almost_eq(dist, p.config.move_speed, 20.0, "distance over 1 s (incl. accel)")
	assert_vec_almost_eq(p.get_facing(), Vector2(-1, -1).normalized(), 0.01, "8-dir facing")


func test_no_jump_by_default() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	var jumps := [0]
	p.jumped.connect(func() -> void: jumps[0] += 1)
	await wait_physics_frames(2)
	var y0 := p.global_position.y
	press_jump()
	await wait_physics_frames(20)
	release_jump()
	assert_eq(jumps[0], 0, "no jump in top-down")
	assert_almost_eq(p.global_position.y, y0, 0.01, "no vertical motion / gravity")


func test_optional_hop_when_enabled() -> void:
	var cfg := PlayerConfig.new()
	cfg.top_down_jump_enabled = true
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO, cfg)
	var counts := [0, 0]
	p.jumped.connect(func() -> void: counts[0] += 1)
	p.landed.connect(func() -> void: counts[1] += 1)
	await wait_physics_frames(2)
	press_jump()
	await wait_physics_frames(int(cfg.top_down_jump_duration * 60) + 4)
	assert_eq(counts, [1, 1], "hop jumped + landed")


func test_dash_in_move_or_facing_direction() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	await wait_physics_frames(2)
	input.move = Vector2.UP
	press_dash()
	await wait_physics_frames(1)
	assert_true(p.is_dashing())
	assert_vec_almost_eq(p.get_motor().get_dash_direction(), Vector2.UP, 0.001, "dash along move")
	var y0 := p.global_position.y
	input.move = Vector2.ZERO
	await wait_until(func() -> bool: return not p.is_dashing(), 1.0)
	var cfg := p.config
	assert_almost_eq(y0 - p.global_position.y, cfg.dash_speed * (cfg.dash_duration - 1.0 / 60.0), 10.0, "dash distance")
	await wait_seconds(cfg.dash_cooldown)
	# Idle dash uses facing (last move = up).
	press_dash()
	await wait_physics_frames(1)
	assert_vec_almost_eq(p.get_motor().get_dash_direction(), Vector2.UP, 0.001, "idle dash uses facing")
