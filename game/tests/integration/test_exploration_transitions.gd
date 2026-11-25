extends PlayerTestCase
## Lab-level flows: door transitions side <-> top-down (items/flags persist,
## correct spawn + motor), checkpoint -> death -> respawn snapshot restore,
## pickup hidden after a scene reload.

const SIDE := "res://scenes/tests/side_view_lab.tscn"
const TOP := "res://scenes/tests/top_down_lab.tscn"


func after_each() -> void:
	super.after_each()
	await unload_current_scene()


func _player() -> Player:
	return SceneRouter.get_player() as Player


func _scene_node(path: NodePath) -> Node:
	return get_tree().current_scene.get_node(path)


func test_door_transition_keeps_items_and_flags() -> void:
	await change_scene_and_wait(SIDE, &"start")
	var p := _player()
	assert_not_null(p, "player in side lab")
	assert_eq(p.movement_mode, Player.MovementMode.SIDE_VIEW)
	assert_vec_almost_eq(p.global_position, (_scene_node(^"Spawns/Start") as Node2D).global_position, 0.5, "at start spawn")
	GameState.add_item(load("res://resources/items/lab_key.tres"))
	GameState.set_flag(&"lab.test.flag", 3)
	var door: SceneDoor = _scene_node(^"Interactables/DoorTopDown")
	await door.interact(p)
	assert_true(await wait_transition(), "transition finished")
	assert_eq(SceneRouter.get_current_scene_path(), TOP, "now in top-down lab")
	p = _player()
	assert_eq(p.movement_mode, Player.MovementMode.TOP_DOWN, "top-down motor active")
	assert_true(p.get_motor() is TopDownMotor)
	var spawn := _scene_node(^"Spawns/FromSideViewLab") as SpawnPoint
	assert_eq(spawn.spawn_id, &"from_side_view_lab")
	assert_vec_almost_eq(p.global_position, spawn.global_position, 0.5, "placed on from_side_view_lab")
	assert_true(GameState.has_item(&"lab_key"), "item kept")
	assert_eq(GameState.get_flag(&"lab.test.flag"), 3, "flag kept")
	# Collect something here and go back.
	GameState.set_flag(&"lab.top.shortcut.open", true)
	var back: SceneDoor = _scene_node(^"Interactables/DoorSideView")
	await back.interact(p)
	assert_true(await wait_transition())
	assert_eq(SceneRouter.get_current_scene_path(), SIDE)
	p = _player()
	var side_spawn := _scene_node(^"Spawns/FromTopDownLab") as Node2D
	assert_vec_almost_eq(p.global_position, side_spawn.global_position, 0.5, "placed on from_top_down_lab")
	assert_eq(p.get_facing(), Vector2.LEFT, "spawn facing applied")
	assert_true(GameState.has_item(&"lab_key"))
	assert_true(GameState.has_flag(&"lab.top.shortcut.open"), "top-down flag kept")
	# The key pickup in the side lab is hidden because the key is owned.
	var key_pickup: Pickup = _scene_node(^"Interactables/Key")
	assert_true(key_pickup.is_collected and not key_pickup.visible, "owned key pickup hidden")


func test_checkpoint_death_respawn_restores_snapshot() -> void:
	await change_scene_and_wait(SIDE, &"start")
	var p := _player()
	var key: ItemData = load("res://resources/items/lab_key.tres")
	GameState.add_item(key)  # before the checkpoint: must survive
	var cp: Checkpoint = _scene_node(^"Interactables/CheckpointStart")
	p.global_position = cp.global_position + Vector2(0, -1)
	assert_true(await wait_until(func() -> bool: return cp.is_active_checkpoint, 1.0), "checkpoint touched")
	assert_eq(String(GameState.checkpoint.get("spawn_id")), "cp_side_start")
	assert_eq(String(GameState.checkpoint.get("scene_path")), SIDE)
	# Progress after the checkpoint (must be rolled back).
	GameState.add_item(load("res://resources/items/lab_memory_photo.tres"))
	GameState.set_flag(&"lab.test.after_cp", true)
	GameState.apply_damage(2)
	assert_eq(GameState.health, 3)
	var died := [0]
	p.died.connect(func() -> void: died[0] += 1)
	# Fall into the coyote pit's KillZone.
	p.global_position = Vector2(540, 30)
	assert_true(await wait_until(func() -> bool: return p.is_dead(), 2.0), "killed by kill zone")
	assert_eq(died[0], 1)
	assert_true(p.is_input_locked(), "input locked while dead")
	assert_true(await wait_until(func() -> bool: return SceneRouter.is_transitioning, 3.0), "respawn after delay")
	assert_true(await wait_transition(), "respawn finished")
	var np := _player()
	assert_ne(np, p, "new player instance")
	var cp_spawn := (_scene_node(^"Interactables/CheckpointStart") as Checkpoint).spawn_point
	assert_vec_almost_eq(np.global_position, cp_spawn.global_position, 0.5, "respawned at checkpoint spawn")
	assert_eq(GameState.health, GameState.max_health, "health restored")
	assert_true(GameState.has_item(&"lab_key"), "pre-checkpoint item kept")
	assert_false(GameState.has_item(&"lab_memory_photo"), "post-checkpoint item rolled back")
	assert_false(GameState.has_flag(&"lab.test.after_cp"), "post-checkpoint flag rolled back")
	var photo: Pickup = _scene_node(^"Interactables/MemoryPhoto")
	assert_false(photo.is_collected, "rolled-back pickup is back in the world")
	assert_false(np.is_dead())
	assert_false(np.is_input_locked(), "control restored")


func test_pickup_hidden_after_scene_reload() -> void:
	await change_scene_and_wait(SIDE, &"start")
	var photo: Pickup = _scene_node(^"Interactables/MemoryPhoto")
	assert_false(photo.is_collected)
	var p := _player()
	p.global_position = photo.global_position + Vector2(0, 10)
	assert_true(await wait_until(func() -> bool: return photo.is_collected, 1.0), "collected by touch")
	var popup := find_popup(get_tree().current_scene)
	assert_not_null(popup, "memory popup shown")
	if popup:
		popup.close()
	assert_eq(GameState.get_item_count(&"lab_memory_photo"), 1)
	SceneRouter.reload_current_scene(&"start")
	assert_true(await wait_transition())
	var again: Pickup = _scene_node(^"Interactables/MemoryPhoto")
	assert_true(again.is_collected and not again.visible, "hidden after reload")
	assert_eq(GameState.get_item_count(&"lab_memory_photo"), 1, "no duplicate")


func test_scene_exit_touch_trigger() -> void:
	var exit: SceneExit = instantiate_scene("res://scenes/core/interaction/scene_exit.tscn")
	exit.position = Vector2(40, 0)
	exit.target_scene = TOP
	exit.target_spawn_id = &"from_side_view_lab"
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	await wait_physics_frames(3)
	assert_false(exit.can_focus(p), "exits are never focused")
	input.move = Vector2.RIGHT
	assert_true(await wait_until(func() -> bool: return SceneRouter.is_transitioning, 2.0), "touch starts transition")
	# The test-owned player is not part of the scene; remove it so the router
	# places the lab's own player (only one player exists in real levels).
	p.remove_from_group(Layers.GROUP_PLAYER)
	p.queue_free()
	assert_true(await wait_transition())
	assert_eq(SceneRouter.get_current_scene_path(), TOP)
	var np := _player()
	assert_vec_almost_eq(np.global_position, (_scene_node(^"Spawns/FromSideViewLab") as Node2D).global_position, 0.5)


func test_top_down_lab_camera_bounds_and_landmark_visible() -> void:
	await change_scene_and_wait(TOP, &"start")
	var p := _player()
	await wait_frames(5)
	var cam := p.camera
	assert_true(cam.enabled, "player camera enabled")
	assert_eq(cam.limit_left, 0)
	assert_eq(cam.limit_right, 960, "limits copied from CameraBounds")
	assert_eq(cam.limit_bottom, 540)
	var view := Rect2(cam.get_screen_center_position() - Vector2(320, 180), Vector2(640, 360))
	var landmark := _scene_node(^"Landmark") as Node2D
	assert_true(view.has_point(landmark.global_position + Vector2(0, -40)), "landmark visible from the start (%s)" % str(view))
	var door := _scene_node(^"Interactables/ShortcutDoor") as OneWayDoor
	assert_false(door.is_open, "shortcut closed initially")
	assert_true(door.is_on_open_side(_scene_node(^"Interactables/MemoryGarden") as Node2D), "opens from the shrine side")
	assert_false(door.is_on_open_side(p), "locked from the start side")
