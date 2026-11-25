extends PlayerTestCase
## Sticky-puddle jump metrics for level design (docs/LEVEL_DESIGN_GUIDE.md).
## Same method as test_player_metrics.gd, but every take-off is inside a
## StickyPuddle (default multipliers). Prints a table and asserts the
## properties The Cellar Shelf relies on.

const TILE := 16.0
const PUDDLE_SCENE := "res://scenes/level_kit/sticky_puddle.tscn"


func _jump(run_up: int, move_x: float, dash_at_apex: bool) -> Dictionary:
	input.move = Vector2(move_x, 0)
	await wait_physics_frames(run_up)
	var p: Player = get_tree().get_first_node_in_group(Layers.GROUP_PLAYER)
	var x0 := p.global_position.x
	var y0 := p.global_position.y
	var speed0 := absf(p.velocity.x)
	var sticky := p.get_surface_jump_multiplier() < 1.0
	var min_y := y0
	press_jump()
	var frames := 0
	var dashed := false
	while frames < 180:
		await wait_physics_frames(1)
		frames += 1
		input.jump_pressed = false
		min_y = minf(min_y, p.global_position.y)
		if dash_at_apex and not dashed and p.velocity.y >= 0.0 and frames > 2:
			press_dash()
			dashed = true
		elif dashed:
			input.dash_pressed = false
		if p.is_on_floor() and frames > 2:
			break
	release_jump()
	input.move = Vector2.ZERO
	var result := {"apex": y0 - min_y, "distance": absf(p.global_position.x - x0),
		"speed": speed0, "sticky": sticky}
	await wait_physics_frames(50)
	return result


func test_sticky_jump_metrics_table() -> void:
	disable_feel_settings()
	var puddle: StickyPuddle = load(PUDDLE_SCENE).instantiate()
	puddle.width = 3600.0
	puddle.position = Vector2(0, 0)
	add_test_node(puddle)
	var p := await make_side_player_on_floor(-1500.0)
	await wait_physics_frames(5)
	var run := await _jump(60, 1.0, false)
	var stand := await _jump(0, 1.0, false)
	var dash := await _jump(60, 1.0, true)
	print("\n".join(PackedStringArray([
		"    | sticky metric | px | tiles |",
		"    | run speed in puddle | %.0f px/s | |" % run.speed,
		"    | apex (full hold) | %.1f | %.2f |" % [run.apex, run.apex / TILE],
		"    | running jump distance | %.1f | %.2f |" % [run.distance, run.distance / TILE],
		"    | standing jump distance | %.1f | %.2f |" % [stand.distance, stand.distance / TILE],
		"    | running jump + air-dash | %.1f | %.2f |" % [dash.distance, dash.distance / TILE],
	])))
	assert_true(run.sticky, "take-off was sticky")
	assert_true(run.apex < 3.0 * TILE, "sticky apex < 3 tiles (a 4-tile step needs a dry take-off)")
	assert_true(run.speed < 110.0, "slowed run")
	assert_true(dash.distance > run.distance + 3.0 * TILE, "air-dash still carries")
	assert_true(p.is_on_floor())
	restore_feel_settings()
