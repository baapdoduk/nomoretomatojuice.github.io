extends PlayerTestCase
## Cross-module integration slice (integration_overworld <-> integration_interior)
## driven with the real Player through SceneRouter.

const OW := "res://scenes/tests/integration_overworld.tscn"
const IN := "res://scenes/tests/integration_interior.tscn"
const BOSS_FLAG := &"boss.int_guardian.defeated"


func after_each() -> void:
	super.after_each()
	await unload_current_scene()


func _load(path: String, spawn: StringName = &"") -> Player:
	await change_scene_and_wait(path, spawn)
	var p := SceneRouter.get_player() as Player
	input = PlayerInputState.new()
	p.set_input_override(input)
	return p

func _n(path: NodePath) -> Node:
	return get_tree().current_scene.get_node(path)

func _place(p: Player, pos: Vector2, frames: int = 4) -> void:
	p.global_position = pos
	p.velocity = Vector2.ZERO
	await wait_physics_frames(frames)

func _interact(frames: int = 4) -> void:
	input.interact_pressed = true
	await wait_physics_frames(frames)

func _close_popups() -> void:
	var popup := find_popup(get_tree().current_scene)
	if popup:
		popup.close()
	await wait_frames(2)


func test_transitions_keep_items_flags_health() -> void:
	var p := await _load(OW, &"start")
	assert_vec_almost_eq(p.global_position, (_n(^"Spawns/Start") as Node2D).global_position, 0.5, "start spawn")
	var view_landmark := (_n(^"Corridor/GoalLandmark") as Node2D).global_position
	assert_true(view_landmark.x < 640.0, "goal landmark inside the start view")
	await _place(p, (_n(^"Interactables/Memory") as Node2D).global_position + Vector2(0, 8))
	assert_true(GameState.has_item(&"int_memory"), "memory collected")
	await _close_popups()
	GameState.apply_damage(1)
	GameState.set_flag(&"int.test.flag", 7)
	await (_n(^"Interactables/DoorInterior") as SceneDoor).interact(p)
	assert_true(await wait_transition())
	assert_eq(SceneRouter.get_current_scene_path(), IN)
	p = SceneRouter.get_player() as Player
	assert_eq(p.movement_mode, Player.MovementMode.SIDE_VIEW, "side view inside")
	assert_vec_almost_eq(p.global_position, (_n(^"Spawns/FromOverworld") as Node2D).global_position, 0.5, "from_integration_overworld")
	assert_eq(GameState.health, 4, "health kept")
	assert_true(GameState.has_item(&"int_memory"))
	assert_eq(GameState.get_flag(&"int.test.flag"), 7)
	GameState.add_item(load("res://resources/items/int_key.tres"))
	await (_n(^"Interactables/DoorOut") as SceneDoor).interact(p)
	assert_true(await wait_transition())
	assert_eq(SceneRouter.get_current_scene_path(), OW)
	p = SceneRouter.get_player() as Player
	assert_eq(p.movement_mode, Player.MovementMode.TOP_DOWN)
	assert_vec_almost_eq(p.global_position, (_n(^"Spawns/FromInterior") as Node2D).global_position, 0.5, "from_integration_interior")
	assert_eq(GameState.health, 4)
	assert_eq(GameState.get_item_count(&"int_memory"), 1)
	assert_eq(GameState.get_item_count(&"int_key"), 1)
	assert_false((_n(^"Interactables/Memory") as Pickup).visible, "collected memory stays hidden")


func test_interior_lever_gate_and_key() -> void:
	var p := await _load(IN, &"from_integration_overworld")
	var gate := _n(^"Interactables/LeverGate") as Gate
	assert_false(gate.is_open, "lever gate closed")
	await _place(p, Vector2(560, -1))
	input.move = Vector2.RIGHT
	await wait_physics_frames(30)
	input.move = Vector2.ZERO
	assert_true(p.global_position.x < 592.0, "blocked by the gate (x=%.1f)" % p.global_position.x)
	await _place(p, Vector2(530, -1))
	var lever := _n(^"Interactables/Lever") as ContextActionInteractable
	assert_eq(p.interactor.target, lever, "lever focused")
	await _interact(2)
	assert_true(lever.is_running, "context action started")
	Input.action_press(&"interact")
	await wait_seconds(lever.hold_time + 0.2)
	Input.action_release(&"interact")
	assert_true(lever.is_completed, "lever pulled")
	await wait_seconds(0.25)
	assert_true(gate.is_open, "gate opened by the context action")
	input.move = Vector2.RIGHT
	assert_true(await wait_until(func() -> bool: return GameState.has_item(&"int_key"), 3.0), "walked to the key")
	input.move = Vector2.ZERO


func test_key_gate_refuses_then_opens() -> void:
	var p := await _load(OW, &"start")
	var gate := _n(^"Puzzle/GateKey") as Gate
	await _place(p, Vector2(290, 234))
	input.move = Vector2.RIGHT
	await wait_physics_frames(30)
	assert_false(gate.is_open, "closed without the key")
	assert_true(p.global_position.x < 320.0, "blocked (x=%.1f)" % p.global_position.x)
	GameState.add_item(load("res://resources/items/int_key.tres"))
	await wait_physics_frames(2)
	assert_true(gate.is_open, "opens with the key")
	assert_true(GameState.has_flag(&"int.gate_key.open"), "gate persisted")
	assert_true(GameState.has_item(&"int_key"), "key not consumed")
	await wait_physics_frames(30)
	assert_true(p.global_position.x > 340.0, "walked through (x=%.1f)" % p.global_position.x)


func test_light_puzzle_via_interactor() -> void:
	var p := await _load(OW, &"start")
	var mirror_a := _n(^"Puzzle/MirrorA") as Mirror
	var mirror_b := _n(^"Puzzle/MirrorB") as Mirror
	var recv := _n(^"Puzzle/Receiver") as LightReceiver
	var gate := _n(^"Puzzle/GatePuzzle") as Gate
	await wait_physics_frames(4)
	assert_false(recv.is_lit(), "unsolved at start")
	await _place(p, Vector2(604, 164))
	assert_eq(p.interactor.target, mirror_a.interactable, "mirror A focused")
	await _interact(8)
	assert_eq(mirror_a.step_index, 1, "mirror A rotated by the Interactor")
	assert_false(recv.is_lit(), "one mirror is not enough")
	await _place(p, Vector2(604, 326))
	assert_eq(p.interactor.target, mirror_b.interactable, "mirror B focused")
	await wait_seconds(0.2)  # interaction cooldown
	await _interact(8)
	assert_eq(mirror_b.step_index, 1)
	assert_true(recv.is_lit(), "receiver lit")
	assert_true((_n(^"Puzzle/Controller") as PuzzleController).is_solved(), "controller solved")
	assert_true(gate.is_open, "puzzle gate open")
	assert_true(GameState.has_flag(&"int.puzzle.solved"))


func test_boss_death_respawns_at_arena_checkpoint() -> void:
	var p := await _load(OW, &"start")
	GameState.add_item(load("res://resources/items/int_key.tres"))
	GameState.add_item(load("res://resources/items/int_memory.tres"))
	GameState.set_flag(&"int.puzzle.solved", true)
	await _place(p, Vector2(690, 240), 6)
	assert_eq(String(GameState.checkpoint.get("spawn_id")), "cp_int_arena", "arena checkpoint saved")
	var boss := _n(^"Arena/Boss") as Boss
	await _place(p, Vector2(760, 240), 4)
	assert_true(boss.is_fight_active(), "trigger started the fight")
	GameState.set_flag(&"int.test.after_cp", true)
	GameState.apply_damage(2)
	p.kill()
	assert_true(await wait_until(func() -> bool: return SceneRouter.is_transitioning, 3.0), "respawn starts")
	assert_true(await wait_transition())
	p = SceneRouter.get_player() as Player
	var cp := _n(^"Arena/CheckpointArena") as Checkpoint
	assert_vec_almost_eq(p.global_position, cp.spawn_point.global_position, 0.5, "at arena checkpoint")
	assert_eq(GameState.health, GameState.max_health, "health restored")
	assert_eq(GameState.get_item_count(&"int_key"), 1, "no key loss/duplication")
	assert_eq(GameState.get_item_count(&"int_memory"), 1)
	assert_false(GameState.has_flag(&"int.test.after_cp"), "post-checkpoint flag rolled back")
	assert_true((_n(^"Puzzle/GatePuzzle") as Gate).is_open, "solved puzzle gate stays open")
	assert_true((_n(^"Puzzle/GateKey") as Gate).is_open, "key gate open")
	var boss2 := _n(^"Arena/Boss") as Boss
	assert_false(boss2.is_fight_active(), "boss reset, waits for the trigger")
	assert_false((_n(^"Interactables/Memory") as Pickup).visible, "owned memory not respawned")


func test_defeat_boss_with_melee_opens_victory_gate() -> void:
	var p := await _load(OW, &"start")
	GameState.set_flag(&"int.puzzle.solved", true)
	p.health.set_invulnerable_flag(&"test", true)
	var boss := _n(^"Arena/Boss") as Boss
	var gate := _n(^"Arena/GateVictory") as Gate
	assert_false(gate.is_open)
	await _place(p, Vector2(760, 240))
	assert_true(boss.is_fight_active())
	var hits_in_recovery := [0, 0]
	boss.health.damaged.connect(func(_e: DamageEvent) -> void:
		hits_in_recovery[0 if boss.state == Boss.State.RECOVERY else 1] += 1)
	var t := 0.0
	while not boss.is_defeated() and t < 60.0:
		if boss.state == Boss.State.RECOVERY:
			p.global_position = boss.global_position + Vector2(-30, 10)
			p.set_facing(Vector2.RIGHT)
			input.attack_pressed = true
		else:
			p.global_position = Vector2(700, 300)
		await wait_seconds(0.35)
		t += 0.35
	assert_true(boss.is_defeated(), "boss defeated by melee (%.1f s)" % t)
	assert_eq(hits_in_recovery[0], boss.config.max_health, "all hits landed during RECOVERY")
	assert_true(GameState.has_flag(BOSS_FLAG))
	await wait_physics_frames(3)
	assert_true(gate.is_open, "victory gate open")


func test_shortcut_goal_and_persistence() -> void:
	var p := await _load(OW, &"start")
	var goal := _n(^"Corridor/Goal") as Interactable
	var hub_door := _n(^"Corridor/DoorHub") as SceneDoor
	var door := _n(^"Corridor/Shortcut") as OneWayDoor
	await goal.interact(p)
	assert_false(GameState.has_flag(&"integration.complete"), "goal sealed before the boss")
	assert_false(hub_door.conditions_met())
	# Corridor from the start side: shortcut is locked.
	await _place(p, Vector2(300, 66))
	assert_false(door.is_on_open_side(p))
	GameState.set_flag(BOSS_FLAG, true)
	await wait_physics_frames(3)
	assert_true((_n(^"Arena/GateVictory") as Gate).is_open, "victory gate follows boss flag")
	await _place(p, Vector2(360, 66))
	assert_eq(p.interactor.target, door, "shortcut focused from the arena side")
	await _interact()
	assert_true(door.is_open, "shortcut opened")
	input.move = Vector2.LEFT
	assert_true(await wait_until(func() -> bool: return p.global_position.x < 90.0, 3.0), "walked back to the start through the shortcut")
	input.move = Vector2.ZERO
	await wait_physics_frames(3)
	assert_eq(p.interactor.target, goal, "goal focused")
	await wait_seconds(0.2)
	await _interact()
	assert_true(GameState.has_flag(&"integration.complete"), "integration.complete set")
	assert_true(hub_door.conditions_met(), "hub door unlocked")
	SceneRouter.reload_current_scene(&"start")
	assert_true(await wait_transition())
	assert_true((_n(^"Corridor/Shortcut") as OneWayDoor).is_open, "shortcut persists after re-entry")
	assert_true((_n(^"Arena/GateVictory") as Gate).is_open)
	var boss := get_tree().current_scene.get_node_or_null(^"Arena/Boss") as Boss
	assert_true(boss == null or boss.is_queued_for_deletion() or not boss.is_fight_active(),
		"defeated boss is removed / does not restart")
