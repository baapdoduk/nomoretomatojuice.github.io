extends TestCase
## Map-wide state transitions (StateDriven / StateLever / StateSensor) and parallel world.

const WATER := &"world.test.water_level"
const LAYER := &"world.test.layer"

var root: Node2D


func before_each() -> void:
	GameState.new_game(5)
	root = add_test_node(Node2D.new()) as Node2D


func _player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.add_to_group(&"player")
	p.collision_layer = Layers.PLAYER
	p.collision_mask = 0
	p.position = pos
	PuzzlePhysics.ensure_rect_shape(p, Vector2(12, 20))
	root.add_child(p)
	return p

## A StateDriven node with one solid block at `pos` and a visual child.
func _driven(flag: StringName, values: Array[int], pos: Vector2, size: Vector2 = Vector2(64, 16),
		display: StateDriven.InactiveDisplay = StateDriven.InactiveDisplay.HIDE) -> StateDriven:
	var sd := StateDriven.new()
	sd.state_flag = flag
	sd.active_values = values
	sd.inactive_display = display
	var body := StaticBody2D.new()
	body.position = pos
	PuzzlePhysics.ensure_rect_shape(body, size)
	sd.add_child(body)
	var visual := Polygon2D.new()
	visual.name = "Visual"
	sd.add_child(visual)
	root.add_child(sd)
	return sd

func _shape_of(sd: StateDriven) -> CollisionShape2D:
	return PuzzlePhysics.collect_solid_shapes(sd)[0] as CollisionShape2D


func test_state_driven_switches_visual_and_collision() -> void:
	var lvl1 := _driven(WATER, [1, 2], Vector2(0, 0))
	var lvl2 := _driven(WATER, [2], Vector2(0, -32))
	await wait_physics_frames(2)
	assert_false(lvl1.is_enabled)
	assert_false(lvl1.visible)
	assert_true(_shape_of(lvl1).disabled, "collision off at level 0")
	GameState.set_flag(WATER, 1)
	await wait_physics_frames(2)
	assert_true(lvl1.is_enabled and lvl1.visible)
	assert_false(_shape_of(lvl1).disabled, "collision on at level 1")
	assert_false(lvl2.is_enabled)
	GameState.set_flag(WATER, 2)
	await wait_physics_frames(2)
	assert_true(lvl2.is_enabled)
	assert_false(_shape_of(lvl2).disabled)

func test_lever_accepts_change_when_clear() -> void:
	_driven(WATER, [1], Vector2(0, 0))
	_player(Vector2(0, -60)) # standing well above the raised platform
	var lever := StateLever.new()
	lever.state_flag = WATER
	lever.cycle_values = [0, 1, 2]
	root.add_child(lever)
	await wait_physics_frames(2)
	assert_true(lever.request_next(), "accepted")
	assert_eq(GameState.get_flag(WATER), 1)
	assert_eq(lever.get_next_value(), 2)

func test_lever_refuses_change_that_would_trap_player() -> void:
	var sd := _driven(WATER, [1], Vector2(0, 0))
	var p := _player(Vector2(0, 0)) # would be inside the new collider
	var lever := StateLever.new()
	lever.state_flag = WATER
	root.add_child(lever)
	var msgs: Array[String] = []
	var cb := func(t: String, _d: float) -> void: msgs.append(t)
	GameState.notification_requested.connect(cb)
	var refused := [0]
	lever.change_refused.connect(func(_v: int, b: Array[Node]) -> void:
		refused[0] += 1
		assert_true(b.has(p), "player reported as blocker"))
	await wait_physics_frames(2)
	assert_false(lever.request_value(1), "refused")
	GameState.notification_requested.disconnect(cb)
	assert_eq(GameState.get_flag(WATER, 0), 0, "state unchanged")
	assert_false(sd.is_enabled)
	assert_eq(refused[0], 1)
	assert_eq(msgs.size(), 1)
	assert_true(msgs[0].contains("blocked") if msgs.size() > 0 else false, "blocked message")
	p.position = Vector2(200, 0)
	await wait_physics_frames(2)
	assert_true(lever.request_value(1), "accepted after moving away")

func test_lever_refuses_when_pushable_would_be_trapped() -> void:
	_driven(WATER, [1], Vector2(0, 0))
	var box := PushBox.new()
	box.position = Vector2(10, 0)
	root.add_child(box)
	var lever := StateLever.new()
	lever.state_flag = WATER
	lever.blocked_message = ""
	root.add_child(lever)
	await wait_physics_frames(2)
	assert_false(lever.request_value(1), "box would be trapped")

func test_lever_interaction_path() -> void:
	_driven(WATER, [1], Vector2(0, 0))
	var lever := StateLever.new()
	lever.state_flag = WATER
	lever.mode = StateLever.Mode.SET
	lever.target_value = 1
	root.add_child(lever)
	await lever.interactable.interact(self)
	await wait_physics_frames(2)
	assert_eq(GameState.get_flag(WATER), 1, "interaction applies after physics-frame validation")

func test_state_sensor_drives_gate() -> void:
	var sensor := StateSensor.new()
	sensor.state_flag = &"world.test.power"
	root.add_child(sensor)
	var g := Gate.new()
	g.inputs = [sensor]
	root.add_child(g)
	await wait_physics_frames(2)
	assert_false(g.is_open)
	GameState.set_flag(&"world.test.power", 1)
	assert_true(sensor.is_active())
	assert_true(g.is_open, "power on opens gate")

func test_state_change_updates_light() -> void:
	var e := LightEmitter.new()
	root.add_child(e)
	var r := LightReceiver.new()
	r.position = Vector2(120, 0)
	root.add_child(r)
	_driven(WATER, [1], Vector2(60, 0), Vector2(8, 40))
	await wait_physics_frames(4)
	assert_true(r.is_lit())
	GameState.set_flag(WATER, 1)
	await wait_physics_frames(4)
	assert_false(r.is_lit(), "raised water blocks the beam")

func test_parallel_world_switch() -> void:
	var a := _driven(LAYER, [0], Vector2(0, 0))
	var b := _driven(LAYER, [1], Vector2(0, 40), Vector2(64, 16), StateDriven.InactiveDisplay.GHOST)
	var p := _player(Vector2(100, 40))
	var sw := ParallelWorldSwitch.new()
	sw.state_flag = LAYER
	root.add_child(sw)
	await wait_physics_frames(2)
	assert_true(a.is_enabled)
	assert_false(b.is_enabled)
	assert_false(_shape_of(a).disabled)
	assert_true(_shape_of(b).disabled, "only the active layer collides")
	assert_true(b.visible, "ghosted layer stays visible")
	assert_true(sw.switch_world(), "switch to layer 1")
	await wait_physics_frames(2)
	assert_eq(sw.get_active_layer(), 1)
	assert_true(_shape_of(a).disabled)
	assert_false(_shape_of(b).disabled)
	# Standing where layer 0 has a wall: switching back is refused.
	p.position = Vector2(0, 0)
	await wait_physics_frames(2)
	var msgs: Array[String] = []
	var cb := func(t: String, _d: float) -> void: msgs.append(t)
	GameState.notification_requested.connect(cb)
	assert_false(sw.switch_world(), "refused: would be inside layer 0")
	GameState.notification_requested.disconnect(cb)
	assert_eq(sw.get_active_layer(), 1)
	assert_eq(msgs.size(), 1)
