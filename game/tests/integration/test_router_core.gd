extends TestCase
## SceneRouter: transitions, spawn placement, pause during transition, respawn snapshot.

const A := "res://tests/fixtures/router_a.tscn"
const B := "res://tests/fixtures/router_b.tscn"

func before_each() -> void:
	GameState.new_game(5)

func test_change_scene_places_player_at_spawn() -> void:
	await change_scene_and_wait(A)
	var p := SceneRouter.get_player()
	assert_not_null(p)
	assert_vec_almost_eq(p.global_position, Vector2(10, 10), 0.01, "default spawn")
	await change_scene_and_wait(B, &"from_other")
	p = SceneRouter.get_player()
	assert_eq(get_tree().current_scene.name, &"Router_b")
	assert_vec_almost_eq(p.global_position, Vector2(300, 50), 0.01, "named spawn")
	assert_eq(p.get(&"spawned_at"), &"from_other")
	assert_false(get_tree().paused, "unpaused after transition")
	assert_false(SceneRouter.is_transitioning)

func test_tree_paused_and_reentry_ignored_during_transition() -> void:
	SceneRouter.change_scene(A, &"", 0.1)
	await get_tree().process_frame
	assert_true(SceneRouter.is_transitioning)
	assert_true(get_tree().paused, "paused while fading")
	SceneRouter.change_scene(B)  # must be ignored
	await SceneRouter.transition_finished
	assert_eq(get_tree().current_scene.name, &"Router_a", "second request ignored")

func test_respawn_restores_checkpoint_snapshot() -> void:
	await change_scene_and_wait(A)
	var key := ItemData.new()
	key.id = &"k"
	GameState.add_item(key)
	GameState.save_checkpoint(A, &"from_other")
	GameState.set_flag(&"after.cp")
	GameState.apply_damage(5)
	SceneRouter.respawn_at_checkpoint()
	await SceneRouter.transition_finished
	assert_eq(GameState.health, 5)
	assert_true(GameState.has_item(&"k"))
	assert_false(GameState.has_flag(&"after.cp"))
	assert_vec_almost_eq(SceneRouter.get_player().global_position, Vector2(300, 50), 0.01)
	assert_eq(GameState.death_count, 1)

func test_respawn_without_checkpoint_uses_scene_entry() -> void:
	await change_scene_and_wait(B, &"from_other")
	GameState.set_flag(&"x")
	GameState.apply_damage(5)
	SceneRouter.respawn_at_checkpoint()
	await SceneRouter.transition_finished
	assert_false(GameState.has_flag(&"x"), "scene-entry snapshot restored")
	assert_eq(GameState.health, 5)
	assert_eq(get_tree().current_scene.name, &"Router_b")

func test_iris_transition_covers_then_clears() -> void:
	await change_scene_and_wait(A)
	SceneRouter.change_scene(B, &"from_other", 0.2, SceneRouter.STYLE_IRIS)
	var peak := [0.0]
	while SceneRouter.is_transitioning:
		peak[0] = maxf(peak[0], SceneRouter.get_transition_progress())
		await get_tree().process_frame
	assert_almost_eq(peak[0], 1.0, 0.001, "fully covered mid-transition")
	assert_almost_eq(SceneRouter.get_transition_progress(), 0.0, 0.001, "cleared after")
	assert_eq(get_tree().current_scene.name, &"Router_b")
