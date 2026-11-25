extends PlayerTestCase
## Side-view feel: corner correction, step-up, skid, surface modifiers,
## hit-stop / trauma settings.


func after_each() -> void:
	super.after_each()
	restore_feel_settings()


## Ceiling whose right edge overlaps the (12 px wide) player by `overlap_px`.
func _jump_under_ceiling_edge(overlap_px: float, cfg: PlayerConfig = null) -> Array:
	make_block(Rect2(-2000, 0, 4000, 40))
	make_block(Rect2(-300, -60, 300 - 6.0 + overlap_px, 20))  # bottom at y = -40
	var p := make_player(Player.MovementMode.SIDE_VIEW, Vector2(0, -1), cfg)
	await wait_physics_frames(3)
	await wait_until(func() -> bool: return p.is_on_floor(), 1.0)
	var x0 := p.global_position.x
	var min_y := 0.0
	press_jump()
	for i in 50:
		await wait_physics_frames(1)
		min_y = minf(min_y, p.global_position.y)
	release_jump()
	return [p.global_position.x - x0, min_y]


func test_corner_correction_clips_past_ceiling_edge() -> void:
	var r: Array = await _jump_under_ceiling_edge(3.0)
	print("    corner correction: shifted %.2f px, apex y %.1f" % [r[0], r[1]])
	assert_true(r[1] < -60.0, "jump passed the ceiling edge (min y %.1f)" % r[1])
	assert_true(r[0] >= 3.0 and r[0] <= 4.0, "nudged 3-4 px (%.2f)" % r[0])


func test_corner_correction_limits() -> void:
	var r: Array = await _jump_under_ceiling_edge(6.0)
	assert_true(r[1] > -21.0, "6 px overlap still bonks (min y %.1f)" % r[1])
	assert_almost_eq(r[0], 0.0, 0.01, "no nudge")


func test_corner_correction_can_be_disabled() -> void:
	var cfg: PlayerConfig = load("res://resources/player/default_player_config.tres").duplicate()
	cfg.corner_correction = 0.0
	var r: Array = await _jump_under_ceiling_edge(3.0, cfg)
	assert_true(r[1] > -21.0, "bonks without correction (min y %.1f)" % r[1])


func _walk_into_lip(height: float) -> Player:
	make_block(Rect2(-2000, 0, 4000, 40))
	make_block(Rect2(30, -height, 300, height))
	var p := await make_side_player_on_floor(0.0)
	input.move = Vector2.RIGHT
	await wait_physics_frames(40)
	input.move = Vector2.ZERO
	return p


func test_step_up_over_small_lip() -> void:
	var p := await _walk_into_lip(2.0)
	assert_true(p.global_position.x > 60.0, "walked onto the lip (x %.1f)" % p.global_position.x)
	assert_almost_eq(p.global_position.y, -2.0, 0.2, "standing on top of the 2 px lip")
	assert_true(p.is_on_floor())


func test_step_up_does_not_climb_walls() -> void:
	var p := await _walk_into_lip(5.0)
	assert_true(p.global_position.x < 30.0, "blocked by a 5 px step (x %.1f)" % p.global_position.x)
	assert_almost_eq(p.global_position.y, 0.0, 0.2)


func test_skid_signal_on_reversal_at_speed() -> void:
	var p := await make_side_player_on_floor()
	var skids := [0]
	p.skidded.connect(func() -> void: skids[0] += 1)
	input.move = Vector2.RIGHT
	await wait_physics_frames(30)
	assert_eq(skids[0], 0, "no skid while accelerating")
	input.move = Vector2.LEFT
	await wait_physics_frames(20)
	assert_eq(skids[0], 1, "one skid per reversal")
	# Turn decel 2200 stops 180 px/s in ~5 frames (vs. 12 at accel 900).
	assert_true(p.velocity.x < -100.0, "already running the other way")


func test_turn_uses_turn_decel() -> void:
	var p := await make_side_player_on_floor()
	input.move = Vector2.RIGHT
	await wait_physics_frames(40)
	assert_almost_eq(p.velocity.x, 180.0, 0.01, "full speed")
	input.move = Vector2.LEFT
	await wait_physics_frames(1)
	assert_almost_eq(p.velocity.x, 180.0 - 2200.0 / 60.0, 0.1, "turn decel 2200")
	input.move = Vector2.ZERO
	await wait_physics_frames(1)
	var v := p.velocity.x
	await wait_physics_frames(1)
	assert_almost_eq(v - p.velocity.x, 1200.0 / 60.0, 0.1, "release decel 1200")


func test_surface_modifier_slows_and_clears() -> void:
	var p := await make_side_player_on_floor()
	var puddle := Node.new()
	add_test_node(puddle)
	p.set_surface_modifier(puddle, 0.5, 0.7, 1.0)
	input.move = Vector2.RIGHT
	await wait_physics_frames(40)
	assert_almost_eq(p.velocity.x, 90.0, 0.5, "speed halved")
	input.move = Vector2.ZERO
	await wait_physics_frames(20)
	var y0 := p.global_position.y
	var min_y := y0
	press_jump()
	for i in 60:
		await wait_physics_frames(1)
		min_y = minf(min_y, p.global_position.y)
	release_jump()
	var h := y0 - min_y
	assert_almost_eq(h, 76.0 * 0.49, 4.0, "jump height ~0.49x with jump_mult 0.7 (%.1f)" % h)
	# Second source combines multiplicatively.
	var other := Node.new()
	add_test_node(other)
	p.set_surface_modifier(other, 0.5, 1.0, 1.0)
	assert_almost_eq(p.get_surface_speed_multiplier(), 0.25, 0.0001, "0.5 * 0.5")
	other.free()
	assert_almost_eq(p.get_surface_speed_multiplier(), 0.5, 0.0001, "freed source ignored")
	p.clear_surface_modifier(puddle)
	assert_false(p.has_surface_modifier(puddle))
	await wait_until(func() -> bool: return p.is_on_floor(), 2.0)
	input.move = Vector2.RIGHT
	await wait_physics_frames(40)
	assert_almost_eq(p.velocity.x, 180.0, 0.5, "full speed after clear")


func test_surface_modifier_accel() -> void:
	var p := await make_side_player_on_floor()
	p.set_surface_modifier(self, 1.0, 1.0, 0.5)
	input.move = Vector2.RIGHT
	await wait_physics_frames(1)
	assert_almost_eq(p.velocity.x, 450.0 / 60.0, 0.1, "accel halved")
	p.clear_surface_modifier(self)


func _hit_target_in_front(p: Player) -> Health:
	var root := Node2D.new()
	root.position = p.global_position + Vector2(16, -10)
	var health := Health.new()
	health.max_health = 10
	root.add_child(health)
	var hurt := Hurtbox.new()
	hurt.collision_layer = Layers.ENEMY
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 8
	shape.shape = c
	hurt.add_child(shape)
	root.add_child(hurt)
	add_test_node(root)
	return health


func test_hit_stop_on_melee_hit_respects_setting() -> void:
	var p := await make_side_player_on_floor()
	var target := _hit_target_in_front(p)
	await wait_physics_frames(2)
	var hits := [0]
	p.melee.hit_confirmed.connect(func(_h: Hurtbox, _e: DamageEvent) -> void: hits[0] += 1)
	GameState.set_setting(&"hit_stop", true)
	input.attack_pressed = true
	assert_true(await wait_until(func() -> bool: return hits[0] > 0, 1.0), "swing connected")
	assert_true(HitStop.is_active(), "hit-stop running")
	assert_almost_eq(Engine.time_scale, p.config.hit_stop_time_scale, 0.001, "time scaled down")
	var frames := 0
	while HitStop.is_active() and frames < 30:
		await wait_frames(1)
		frames += 1
	print("    hit-stop lasted %d frames (%.0f ms)" % [frames, frames * 1000.0 / 60.0])
	assert_true(frames >= 2 and frames <= 5, "~50 ms (%d frames)" % frames)
	assert_eq(Engine.time_scale, 1.0, "time scale restored")
	assert_true(target.current < 10, "target damaged")
	# Disabled: no freeze, and timing is exact.
	await wait_until(func() -> bool: return p.melee.can_attack(), 1.0)
	await wait_physics_frames(2)
	GameState.set_setting(&"hit_stop", false)
	var before: int = hits[0]
	input.attack_pressed = true
	assert_true(await wait_until(func() -> bool: return hits[0] > before, 1.0), "second swing connected")
	assert_false(HitStop.is_active(), "no hit-stop when disabled")
	assert_eq(Engine.time_scale, 1.0)


func test_hit_stop_helper_disabled_returns_false() -> void:
	GameState.set_setting(&"hit_stop", false)
	assert_false(HitStop.trigger(get_tree(), 0.05), "disabled")
	assert_eq(Engine.time_scale, 1.0)
	GameState.set_setting(&"hit_stop", true)
	assert_true(HitStop.trigger(get_tree(), 0.05), "enabled")
	assert_true(Engine.time_scale < 1.0)
	HitStop.stop()
	assert_eq(Engine.time_scale, 1.0)


func test_visual_squash_and_stretch() -> void:
	var p := await make_side_player_on_floor()
	var vis := p.get_node(^"Visual") as PlayerVisual
	press_jump()
	await wait_physics_frames(1)
	assert_true(vis.get_squash().y > 1.1, "stretched on take-off (%s)" % str(vis.get_squash()))
	release_jump()
	await wait_until(func() -> bool: return p.is_on_floor(), 2.0)
	await wait_frames(1)
	assert_true(vis.get_squash().x > 1.05, "squashed on landing (%s)" % str(vis.get_squash()))
	await wait_seconds(0.5)
	assert_vec_almost_eq(vis.get_squash(), Vector2.ONE, 0.02, "recovered")
