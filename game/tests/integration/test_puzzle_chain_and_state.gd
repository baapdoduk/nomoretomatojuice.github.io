extends TestCase
## Integration: A -> B -> C -> final door chain with plates/boxes/switches built from
## scenes, plus a water-level transition driving collision, light and a gate.

const DIR := "res://scenes/puzzles/"

var root: Node2D


func before_each() -> void:
	GameState.new_game(5)
	root = add_test_node(Node2D.new()) as Node2D


func _inst(file: String, pos: Vector2) -> Node2D:
	var n: Node2D = (load(DIR + file) as PackedScene).instantiate()
	n.position = pos
	return n

func _player(pos: Vector2) -> CharacterBody2D:
	var p := CharacterBody2D.new()
	p.add_to_group(&"player")
	p.collision_layer = Layers.PLAYER
	p.collision_mask = Layers.WORLD
	p.position = pos
	PuzzlePhysics.ensure_rect_shape(p, Vector2(12, 20))
	root.add_child(p)
	return p


func test_chain_switch_plate_box_final_door() -> void:
	# A: a latch switch opens passage B.
	var sw := _inst("switch.tscn", Vector2(0, 0)) as PuzzleSwitch
	sw.mode = PuzzleSwitch.Mode.LATCH
	var ctrl_a := _inst("puzzle_controller.tscn", Vector2(0, -40)) as PuzzleController
	ctrl_a.devices = [sw]
	ctrl_a.solved_flag = &"puzzle.chain.a"
	var gate_b := _inst("gate.tscn", Vector2(60, 0)) as Gate
	gate_b.inputs = [ctrl_a]
	# C: push a box onto a plate (beyond B).
	var plate := _inst("pressure_plate.tscn", Vector2(140, 0)) as PressurePlate
	var box := _inst("push_box.tscn", Vector2(116, 0)) as PushBox
	var ctrl_c := _inst("puzzle_controller.tscn", Vector2(130, -40)) as PuzzleController
	ctrl_c.devices = [ctrl_a, plate]
	ctrl_c.solved_flag = &"puzzle.chain.c"
	var final_door := _inst("gate.tscn", Vector2(220, 0)) as Gate
	final_door.inputs = [ctrl_c]
	for n: Node in [sw, ctrl_a, gate_b, plate, box, ctrl_c, final_door]:
		root.add_child(n)
	var actor := _player(Vector2(96, 0))
	await wait_physics_frames(4)
	assert_false(gate_b.is_open)
	assert_false(final_door.is_open, "final door visible but closed from the start")
	await sw.interactable.interact(actor)
	assert_true(ctrl_a.is_solved())
	assert_true(gate_b.is_open, "passage B opens")
	assert_false(final_door.is_open, "C not done yet")
	await box.interactable.interact(actor)
	await wait_until(func() -> bool: return not box.is_moving and box.global_position.x > 130.0, 1.0)
	await wait_physics_frames(4)
	assert_true(plate.is_active(), "box on plate")
	assert_true(ctrl_c.is_solved())
	assert_true(final_door.is_open, "final door opens")
	assert_true(GameState.has_flag(&"puzzle.chain.c"))

func test_water_level_transition() -> void:
	const WATER := &"world.chain.water"
	# Level 1 raises a platform (solid) at y=0 and blocks a beam; level 2 opens a gate.
	var lvl1 := _inst("state_driven.tscn", Vector2(60, 0)) as StateDriven
	lvl1.state_flag = WATER
	lvl1.active_values = [1, 2]
	var sensor := _inst("state_sensor.tscn", Vector2(0, -60)) as StateSensor
	sensor.state_flag = WATER
	sensor.active_values = [2]
	var gate := _inst("gate.tscn", Vector2(300, 0)) as Gate
	gate.inputs = [sensor]
	var emitter := _inst("light_emitter.tscn", Vector2(0, 0)) as LightEmitter
	var receiver := _inst("light_receiver.tscn", Vector2(140, 0)) as LightReceiver
	var lever := _inst("state_lever.tscn", Vector2(0, 80)) as StateLever
	lever.state_flag = WATER
	lever.cycle_values = [0, 1, 2]
	for n: Node in [lvl1, sensor, gate, emitter, receiver, lever]:
		root.add_child(n)
	var p := _player(Vector2(60, 0)) # standing where the platform would appear
	await wait_physics_frames(4)
	assert_true(receiver.is_lit(), "level 0: beam passes")
	await lever.interactable.interact(p)
	await wait_physics_frames(3)
	assert_eq(lever.get_value(), 0, "refused while the player stands there")
	p.position = Vector2(60, -60)
	await wait_physics_frames(2)
	await lever.interactable.interact(p)
	await wait_physics_frames(5)
	assert_eq(lever.get_value(), 1)
	assert_true(lvl1.is_enabled)
	assert_false(receiver.is_lit(), "level 1: platform blocks the beam")
	assert_false(gate.is_open)
	await lever.interactable.interact(p)
	await wait_physics_frames(3)
	assert_eq(lever.get_value(), 2)
	assert_true(gate.is_open, "level 2 opens the gate")
	assert_true(lever.is_active())
	lever.reset()
	await wait_physics_frames(5)
	assert_eq(lever.get_value(), 0, "reset back to level 0")
	assert_false(lvl1.is_enabled)
	assert_true(receiver.is_lit())
