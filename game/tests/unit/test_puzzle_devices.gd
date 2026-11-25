extends TestCase
## Switch modes, pressure plate, push box, reset lever.

var root: Node2D


func before_each() -> void:
	GameState.new_game(5)
	root = add_test_node(Node2D.new()) as Node2D


func _player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.add_to_group(&"player")
	p.collision_layer = Layers.PLAYER
	p.collision_mask = Layers.WORLD
	p.position = pos
	PuzzlePhysics.ensure_rect_shape(p, Vector2(12, 20))
	root.add_child(p)
	return p

func _switch(mode: PuzzleSwitch.Mode) -> PuzzleSwitch:
	var s := PuzzleSwitch.new()
	s.mode = mode
	root.add_child(s)
	return s


func test_switch_toggle_via_interactable() -> void:
	var s := _switch(PuzzleSwitch.Mode.TOGGLE)
	assert_not_null(s.interactable, "auto-created interactable")
	var log: Array[bool] = []
	s.activated_changed.connect(func(a: bool) -> void: log.append(a))
	await s.interactable.interact(self)
	assert_true(s.is_active())
	await s.interactable.interact(self)
	assert_false(s.is_active())
	assert_eq(log, [true, false] as Array[bool])

func test_switch_momentary_times_out() -> void:
	var s := _switch(PuzzleSwitch.Mode.MOMENTARY)
	s.momentary_time = 0.25
	s.operate()
	assert_true(s.is_active())
	await wait_seconds(0.1)
	s.operate() # restarts the timer
	await wait_seconds(0.18)
	assert_true(s.is_active(), "timer restarted by re-use")
	await wait_seconds(0.15)
	assert_false(s.is_active(), "turned off after momentary_time")

func test_switch_latch_and_reset() -> void:
	var s := _switch(PuzzleSwitch.Mode.LATCH)
	s.operate()
	assert_true(s.is_active())
	assert_false(s.interactable.enabled, "latched switch can't be used")
	s.operate()
	assert_true(s.is_active(), "stays on")
	s.reset()
	assert_false(s.is_active())
	assert_true(s.interactable.enabled)

func test_switch_persist_flag() -> void:
	var s := PuzzleSwitch.new()
	s.persist_flag = &"puzzle.test.sw"
	root.add_child(s)
	s.operate()
	assert_true(GameState.has_flag(&"puzzle.test.sw"))
	var s2 := PuzzleSwitch.new()
	s2.persist_flag = &"puzzle.test.sw"
	root.add_child(s2)
	assert_true(s2.is_active(), "restored")

func test_pressure_plate_player_and_box() -> void:
	var plate := PressurePlate.new()
	plate.position = Vector2(100, 100)
	plate.plate_size = Vector2(16, 16)
	root.add_child(plate)
	var p := _player(Vector2(300, 300))
	await wait_physics_frames(3)
	assert_false(plate.is_active())
	p.position = Vector2(100, 100)
	await wait_physics_frames(3)
	assert_true(plate.is_active(), "player presses")
	p.position = Vector2(300, 300)
	await wait_physics_frames(3)
	assert_false(plate.is_active(), "released")
	var box := PushBox.new()
	box.position = Vector2(100, 100)
	root.add_child(box)
	await wait_physics_frames(3)
	assert_true(plate.is_active(), "pushable presses")
	var other := StaticBody2D.new()
	other.position = Vector2(100, 100)
	PuzzlePhysics.ensure_rect_shape(other, Vector2(8, 8))
	box.queue_free()
	await wait_physics_frames(3)
	assert_false(plate.is_active(), "freed box releases")
	root.add_child(other)
	await wait_physics_frames(3)
	assert_false(plate.is_active(), "non-group bodies ignored")

func test_pressure_plate_latch() -> void:
	var plate := PressurePlate.new()
	plate.latch = true
	root.add_child(plate)
	var p := _player(Vector2(0, 0))
	await wait_physics_frames(3)
	assert_true(plate.is_active())
	p.position = Vector2(300, 0)
	await wait_physics_frames(3)
	assert_true(plate.is_active(), "latched")
	plate.reset()
	assert_false(plate.is_active())

func test_push_box_moves_onto_plate_and_blocks_at_wall() -> void:
	var plate := PressurePlate.new()
	plate.position = Vector2(116, 100)
	plate.plate_size = Vector2(12, 12)
	root.add_child(plate)
	var box := PushBox.new()
	box.position = Vector2(100, 100)
	root.add_child(box)
	var wall := StaticBody2D.new()
	wall.position = Vector2(140, 100)
	PuzzlePhysics.ensure_rect_shape(wall, Vector2(16, 64))
	root.add_child(wall)
	var actor := _player(Vector2(80, 100))
	await wait_physics_frames(2)
	assert_eq(box.direction_from(actor.global_position), Vector2.RIGHT)
	await box.interactable.interact(actor)
	await wait_until(func() -> bool: return not box.is_moving and box.global_position.x > 110.0, 1.0)
	assert_vec_almost_eq(box.global_position, Vector2(116, 100), 0.01, "moved one cell")
	await wait_physics_frames(3)
	assert_true(plate.is_active(), "box on plate")
	await wait_physics_frames(1)
	assert_false(box.push(Vector2.RIGHT), "wall blocks")
	assert_vec_almost_eq(box.global_position, Vector2(116, 100), 0.01)
	box.reset()
	await wait_physics_frames(3)
	assert_vec_almost_eq(box.global_position, Vector2(100, 100), 0.01, "reset to start")
	await wait_physics_frames(3)
	assert_false(plate.is_active())

func test_push_box_side_view_no_vertical() -> void:
	var box := PushBox.new()
	box.allow_vertical = false
	root.add_child(box)
	await wait_physics_frames(2)
	assert_eq(box.direction_from(Vector2(2, 40)), Vector2.LEFT, "vertical actor offset -> horizontal")
	assert_false(box.can_push(Vector2.UP))

func test_push_box_reset_waits_for_player() -> void:
	var box := PushBox.new()
	box.position = Vector2(0, 0)
	root.add_child(box)
	await wait_physics_frames(2)
	assert_true(box.push(Vector2.RIGHT))
	await wait_until(func() -> bool: return not box.is_moving, 1.0)
	var p := _player(Vector2(0, 0)) # standing on the start cell
	await wait_physics_frames(2)
	box.reset()
	await wait_physics_frames(4)
	assert_vec_almost_eq(box.global_position, Vector2(16, 0), 0.01, "deferred while blocked")
	p.position = Vector2(200, 0)
	await wait_physics_frames(4)
	assert_vec_almost_eq(box.global_position, Vector2(0, 0), 0.01, "reset once clear")

func test_reset_lever_resets_targets() -> void:
	var s := _switch(PuzzleSwitch.Mode.LATCH)
	var m := Mirror.new()
	root.add_child(m)
	s.operate()
	m.rotate_step()
	var lever := ResetLever.new()
	lever.targets = [s, m]
	root.add_child(lever)
	var msgs: Array[String] = []
	var cb := func(t: String, _d: float) -> void: msgs.append(t)
	GameState.notification_requested.connect(cb)
	await lever.interactable.interact(self)
	GameState.notification_requested.disconnect(cb)
	assert_false(s.is_active())
	assert_eq(m.step_index, 0)
	assert_eq(msgs.size(), 1)

func test_mirror_persisted_orientation() -> void:
	var m := Mirror.new()
	m.persist_flag = &"puzzle.test.mirror"
	m.rotation_degrees = 45
	root.add_child(m)
	m.rotate_step()
	assert_eq(GameState.get_flag(&"puzzle.test.mirror"), 1)
	var m2 := Mirror.new()
	m2.persist_flag = &"puzzle.test.mirror"
	m2.rotation_degrees = 45
	root.add_child(m2)
	assert_eq(m2.step_index, 1)
	assert_almost_eq(m2.rotation_degrees, 135.0, 0.01, "restored orientation")
	m2.reset()
	assert_false(GameState.has_flag(&"puzzle.test.mirror"))
	assert_almost_eq(m2.rotation_degrees, 45.0, 0.01)
