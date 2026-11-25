extends PlayerTestCase
## puzzle_lab.tscn with the real Player: interactions go through the Player's
## Interactor (scripted PlayerInputState), scene changes through SceneRouter.

const LAB := "res://scenes/tests/puzzle_lab.tscn"
const WORLD := "res://scenes/tests/puzzle_lab_world.tscn"

var lab: Node
var player: Player


func _load(spawn: StringName = &"start") -> void:
	await change_scene_and_wait(LAB, spawn)
	lab = get_tree().current_scene
	player = SceneRouter.get_player() as Player
	assert_not_null(player, "player in lab")
	player.set_input_override(input)

## Teleports the player (feet position) and presses interact once through the Interactor.
func _use_at(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	await wait_physics_frames(3)
	input.interact_pressed = true
	# Past the Interactor's post-interaction cooldown (0.15 s).
	await wait_physics_frames(14)

func _n(path: String) -> Node:
	return lab.get_node(path)

func after_each() -> void:
	super.after_each()
	await unload_current_scene()


func test_section_a_solve_with_interactor_and_reset() -> void:
	await _load()
	var mirror := _n("SectionA/Mirror") as Mirror
	var recv := _n("SectionA/Receiver") as LightReceiver
	var ctrl := _n("SectionA/Controller") as PuzzleController
	var door := _n("SectionA/Door") as Gate
	await wait_physics_frames(4)
	assert_false(recv.is_lit(), "starts unlit")
	assert_false(door.is_open, "door closed")
	await _use_at(Vector2(500, 104))
	assert_eq(mirror.step_index, 1, "mirror rotated by the Interactor")
	assert_true(recv.is_lit(), "beam reaches receiver")
	assert_true(ctrl.is_solved(), "controller solved")
	assert_true(door.is_open, "door A open")
	assert_true(GameState.has_flag(&"puzzle.lab_a.solved"))
	await _use_at(Vector2(330, 284)) # reset lever
	await wait_physics_frames(6)
	assert_eq(mirror.step_index, 0, "mirror reset")
	assert_false(recv.is_lit(), "unlit after reset")
	assert_false(ctrl.is_solved(), "unsolved after reset")
	assert_false(GameState.has_flag(&"puzzle.lab_a.solved"), "flag cleared")
	assert_false(door.is_open, "door closed after reset")

func test_solved_state_survives_leaving_and_reentering() -> void:
	await _load()
	await wait_physics_frames(4)
	await _use_at(Vector2(500, 104))
	assert_true((_n("SectionA/Controller") as PuzzleController).is_solved())
	# Leave through the real door to the world lab, come back through its door.
	await _use_at(Vector2(80, 250))
	assert_true(await wait_transition(), "transition finished")
	assert_eq(SceneRouter.get_current_scene_path(), WORLD, "in world lab")
	await _load(&"from_puzzle_lab_world")
	await wait_physics_frames(6)
	assert_true((_n("SectionA/Controller") as PuzzleController).is_solved(), "loads solved")
	assert_true((_n("SectionA/Door") as Gate).is_open, "door still open")
	assert_eq((_n("SectionA/Mirror") as Mirror).step_index, 1, "mirror orientation persisted")
	assert_true((_n("SectionA/Receiver") as LightReceiver).is_lit(), "beam consistent")

func test_section_b_three_mirrors_and_obstacle() -> void:
	await _load()
	var recv := _n("SectionB/Receiver") as LightReceiver
	var box := _n("SectionB/Obstacle") as PushBox
	await wait_physics_frames(4)
	assert_false(recv.is_lit())
	await _use_at(Vector2(720, 254)) # rotate mirror 3 (stand below it)
	assert_eq((_n("SectionB/Mirror3") as Mirror).step_index, 1)
	assert_false(recv.is_lit(), "box still blocks the beam")
	await _use_at(Vector2(876, 146)) # push the box to the right
	await wait_until(func() -> bool: return not box.is_moving, 1.0)
	await wait_physics_frames(4)
	assert_vec_almost_eq(box.global_position, Vector2(916, 136), 0.5, "box pushed one cell")
	assert_true(recv.is_lit(), "three mirrors reach the receiver")
	assert_true((_n("SectionB/Door") as Gate).is_open)

func test_loop_section_is_bounded() -> void:
	await _load()
	await wait_physics_frames(4)
	var e := _n("SectionC/Emitter") as LightEmitter
	assert_not_null(e.last_result)
	assert_eq(e.last_result.end_reason, LightTracer.EndReason.CYCLE, "loop detected")
	assert_true(e.last_result.bounces <= 12)

func test_chain_and_shortcut() -> void:
	await _load()
	capture_toasts()
	var shortcut := _n("SectionE/Shortcut") as OneWayDoor
	var passage := _n("SectionE/PassageB") as Gate
	var final_door := _n("SectionE/FinalDoor") as Gate
	await wait_physics_frames(4)
	assert_false(final_door.is_open, "final door closed (goal visible from start)")
	assert_not_null(_n("SectionE/Goal"), "goal landmark present")
	# Shortcut is locked from the start side.
	await _use_at(Vector2(588, 388))
	assert_false(shortcut.is_open, "locked from the start side")
	assert_true(toasts.has(shortcut.wrong_side_message), "wrong-side message shown")
	# A -> B
	await _use_at(Vector2(520, 450))
	assert_true(passage.is_open, "passage B open after switch A")
	assert_true(GameState.has_flag(&"door.lab_chain_b.open"))
	# Far side: C, then the shortcut from the right.
	await _use_at(Vector2(690, 550))
	assert_true((_n("SectionE/ControllerC") as PuzzleController).is_solved(), "chain solved")
	assert_true(final_door.is_open, "final door open")
	await _use_at(Vector2(628, 388))
	assert_true(shortcut.is_open, "shortcut opened from the far side")
	# Reload: shortcut and chain progress persist.
	await _load()
	await wait_physics_frames(6)
	assert_true((_n("SectionE/Shortcut") as OneWayDoor).is_open, "shortcut stays open")
	assert_true((_n("SectionE/PassageB") as Gate).is_open, "passage stays open")
	assert_true((_n("SectionE/FinalDoor") as Gate).is_open, "final door stays open")
