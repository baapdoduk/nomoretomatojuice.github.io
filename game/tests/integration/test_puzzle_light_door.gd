extends TestCase
## Integration: light puzzle built from the reusable scenes in res://scenes/puzzles/.
## Two receivers (AND) -> PuzzleController (solved_flag) -> Gate; reset; persistence
## across "scene re-entry" (layout freed and rebuilt with the same GameState).

const DIR := "res://scenes/puzzles/"
const SOLVED_FLAG := &"puzzle.test_light_door.solved"
const MIRROR_FLAG := &"puzzle.test_light_door.mirror"

var root: Node2D


func before_each() -> void:
	GameState.new_game(5)
	root = add_test_node(Node2D.new()) as Node2D


func _inst(file: String, pos: Vector2, rot_deg: float = 0.0) -> Node:
	var n: Node2D = (load(DIR + file) as PackedScene).instantiate()
	n.position = pos
	n.rotation_degrees = rot_deg
	return n


## Emitter A shoots straight at receiver 1. Emitter B needs mirror M (starts at
## -45 = wrong, one 90 deg step makes it 45 = right->down) to reach receiver 2.
func _build(layout: Node2D, persist_mirror: bool = false) -> Dictionary:
	var ea := _inst("light_emitter.tscn", Vector2(0, 0))
	var r1 := _inst("light_receiver.tscn", Vector2(120, 0)) as LightReceiver
	var eb := _inst("light_emitter.tscn", Vector2(0, 100))
	var m := _inst("mirror.tscn", Vector2(150, 100), -45) as Mirror
	if persist_mirror:
		m.persist_flag = MIRROR_FLAG
	var r2 := _inst("light_receiver.tscn", Vector2(150, 200)) as LightReceiver
	var ctrl := _inst("puzzle_controller.tscn", Vector2(300, 0)) as PuzzleController
	ctrl.devices = [r1, r2]
	ctrl.solved_flag = SOLVED_FLAG
	var gate := _inst("gate.tscn", Vector2(400, 0)) as Gate
	gate.inputs = [ctrl]
	for n: Node in [ea, r1, eb, m, r2, ctrl, gate]:
		layout.add_child(n)
	return {"r1": r1, "r2": r2, "m": m, "ctrl": ctrl, "gate": gate, "eb": eb}

func _settle() -> void:
	await wait_physics_frames(5)


func test_two_receivers_and_open_gate() -> void:
	var p := _build(root)
	var ctrl: PuzzleController = p.ctrl
	var gate: Gate = p.gate
	var solved := [0]
	ctrl.solved.connect(func() -> void: solved[0] += 1)
	await _settle()
	assert_true((p.r1 as LightReceiver).is_lit(), "receiver 1 lit")
	assert_false((p.r2 as LightReceiver).is_lit(), "receiver 2 not yet")
	assert_false(ctrl.is_solved(), "AND not satisfied")
	assert_false(gate.is_open)
	await (p.m as Mirror).interactable.interact(self)
	await _settle()
	assert_true((p.r2 as LightReceiver).is_lit(), "mirror rotated onto receiver 2")
	assert_true(ctrl.is_solved(), "solved")
	assert_eq(solved[0], 1)
	assert_true(GameState.has_flag(SOLVED_FLAG), "progress flag written")
	assert_true(gate.is_open, "door opens")
	# Latched: breaking the beam keeps the puzzle solved and the door open.
	(p.eb as LightEmitter).set_powered(false)
	await _settle()
	assert_true(ctrl.is_solved())
	assert_true(gate.is_open)

func test_reset_restores_everything() -> void:
	var p := _build(root)
	await _settle()
	await (p.m as Mirror).interactable.interact(self)
	await _settle()
	assert_true((p.ctrl as PuzzleController).is_solved())
	var lever := _inst("reset_lever.tscn", Vector2(500, 0)) as ResetLever
	lever.targets = [p.ctrl, p.m, p.gate]
	root.add_child(lever)
	await lever.interactable.interact(self)
	await _settle()
	assert_eq((p.m as Mirror).step_index, 0, "mirror back to authored angle")
	assert_false((p.r2 as LightReceiver).is_active(), "receiver 2 unlit again")
	assert_true((p.r1 as LightReceiver).is_active(), "receiver 1 still lit (its beam is fixed)")
	assert_false((p.ctrl as PuzzleController).is_solved(), "controller unsolved")
	assert_false(GameState.has_flag(SOLVED_FLAG), "flag cleared")
	assert_false((p.gate as Gate).is_open, "gate closed")
	# Solvable again after the reset.
	await (p.m as Mirror).interactable.interact(self)
	await _settle()
	assert_true((p.ctrl as PuzzleController).is_solved(), "re-solvable")

func test_persistence_on_reentry() -> void:
	var first := Node2D.new()
	root.add_child(first)
	var p := _build(first, true)
	await _settle()
	await (p.m as Mirror).interactable.interact(self)
	await _settle()
	assert_true((p.ctrl as PuzzleController).is_solved())
	first.queue_free()
	await wait_frames(2)
	# Re-enter: same GameState, fresh nodes.
	var second := Node2D.new()
	root.add_child(second)
	var q := _build(second, true)
	await _settle()
	assert_true((q.ctrl as PuzzleController).is_solved(), "loads solved")
	assert_true((q.gate as Gate).is_open, "door open on load")
	assert_eq((q.m as Mirror).step_index, 1, "mirror orientation persisted")
	assert_true((q.r2 as LightReceiver).is_lit(), "beam consistent with persisted mirror")

func test_all_puzzle_scenes_instantiate_cleanly() -> void:
	for file in DirAccess.get_files_at(DIR):
		if not file.ends_with(".tscn"):
			continue
		var n := (load(DIR + file) as PackedScene).instantiate()
		assert_not_null(n, file)
		root.add_child(n)
	await _settle()
