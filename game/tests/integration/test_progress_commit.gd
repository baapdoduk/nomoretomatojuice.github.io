extends TestCase
## Milestone commit policy (GameState.commit_progress): progress survives death,
## spawn/HP come from the checkpoint, items+flags move atomically.

const A := "res://tests/fixtures/router_a.tscn"
const B := "res://tests/fixtures/router_b.tscn"

func before_each() -> void:
	GameState.new_game(5)

func _item(id: StringName, type: ItemData.ItemType = ItemData.ItemType.PROGRESSION, stack: int = 1) -> ItemData:
	var it := ItemData.new()
	it.id = id
	it.type = type
	it.max_stack = stack
	return it

func _die_and_respawn() -> void:
	GameState.apply_damage(99)
	SceneRouter.respawn_at_checkpoint()
	await SceneRouter.transition_finished

func test_milestone_survives_death_with_checkpoint_spawn_and_hp() -> void:
	await change_scene_and_wait(A)
	GameState.save_checkpoint(A, &"from_other")   # HP 5 at checkpoint
	GameState.apply_damage(4)                      # defeat boss at 1 HP
	GameState.set_milestone(&"boss.x.defeated")
	await wait_frames(2)
	assert_eq(int(GameState.checkpoint["health"]), 5, "checkpoint HP untouched")
	assert_eq(String(GameState.checkpoint["spawn_id"]), "from_other", "spawn untouched")
	await _die_and_respawn()
	assert_true(GameState.has_flag(&"boss.x.defeated"), "milestone kept")
	assert_eq(GameState.health, 5, "respawn HP from checkpoint, not 1")
	assert_vec_almost_eq(SceneRouter.get_player().global_position, Vector2(300, 50), 0.01)

func test_commit_is_atomic_and_coalesced() -> void:
	await change_scene_and_wait(A)
	GameState.save_checkpoint(A, &"start")
	GameState.add_item(_item(&"key"))
	var count := [0]
	var cb := func(_s: Dictionary) -> void: count[0] += 1
	GameState.progress_committed.connect(cb)
	GameState.commit_progress()
	GameState.remove_item(&"key")                  # use key on door in the same frame
	GameState.set_milestone(&"door.y.open")
	await wait_frames(2)
	GameState.progress_committed.disconnect(cb)
	assert_eq(count[0], 1, "one commit per frame")
	await _die_and_respawn()
	assert_false(GameState.has_item(&"key"), "key spent")
	assert_true(GameState.has_flag(&"door.y.open"), "door open")

func test_no_commit_when_player_died_same_frame() -> void:
	await change_scene_and_wait(A)
	GameState.save_checkpoint(A, &"start")
	GameState.set_milestone(&"boss.z.defeated")
	GameState.apply_damage(99)
	await wait_frames(2)
	assert_false((GameState.checkpoint["flags"] as Dictionary).has("boss.z.defeated"), "nothing committed")

func test_non_milestone_progress_after_commit_still_reverts() -> void:
	await change_scene_and_wait(A)
	GameState.save_checkpoint(A, &"start")
	GameState.set_milestone(&"puzzle.p.solved")
	await wait_frames(2)
	GameState.set_flag(&"device.lever")            # not a milestone
	GameState.add_item(_item(&"coin", ItemData.ItemType.CONSUMABLE, 9))
	await _die_and_respawn()
	assert_true(GameState.has_flag(&"puzzle.p.solved"))
	assert_false(GameState.has_flag(&"device.lever"), "device state reverts")
	assert_eq(GameState.get_item_count(&"coin"), 0, "consumable after commit reverts")

func test_without_checkpoint_commit_lands_in_scene_entry() -> void:
	await change_scene_and_wait(B, &"from_other")
	assert_false(GameState.has_checkpoint())
	GameState.set_milestone(&"shortcut.s.open")
	await wait_frames(2)
	await _die_and_respawn()
	assert_true(GameState.has_flag(&"shortcut.s.open"))
	assert_eq(get_tree().current_scene.name, &"Router_b")

func test_restart_chapter_reverts_commits() -> void:
	await change_scene_and_wait(A)
	GameState.begin_chapter(&"ch", A, &"start")
	GameState.set_milestone(&"boss.c.defeated")
	await wait_frames(2)
	SceneRouter.restart_chapter()
	await SceneRouter.transition_finished
	assert_false(GameState.has_flag(&"boss.c.defeated"), "chapter restart reverts everything")

func test_commit_after_new_game_is_cancelled() -> void:
	await change_scene_and_wait(A)
	GameState.save_checkpoint(A, &"start")
	GameState.set_milestone(&"x")
	GameState.new_game(5)
	await wait_frames(2)
	assert_false(GameState.has_flag(&"x"))
	assert_true(GameState.checkpoint.is_empty(), "pending commit dropped")

func test_resaving_same_checkpoint_keeps_death_counter() -> void:
	await change_scene_and_wait(A)
	GameState.save_checkpoint(A, &"cp")
	GameState.deaths_since_checkpoint = 2
	GameState.save_checkpoint(A, &"cp")
	assert_eq(GameState.deaths_since_checkpoint, 2, "same checkpoint")
	GameState.save_checkpoint(A, &"cp2")
	assert_eq(GameState.deaths_since_checkpoint, 0, "new checkpoint resets")

func test_scene_change_while_dead_refills() -> void:
	await change_scene_and_wait(A)
	GameState.apply_damage(99)
	await change_scene_and_wait(B)
	assert_eq(GameState.health, 5, "never arrive dead")

func test_failed_interaction_keeps_item_and_one_shot() -> void:
	var it := _FailingInteractable.new()
	it.required_item = &"gem"
	it.consume_required_item = true
	it.one_shot = true
	add_test_node(it)
	GameState.add_item(_item(&"gem"))
	await it.interact(self)
	assert_true(GameState.has_item(&"gem"), "not consumed on failure")
	assert_true(it.can_focus(self), "one_shot not spent on failure")
	it.should_fail = false
	await it.interact(self)
	assert_false(GameState.has_item(&"gem"), "consumed on success")
	assert_false(it.can_focus(self), "one_shot spent")

class _FailingInteractable extends Interactable:
	var should_fail := true
	func _perform(_actor: Node) -> void:
		perform_failed = should_fail

func test_coins_revert_on_death_but_milestone_keeps_them() -> void:
	await change_scene_and_wait(A)
	GameState.save_checkpoint(A, &"start")
	GameState.add_coins(5)
	await _die_and_respawn()
	assert_eq(GameState.coins, 0, "coins after checkpoint revert (no farming)")
	GameState.add_coins(3)
	GameState.set_milestone(&"shard.x")
	await wait_frames(2)
	await _die_and_respawn()
	assert_eq(GameState.coins, 3, "coins committed with a milestone")
