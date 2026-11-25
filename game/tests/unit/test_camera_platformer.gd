extends PlayerTestCase
## PlatformerCamera rig: platform snap, window follow, lead, hard snap, bounds,
## LevelInfo zoom, shake setting. View fixed to 640x360 @ zoom 1.5 = 426.7x240.

const VIEW := Vector2(640, 360)


func after_each() -> void:
	super.after_each()
	restore_feel_settings()


func _make_cam_player(pos: Vector2) -> Player:
	var packed: PackedScene = load(PLAYER_SCENE)
	var p: Player = packed.instantiate()
	p.movement_mode = Player.MovementMode.SIDE_VIEW
	p.use_camera = true
	p.position = pos
	p.set_input_override(input)
	(p.get_node(^"PlatformerCamera") as PlatformerCamera).view_size_override = VIEW
	add_test_node(p)
	return p


func _cam(p: Player) -> PlatformerCamera:
	return p.camera as PlatformerCamera


## Feet position as a fraction of the view height from the top.
func _feet_frac(p: Player) -> float:
	var c := _cam(p)
	var h := c.get_view_size().y
	return (p.global_position.y - (c.global_position.y - h * 0.5)) / h


func _settle(p: Player) -> void:
	await wait_physics_frames(3)
	await wait_until(func() -> bool: return p.is_on_floor(), 1.0)
	await wait_physics_frames(30)


func test_rig_is_active_camera_in_side_view() -> void:
	make_block(Rect2(-2000, 0, 4000, 40))
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	assert_true(p.camera is PlatformerCamera, "side view uses the rig")
	assert_true(p.camera.enabled and p.camera.top_level, "enabled, top_level")
	assert_false(p.follow_camera.enabled, "child Camera2D disabled")
	assert_almost_eq(p.camera.zoom.x, 1.5, 0.001, "default zoom")
	assert_almost_eq(_feet_frac(p), 0.70, 0.01, "feet on the 70 %% rest line")


func test_camera_holds_y_during_full_jump() -> void:
	make_block(Rect2(-2000, 0, 4000, 40))
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	var y0 := _cam(p).global_position.y
	var max_dev := 0.0
	var min_feet := 0.0
	press_jump()
	for i in 70:
		await wait_physics_frames(1)
		max_dev = maxf(max_dev, absf(_cam(p).global_position.y - y0))
		min_feet = minf(min_feet, p.global_position.y)
	release_jump()
	assert_true(min_feet < -70.0, "full jump happened (apex %.1f px)" % -min_feet)
	assert_true(p.is_on_floor(), "landed")
	assert_almost_eq(max_dev, 0.0, 0.01, "camera y did not move (max dev %.3f)" % max_dev)


func test_camera_eases_to_higher_platform() -> void:
	make_block(Rect2(-2000, 0, 4000, 40))
	make_block(Rect2(40, -48, 400, 48))  # 3-tile step
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	var y0 := _cam(p).global_position.y
	input.move = Vector2.RIGHT
	press_jump()
	var landed := false
	var air_dev := 0.0
	for i in 120:
		await wait_physics_frames(1)
		if p.is_on_floor() and p.global_position.y < -40.0:
			landed = true
			break
		air_dev = maxf(air_dev, absf(_cam(p).global_position.y - y0))
	input.move = Vector2.ZERO
	release_jump()
	assert_true(landed, "landed on the platform")
	assert_almost_eq(air_dev, 0.0, 0.01, "no scroll while airborne")
	var target := y0 - 48.0
	var frames := 1  # the landing frame already eased once
	while absf(_cam(p).global_position.y - target) > 2.0 and frames < 60:
		await wait_physics_frames(1)
		frames += 1
	var t := frames / 60.0
	print("    camera ease to +3 tiles: %.3f s to within 2 px" % t)
	assert_true(t <= 0.35 and t >= 0.15, "eased (not snapped) within ~0.35 s (%.3f s)" % t)
	await wait_physics_frames(30)
	assert_almost_eq(_feet_frac(p), 0.70, 0.01, "rest line restored")


func test_camera_follows_fall_past_window() -> void:
	make_block(Rect2(-2000, 0, 2000, 40))  # ledge at x = 0
	make_block(Rect2(-2000, 300, 4000, 40))  # floor far below
	var p := _make_cam_player(Vector2(-20, -1))
	await _settle(p)
	var y0 := _cam(p).global_position.y
	input.move = Vector2.RIGHT
	var max_frac := 0.0
	var max_fall_v := 0.0
	for i in 90:
		await wait_physics_frames(1)
		if not p.is_on_floor():
			input.move = Vector2.ZERO
		max_frac = maxf(max_frac, _feet_frac(p))
		max_fall_v = maxf(max_fall_v, p.velocity.y)
	assert_true(_cam(p).global_position.y > y0 + 150.0, "camera followed the fall")
	var limit := 0.70 + 16.0 / 240.0
	assert_true(max_frac <= limit + 0.005, "feet never below rest + 1 tile (%.3f <= %.3f)" % [max_frac, limit])
	assert_true(max_fall_v > 250.0, "fell fast (%.0f px/s)" % max_fall_v)


func test_camera_top_window_on_launch() -> void:
	make_block(Rect2(-2000, 0, 4000, 40))
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	var y0 := _cam(p).global_position.y
	p.velocity = Vector2(0, -700)  # spring-like launch (~270 px)
	var min_head := 1.0
	for i in 40:
		await wait_physics_frames(1)
		var c := _cam(p)
		var head := (p.global_position.y - 20.0 - (c.global_position.y - 120.0)) / 240.0
		min_head = minf(min_head, head)
	assert_true(_cam(p).global_position.y < y0 - 50.0, "camera moved up")
	assert_true(min_head >= 0.22 - 0.005, "head kept below the 22 %% window (%.3f)" % min_head)


func test_lead_follows_velocity_capped_and_rate_limited() -> void:
	make_block(Rect2(-4000, 0, 8000, 40))
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	var c := _cam(p)
	var l0 := c.lead
	input.move = Vector2.RIGHT
	var max_step := 0.0
	var prev := c.lead
	for i in 90:
		await wait_physics_frames(1)
		max_step = maxf(max_step, absf(c.lead - prev))
		prev = c.lead
	assert_almost_eq(c.lead, 44.0, 0.5, "lead ~44 px toward +x")
	assert_almost_eq(c.global_position.x - p.global_position.x, c.lead, 0.01, "camera x = player x + lead")
	assert_true(max_step <= 80.0 / 60.0 + 0.001, "pan <= 80 px/s (max step %.3f)" % max_step)
	# Dash: lead stays capped.
	press_dash()
	for i in 12:
		await wait_physics_frames(1)
		assert_true(c.lead <= 44.0 + 0.001, "lead capped during dash (%.2f)" % c.lead)
	# Reverse: lead swings toward -x at the limited rate (~1.1 s for 88 px).
	input.move = Vector2.LEFT
	await wait_physics_frames(30)
	assert_true(c.lead > 0.0 and c.lead < 44.0, "half-way through reversal (%.1f)" % c.lead)
	await wait_physics_frames(60)
	assert_almost_eq(c.lead, -44.0, 0.5, "lead now toward -x")
	print("    lead start %.1f -> +44 -> -44 (max step %.2f px/frame)" % [l0, max_step])


func test_lead_does_not_swing_on_stationary_turn() -> void:
	make_block(Rect2(-2000, 0, 4000, 40))
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	var c := _cam(p)
	var l0 := c.lead
	var x0 := c.global_position.x
	for k in 4:
		input.move = Vector2.LEFT if k % 2 == 0 else Vector2.RIGHT
		await wait_physics_frames(1)
		input.move = Vector2.ZERO
		await wait_physics_frames(15)
	assert_true(p.get_facing().x > 0.0, "facing changed back and forth")
	assert_almost_eq(c.lead, l0, 0.001, "lead unchanged")
	assert_almost_eq(c.global_position.x, x0, 1.0, "camera x steady")


func test_hard_snap_on_spawn() -> void:
	make_block(Rect2(-4000, 0, 8000, 40))
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	var spawn := Node2D.new()
	spawn.position = Vector2(1500, 0)
	add_test_node(spawn)
	p.global_position = spawn.global_position
	p.on_spawned(spawn)
	var c := _cam(p)
	var expected := Vector2(1500.0 + c.lead, -48.0)
	assert_vec_almost_eq(c.global_position, expected, 0.01, "snapped in the same frame")
	await wait_physics_frames(1)
	assert_vec_almost_eq(c.global_position, expected, 1.0, "no swoop afterwards")


func test_teleport_triggers_snap() -> void:
	make_block(Rect2(-4000, 0, 8000, 40))
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	p.global_position = Vector2(-1200, 0)
	await wait_physics_frames(1)
	assert_almost_eq(_cam(p).global_position.x, -1200.0 + _cam(p).lead, 0.5, "teleport snaps x")


func test_bounds_clamp_and_small_room_centred() -> void:
	make_block(Rect2(-2000, 0, 4000, 40))
	var bounds := CameraBounds.new()
	bounds.bounds = Rect2(0, -300, 2000, 340)
	add_test_node(bounds)
	var p := _make_cam_player(Vector2(20, -1))
	await _settle(p)
	var c := _cam(p)
	assert_almost_eq(c.global_position.x, 213.333, 0.01, "left edge clamps to bounds")
	assert_almost_eq(c.global_position.y + 120.0, 40.0, 0.01, "bottom edge clamps to bounds")
	bounds.bounds = Rect2(-100, -150, 200, 150)  # smaller than the 426x240 view
	c.refresh_level_settings()
	await wait_physics_frames(1)
	assert_vec_almost_eq(c.global_position, Vector2(0, -75), 0.01, "small room centred")


func test_level_info_zoom_override() -> void:
	var script := GDScript.new()
	script.source_code = "extends Node\nvar camera_zoom: float = 2.0\n"
	script.reload()
	var info := Node.new()
	info.set_script(script)
	info.add_to_group(PlatformerCamera.LEVEL_INFO_GROUP)
	add_test_node(info)
	make_block(Rect2(-2000, 0, 4000, 40))
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	assert_almost_eq(p.camera.zoom.x, 2.0, 0.001, "LevelInfo.camera_zoom applied")
	assert_almost_eq(_cam(p).get_view_size().y, 180.0, 0.01)


func test_trauma_shake_respects_setting() -> void:
	make_block(Rect2(-2000, 0, 4000, 40))
	var p := _make_cam_player(Vector2(0, -1))
	await _settle(p)
	var c := _cam(p)
	var y0 := c.global_position.y
	c.add_trauma(0.8)
	assert_almost_eq(c.trauma, 0.8, 0.001, "trauma added")
	await wait_physics_frames(1)
	assert_true(c.offset.length() > 0.0, "shake offset applied")
	assert_almost_eq(c.global_position.y, y0, 0.01, "rig position unaffected by shake")
	await wait_physics_frames(40)
	assert_almost_eq(c.trauma, 0.0, 0.001, "trauma decays")
	assert_eq(c.offset, Vector2.ZERO)
	GameState.set_setting(&"screen_shake", false)
	c.add_trauma(0.8)
	assert_eq(c.trauma, 0.0, "disabled by setting")
