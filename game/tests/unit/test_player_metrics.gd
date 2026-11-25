extends PlayerTestCase
## Measures the real side-view jump metrics from the motor (default config) and
## prints a table for level design (tiles = 16 px). Asserts the PLATFORMER_DESIGN
## B targets: apex 4.5-5 tiles, airtime ~0.8 s, min hop ~1.2 tiles.

const TILE := 16.0


## Jumps on a flat floor. `run_up` frames of running first; `hold_frames` of
## jump hold (0 = release in the same frame); `dash_at_apex` air-dashes when
## vy turns >= 0. Returns {apex, airtime, distance}.
func _jump(run_up: int, hold_frames: int, move_x: float, dash_at_apex: bool = false) -> Dictionary:
	input.move = Vector2(move_x, 0)
	await wait_physics_frames(run_up)
	var p: Player = get_tree().get_first_node_in_group(Layers.GROUP_PLAYER)
	var x0 := p.global_position.x
	var y0 := p.global_position.y
	var min_y := y0
	press_jump()
	if hold_frames == 0:
		release_jump()
	var frames := 0
	var dashed := false
	while frames < 180:
		await wait_physics_frames(1)
		frames += 1
		if frames >= hold_frames:
			release_jump()
		min_y = minf(min_y, p.global_position.y)
		if dash_at_apex and not dashed and p.velocity.y >= 0.0 and frames > 2:
			press_dash()
			dashed = true
		if p.is_on_floor() and frames > 2:
			break
	input.move = Vector2.ZERO
	var result := {"apex": y0 - min_y, "airtime": frames / 60.0, "distance": absf(p.global_position.x - x0)}
	await wait_physics_frames(40)  # stop + dash cooldown
	return result


func test_jump_metrics_table() -> void:
	disable_feel_settings()
	var p := await make_side_player_on_floor(-1500.0)
	var full := await _jump(0, 999, 0.0)
	var hop := await _jump(0, 0, 0.0)
	var standing := await _jump(0, 999, 1.0)
	var running := await _jump(60, 999, 1.0)
	var dash := await _jump(60, 999, 1.0, true)
	var lines := PackedStringArray([
		"    | metric | px | tiles | s |",
		"    | apex (full hold) | %.1f | %.2f | |" % [full.apex, full.apex / TILE],
		"    | airtime (full hold) | | | %.3f |" % full.airtime,
		"    | min hop (tap) | %.1f | %.2f | %.3f |" % [hop.apex, hop.apex / TILE, hop.airtime],
		"    | standing jump distance | %.1f | %.2f | %.3f |" % [standing.distance, standing.distance / TILE, standing.airtime],
		"    | running jump distance | %.1f | %.2f | %.3f |" % [running.distance, running.distance / TILE, running.airtime],
		"    | running jump + air-dash at apex | %.1f | %.2f | %.3f |" % [dash.distance, dash.distance / TILE, dash.airtime],
	])
	print("\n".join(lines))
	assert_true(full.apex >= 4.5 * TILE and full.apex <= 5.0 * TILE, "apex 4.5-5 tiles (%.1f px)" % full.apex)
	assert_almost_eq(full.airtime, 0.8, 0.05, "airtime ~0.8 s")
	assert_almost_eq(hop.apex / TILE, 1.2, 0.15, "min hop ~1.2 tiles")
	assert_true(running.distance > standing.distance, "run-up jumps further")
	assert_true(dash.distance > running.distance + 3.0 * TILE, "air-dash adds > 3 tiles")
	assert_true(p.is_on_floor())
