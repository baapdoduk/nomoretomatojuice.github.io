extends TestCase
## Light reflection: tracing, mirrors, receivers, obstacles, loop safety.
## Layouts are built in code. Mirror angle reference (surface along local +X):
##   45 deg turns RIGHT->DOWN and LEFT->UP; -45 deg turns DOWN->LEFT and UP->RIGHT.

var root: Node2D


func before_each() -> void:
	GameState.new_game(5)
	root = add_test_node(Node2D.new()) as Node2D


func _emitter(pos: Vector2, angle_deg: float = 0.0) -> LightEmitter:
	var e := LightEmitter.new()
	e.position = pos
	e.rotation_degrees = angle_deg
	root.add_child(e)
	return e

func _mirror(pos: Vector2, angle_deg: float, step: float = 0.0, length: float = 24.0) -> Mirror:
	var m := Mirror.new()
	m.position = pos
	m.rotation_degrees = angle_deg
	m.rotation_step_degrees = step
	m.mirror_length = length
	root.add_child(m)
	return m

func _receiver(pos: Vector2) -> LightReceiver:
	var r := LightReceiver.new()
	r.position = pos
	root.add_child(r)
	return r

func _wall(pos: Vector2, size: Vector2) -> StaticBody2D:
	var w := StaticBody2D.new()
	w.position = pos
	PuzzlePhysics.ensure_rect_shape(w, size)
	root.add_child(w)
	return w

func _settle() -> void:
	await wait_physics_frames(4)


func test_straight_beam_hits_receiver() -> void:
	var e := _emitter(Vector2(0, 0))
	var r := _receiver(Vector2(120, 0))
	await _settle()
	assert_true(r.is_lit(), "receiver lit")
	assert_true(r.is_active(), "receiver active")
	assert_eq(e.last_result.end_reason, LightTracer.EndReason.ABSORBED)
	assert_eq(e.get_lit_targets().size(), 1)

func test_single_mirror_turns_90_degrees_to_receiver() -> void:
	var e := _emitter(Vector2(0, 0))
	_mirror(Vector2(100, 0), 45)
	var r := _receiver(Vector2(100, 100))
	await _settle()
	assert_true(r.is_lit(), "lit via one mirror")
	assert_eq(e.last_result.bounces, 1)
	var pts := e.get_beam_points()
	assert_eq(pts.size(), 3, "origin, mirror hit, receiver hit")
	assert_vec_almost_eq(pts[1], Vector2(100, 0), 3.0, "hit on mirror")
	assert_almost_eq(pts[2].x, pts[1].x, 1.0, "travels straight down")
	assert_true(pts[2].y > 85.0, "reaches the receiver below")

func test_three_mirrors_reach_receiver() -> void:
	var e := _emitter(Vector2(-60, 0))
	_mirror(Vector2(100, 0), 45)     # right -> down
	_mirror(Vector2(100, 100), -45)  # down -> left
	_mirror(Vector2(0, 100), 45)     # left -> up
	var r := _receiver(Vector2(0, -80))
	await _settle()
	assert_true(r.is_lit(), "lit via three mirrors")
	assert_eq(e.last_result.bounces, 3)
	assert_eq(e.last_result.reflectors.size(), 3)

func test_obstacle_blocks_beam() -> void:
	var e := _emitter(Vector2(0, 0))
	_mirror(Vector2(100, 0), 45)
	_wall(Vector2(100, 50), Vector2(40, 8))
	var r := _receiver(Vector2(100, 100))
	await _settle()
	assert_false(r.is_lit(), "blocked")
	assert_eq(e.last_result.end_reason, LightTracer.EndReason.BLOCKED)

func test_rotating_mirror_toggles_lit() -> void:
	var e := _emitter(Vector2(0, 0))
	var m := _mirror(Vector2(100, 0), 45)
	var r := _receiver(Vector2(100, 100))
	var changes: Array[bool] = []
	r.activated_changed.connect(func(a: bool) -> void: changes.append(a))
	await _settle()
	assert_true(r.is_active(), "initially lit")
	m.rotate_step()
	await _settle()
	assert_false(r.is_active(), "unlit after 90 deg")
	assert_true(e.get_beam_points()[2].y < 0.0, "beam now goes up")
	m.rotate_step()
	await _settle()
	assert_true(r.is_active(), "lit again after 180 deg")
	assert_eq(changes, [true, false, true] as Array[bool])

func test_mirror_interaction_rotates_45() -> void:
	var m := _mirror(Vector2(0, 0), 0, 45)
	await wait_frames(1)
	await m.interactable.interact(self)
	assert_almost_eq(m.rotation_degrees, 45.0, 0.01)
	assert_eq(m.get_orientation_count(), 4)
	for i in 3:
		await m.interactable.interact(self)
	assert_eq(m.step_index, 0, "wraps after 180 deg")

func test_closed_loop_terminates() -> void:
	var e := _emitter(Vector2(50, 0))
	_mirror(Vector2(100, 0), 45)     # right -> down
	_mirror(Vector2(100, 100), -45)  # down -> left
	_mirror(Vector2(0, 100), 45)     # left -> up
	_mirror(Vector2(0, 0), -45)      # up -> right (back into the loop)
	await _settle()
	var res := e.last_result
	assert_not_null(res)
	assert_true(res.end_reason == LightTracer.EndReason.CYCLE or res.end_reason == LightTracer.EndReason.MAX_BOUNCES, "loop stopped")
	assert_true(res.bounces <= 12, "within bounce limit")
	assert_true(e.get_beam_points().size() <= 15, "bounded polyline")

func test_zigzag_is_not_a_cycle_and_respects_bounce_limit() -> void:
	# Two long parallel mirrors with a slanted beam: a zig-zag that revisits the same
	# mirrors with the same directions at new points -> must run to the bounce limit.
	var e := _emitter(Vector2(0, 0), 60)
	_mirror(Vector2(1000, -20), 0, 0.0, 2400)
	_mirror(Vector2(1000, 40), 0, 0.0, 2400)
	await _settle()
	assert_eq(e.last_result.bounces, 12, "default max bounces")
	assert_eq(e.last_result.end_reason, LightTracer.EndReason.MAX_BOUNCES)
	var cfg := PuzzleConfig.new()
	cfg.max_bounces = 3
	e.config = cfg
	e.request_update()
	await _settle()
	assert_eq(e.last_result.bounces, 3, "configured max bounces")

func test_max_distance_cap() -> void:
	var cfg := PuzzleConfig.new()
	cfg.max_distance = 50.0
	var e := LightEmitter.new()
	e.config = cfg
	root.add_child(e)
	var r := _receiver(Vector2(120, 0))
	await _settle()
	assert_false(r.is_lit(), "receiver beyond max distance")
	assert_almost_eq(e.get_beam_points()[1].x, 50.0, 0.01)

func test_single_sided_mirror_back_blocks() -> void:
	var e := _emitter(Vector2(0, 0))
	var m := _mirror(Vector2(100, 0), 45)
	m.double_sided = false
	var r := _receiver(Vector2(100, 100))
	await _settle()
	# Front normal of a 45 deg mirror points up-right; a beam travelling right hits its back.
	assert_false(r.is_lit(), "back side blocks")
	assert_eq(e.last_result.end_reason, LightTracer.EndReason.BLOCKED)

func test_emitter_power_and_inputs() -> void:
	var sw := PuzzleSwitch.new()
	root.add_child(sw)
	var e := LightEmitter.new()
	e.power_inputs = [sw]
	root.add_child(e)
	var r := _receiver(Vector2(80, 0))
	await _settle()
	assert_false(e.powered, "unpowered while switch off")
	assert_false(r.is_lit())
	sw.operate()
	await _settle()
	assert_true(e.powered)
	assert_true(r.is_lit(), "lit when powered")
	e.toggle_power()
	await _settle()
	assert_false(r.is_lit())
	assert_eq(e.get_beam_points().size(), 0, "no beam while off")

func test_receiver_latch() -> void:
	var e := _emitter(Vector2(0, 0))
	var r := _receiver(Vector2(80, 0))
	r.latch = true
	await _settle()
	assert_true(r.is_active())
	e.set_powered(false)
	await _settle()
	assert_false(r.is_lit())
	assert_true(r.is_active(), "latched")
	r.reset()
	assert_false(r.is_active(), "reset clears latch")

func test_gate_blocks_and_unblocks_beam() -> void:
	_emitter(Vector2(0, 0))
	var g := Gate.new()
	g.position = Vector2(50, 0)
	g.gate_size = Vector2(8, 40)
	root.add_child(g)
	var r := _receiver(Vector2(100, 0))
	await _settle()
	assert_false(r.is_lit(), "closed gate blocks")
	g.force_open()
	await _settle()
	assert_true(r.is_lit(), "open gate lets light through")

func test_continuous_update_tracks_moving_obstacle() -> void:
	var e := _emitter(Vector2(0, 0))
	e.continuous_update = true
	var r := _receiver(Vector2(100, 0))
	var w := _wall(Vector2(50, 200), Vector2(8, 40))
	await _settle()
	assert_true(r.is_lit())
	w.position = Vector2(50, 0)
	await _settle()
	assert_false(r.is_lit(), "moving obstacle detected without notification")

func test_beam_visual_follows_points() -> void:
	var e := _emitter(Vector2(10, 10))
	_receiver(Vector2(90, 10))
	await _settle()
	var beam := PuzzlePhysics.find_child_of_type(e, LightBeam) as LightBeam
	assert_not_null(beam, "auto-created beam line")
	assert_eq(beam.points.size(), 2)
	assert_almost_eq(beam.points[0].x, 0.0, 0.01, "local coordinates")


func test_non_latching_receiver_resyncs_after_load() -> void:
	GameState.set_flag(&"puzzle.test.recv", true)
	var r := LightReceiver.new()
	r.persist_flag = &"puzzle.test.recv"
	r.position = Vector2(100, 0)
	root.add_child(r)
	var g := Gate.new()
	g.inputs = [r]
	g.position = Vector2(0, 200)
	root.add_child(g)
	await _settle()
	assert_false(r.is_active(), "no beam -> not active despite stale flag")
	assert_false(g.is_open, "gate not opened by a stale flag")
	_emitter(Vector2(0, 0))
	await _settle()
	assert_true(r.is_active(), "re-derived from the beam")
	assert_true(GameState.has_flag(&"puzzle.test.recv"))
	GameState.set_flag(&"puzzle.test.recv_latched", true)
	var rl := LightReceiver.new()
	rl.latch = true
	rl.persist_flag = &"puzzle.test.recv_latched"
	rl.position = Vector2(0, 300)
	root.add_child(rl)
	await _settle()
	assert_true(rl.is_active(), "latching receiver keeps its flag")
