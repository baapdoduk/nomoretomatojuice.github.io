extends TestCase
## Gate logic (AND/OR/invert/latch/conditions/anti-trap/persistence) and PuzzleController.

var root: Node2D


func before_each() -> void:
	GameState.new_game(5)
	root = add_test_node(Node2D.new()) as Node2D


func _dev(on: bool = false) -> PuzzleDevice:
	var d := PuzzleDevice.new()
	d.start_active = on
	root.add_child(d)
	return d

func _gate(inputs: Array[Node], logic: PuzzleInputs.Logic = PuzzleInputs.Logic.ALL, invert: bool = false) -> Gate:
	var g := Gate.new()
	g.inputs = inputs
	g.logic = logic
	g.invert = invert
	root.add_child(g)
	return g

func _player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.add_to_group(&"player")
	p.collision_layer = Layers.PLAYER
	p.collision_mask = 0
	p.position = pos
	PuzzlePhysics.ensure_rect_shape(p, Vector2(12, 20))
	root.add_child(p)
	return p

## Gates close one physics frame after their condition drops (anti-trap check).
func _settle() -> void:
	await wait_physics_frames(3)

func _shape_disabled(g: Gate) -> bool:
	for c in g.get_children():
		if c is CollisionShape2D:
			return c.disabled
	return false


func test_gate_and() -> void:
	var a := _dev()
	var b := _dev()
	var g := _gate([a, b])
	await _settle()
	assert_false(g.is_open)
	a.set_active(true)
	assert_false(g.is_open, "AND needs both")
	b.set_active(true)
	assert_true(g.is_open)
	await _settle()
	assert_true(_shape_disabled(g), "collision off while open")
	a.set_active(false)
	await _settle()
	assert_false(g.is_open, "closes again")
	assert_false(_shape_disabled(g), "collision back on")

func test_gate_or() -> void:
	var a := _dev()
	var b := _dev()
	var g := _gate([a, b], PuzzleInputs.Logic.ANY)
	await _settle()
	assert_false(g.is_open)
	b.set_active(true)
	assert_true(g.is_open, "OR needs one")

func test_gate_invert() -> void:
	var a := _dev()
	var g := _gate([a], PuzzleInputs.Logic.ALL, true)
	await _settle()
	assert_true(g.is_open, "inverted: open while input off")
	a.set_active(true)
	await _settle()
	assert_false(g.is_open)

func test_gate_latch_open() -> void:
	var a := _dev()
	var g := _gate([a])
	g.latch_open = true
	a.set_active(true)
	await _settle()
	assert_true(g.is_open)
	a.set_active(false)
	await _settle()
	assert_true(g.is_open, "latched")
	g.reset()
	await _settle()
	assert_false(g.is_open, "reset closes")

func test_conditional_gate_items_and_flags() -> void:
	var g := Gate.new()
	g.required_items = [&"key_x"]
	g.required_flags = [&"boss.a.defeated"]
	root.add_child(g)
	await _settle()
	assert_false(g.is_open)
	var key := ItemData.new()
	key.id = &"key_x"
	key.type = ItemData.ItemType.PROGRESSION
	GameState.add_item(key)
	await _settle()
	assert_false(g.is_open, "flag still missing")
	GameState.set_flag(&"boss.a.defeated")
	assert_true(g.is_open, "opens when all conditions hold")
	assert_true(GameState.has_item(&"key_x"), "item never consumed")

func test_gate_without_config_stays_closed_until_forced() -> void:
	var g := Gate.new()
	root.add_child(g)
	await _settle()
	assert_false(g.is_open)
	g.force_open()
	assert_true(g.is_open)

func test_gate_anti_trap_defers_close() -> void:
	var a := _dev(true)
	var g := _gate([a])
	g.position = Vector2(100, 0)
	var p := _player(Vector2(100, 0))
	await _settle()
	assert_true(g.is_open)
	var deferred := [0]
	g.closing_deferred.connect(func(_b: Array[Node]) -> void: deferred[0] += 1)
	a.set_active(false)
	await _settle()
	assert_true(g.is_open, "does not close on the player")
	assert_true(g.is_close_pending)
	assert_eq(deferred[0], 1)
	await wait_physics_frames(5)
	assert_eq(deferred[0], 1, "reported once")
	p.position = Vector2(200, 0)
	await _settle()
	assert_false(g.is_open, "closes once clear")
	assert_false(g.is_close_pending)

func test_gate_reopen_cancels_pending_close() -> void:
	var a := _dev(true)
	var g := _gate([a])
	_player(Vector2(0, 0))
	await _settle()
	a.set_active(false)
	await _settle()
	assert_true(g.is_close_pending)
	a.set_active(true)
	assert_false(g.is_close_pending)
	assert_true(g.is_open)

func test_gate_open_flag_persistence() -> void:
	var a := _dev()
	var g := _gate([a])
	g.open_flag = &"door.test.shortcut"
	await _settle()
	a.set_active(true)
	assert_true(GameState.has_flag(&"door.test.shortcut"))
	a.set_active(false)
	await _settle()
	assert_true(g.is_open, "open_flag gates stay open")
	# "Re-entering the scene": a fresh gate with the same flag loads open.
	var g2 := Gate.new()
	g2.inputs = [_dev()]
	g2.open_flag = &"door.test.shortcut"
	root.add_child(g2)
	await _settle()
	assert_true(g2.is_open, "loads open")

func test_controller_all_any_and_signals() -> void:
	var a := _dev()
	var b := _dev()
	var c := PuzzleController.new()
	c.devices = [a, b]
	c.latch = false
	root.add_child(c)
	var events: Array[String] = []
	c.solved.connect(func() -> void: events.append("solved"))
	c.unsolved.connect(func() -> void: events.append("unsolved"))
	c.state_changed.connect(func(s: bool) -> void: events.append("state:%s" % s))
	await wait_frames(1)
	a.set_active(true)
	assert_false(c.is_solved())
	b.set_active(true)
	assert_true(c.is_solved())
	b.set_active(false)
	assert_false(c.is_solved(), "unlatched controller unsolves")
	assert_eq(events, ["solved", "state:true", "unsolved", "state:false"] as Array[String])
	c.mode = PuzzleInputs.Logic.ANY
	c._on_device_changed(true)
	assert_true(c.is_solved(), "ANY with one device")

func test_controller_latch_reset_and_feedback() -> void:
	var s1 := PuzzleSwitch.new()
	s1.mode = PuzzleSwitch.Mode.LATCH
	root.add_child(s1)
	var s2 := PuzzleSwitch.new()
	root.add_child(s2)
	var player := AudioStreamPlayer.new()
	root.add_child(player)
	var flash := Node2D.new()
	root.add_child(flash)
	var c := PuzzleController.new()
	c.devices = [s1, s2]
	c.solved_flag = &"puzzle.test.ctrl.solved"
	c.success_player = player
	c.flash_targets = [flash]
	root.add_child(c)
	var feedback := [0]
	c.success_feedback.connect(func() -> void: feedback[0] += 1)
	await wait_frames(1)
	s1.operate()
	s2.operate()
	assert_true(c.is_solved())
	assert_true(GameState.has_flag(&"puzzle.test.ctrl.solved"), "progress flag")
	assert_eq(feedback[0], 1)
	s2.operate()
	assert_true(c.is_solved(), "latched")
	c.reset()
	assert_false(c.is_solved())
	assert_false(s1.is_active(), "reset resets devices")
	assert_false(s2.is_active())
	assert_false(GameState.has_flag(&"puzzle.test.ctrl.solved"), "flag cleared")

func test_controller_loads_solved_from_flag() -> void:
	GameState.set_flag(&"puzzle.test.loaded.solved", true)
	var d := _dev()
	var c := PuzzleController.new()
	c.devices = [d]
	c.solved_flag = &"puzzle.test.loaded.solved"
	root.add_child(c)
	var feedback := [0]
	c.success_feedback.connect(func() -> void: feedback[0] += 1)
	var g := _gate([c])
	await _settle()
	assert_true(c.is_solved(), "already solved")
	assert_true(g.is_open, "downstream gate open on load")
	assert_eq(feedback[0], 0, "no success feedback on load")

func test_controller_chain() -> void:
	# switch A -> controller A -> (gate B) ; controller A + plate-ish device -> controller C -> final gate
	var sw := PuzzleSwitch.new()
	root.add_child(sw)
	var ca := PuzzleController.new()
	ca.devices = [sw]
	root.add_child(ca)
	var dev_c := _dev()
	var cc := PuzzleController.new()
	cc.devices = [ca, dev_c]
	root.add_child(cc)
	var final_gate := _gate([cc])
	await _settle()
	sw.operate()
	assert_true(ca.is_solved())
	assert_false(cc.is_solved())
	dev_c.set_active(true)
	assert_true(cc.is_solved())
	assert_true(final_gate.is_open)
	cc.reset()
	assert_false(ca.is_solved(), "chained reset reaches upstream controllers")
	assert_false(sw.is_active())
	await _settle()
	assert_false(final_gate.is_open)

func test_controller_hint_after_delay_when_player_near() -> void:
	var c := PuzzleController.new()
	c.devices = [_dev()]
	c.hint_text = "Try the mirrors."
	c.hint_delay = 0.3
	c.hint_radius = 100.0
	root.add_child(c)
	var p := _player(Vector2(500, 0))
	var msgs: Array[String] = []
	var cb := func(t: String, _d: float) -> void: msgs.append(t)
	GameState.notification_requested.connect(cb)
	await wait_seconds(0.45)
	assert_eq(msgs.size(), 0, "player far away: no hint")
	p.position = Vector2(20, 0)
	await wait_seconds(0.45)
	GameState.notification_requested.disconnect(cb)
	assert_eq(msgs.size(), 1, "hint shown once after delay")
	assert_eq(msgs[0] if msgs.size() > 0 else "", "Try the mirrors.")


func test_gate_close_enables_collision_in_the_same_physics_step() -> void:
	var a := _dev(true)
	var g := _gate([a])
	await _settle()
	assert_true(g.is_open)
	var at_close := []
	g.closed.connect(func() -> void: at_close.append(_shape_disabled(g)))
	a.set_active(false)
	await _settle()
	assert_false(g.is_open)
	assert_eq(at_close, [false], "solid immediately when closed (no deferred gap)")

func test_gate_close_check_is_inflated() -> void:
	var a := _dev(true)
	var g := _gate([a])
	g.position = Vector2(100, 0)
	# Gate is 16 px wide (92..108); a 12 px body centred at 115 starts at 109 (1 px gap).
	var p := _player(Vector2(115, 0))
	await _settle()
	a.set_active(false)
	await _settle()
	assert_true(g.is_open, "body within the safety margin defers the close")
	p.position = Vector2(140, 0)
	await _settle()
	assert_false(g.is_open)
