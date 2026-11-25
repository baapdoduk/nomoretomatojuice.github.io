extends LevelKitTestCase
## CatnapCushion, MemoryDoor, SecretArea, StickyPuddle, DripEmitter.


func test_catnap_cushion_saves_checkpoint_and_wakes() -> void:
	var player := await make_side_player_on_floor(0.0)
	var cushion := kit("catnap_cushion", Vector2(60, 0), func(n: Node) -> void:
		n.checkpoint_id = &"kit_cp") as CatnapCushion
	assert_false(cushion.is_cat_awake(), "asleep at start")
	capture_toasts()
	await wait_physics_frames(2)
	player.global_position = Vector2(66, -1)  # not on the spawn point (that waits for an exit)
	await wait_physics_frames(3)
	assert_true(GameState.has_checkpoint(), "checkpoint saved")
	assert_eq(String(GameState.checkpoint.get("spawn_id", "")), "cp_kit_cp", "spawn id")
	assert_true(cushion.is_cat_awake(), "cat awake")
	assert_true(toasts.has("Catnap Cushion"), "toast")
	await wait_seconds(cushion.wake_time + 0.1)
	assert_almost_eq(cushion.awake_amount, 1.0, 0.01, "wake animation done")


func test_memory_door_sets_clear_milestone_and_returns_to_hub() -> void:
	var info := LevelInfo.new()
	info.level_id = &"kit_door"
	add_test_node(info)
	var player := await make_side_player_on_floor(0.0)
	var door := kit("memory_door", Vector2(80, 0), func(n: Node) -> void:
		n.celebration_time = 0.1) as MemoryDoor
	var targets: Array[String] = []
	var on_start := func(path: String, _spawn: StringName) -> void: targets.append(path)
	SceneRouter.transition_started.connect(on_start)
	await wait_physics_frames(2)
	player.global_position = Vector2(80, -1)
	await wait_physics_frames(3)
	assert_true(door.is_triggered, "triggered")
	assert_true(player.has_input_lock(MemoryDoor.LOCK_REASON), "input locked")
	assert_true(GameState.has_flag(&"level.kit_door.clear"), "clear milestone")
	assert_true(await wait_until(func() -> bool: return not targets.is_empty(), 2.0), "scene change started")
	SceneRouter.transition_started.disconnect(on_start)
	assert_eq(targets[0], String(ProjectSettings.get_setting("application/run/main_scene")), "to hub")
	await wait_transition()
	await unload_current_scene()


func test_secret_area_fades_while_inside() -> void:
	var area := kit("secret_area", Vector2(0, -64), func(n: Node) -> void:
		n.size = Vector2(64, 64)) as SecretArea
	var visual := area.get_node("Visual") as CanvasItem
	await wait_physics_frames(2)
	var body := make_stand_in(Vector2(32, 0))
	await wait_seconds(0.4)
	assert_true(area.is_player_inside(), "inside")
	assert_almost_eq(area.cover_alpha, area.inside_alpha, 0.01, "faded")
	assert_almost_eq(visual.modulate.a, area.inside_alpha, 0.01, "visual faded")
	body.position = Vector2(300, 0)
	await wait_seconds(0.4)
	assert_false(area.is_player_inside(), "left")
	assert_almost_eq(area.cover_alpha, 1.0, 0.01, "opaque again")


func test_sticky_puddle_calls_modifier_api() -> void:
	var puddle := kit("sticky_puddle", Vector2(0, 0)) as StickyPuddle
	await wait_physics_frames(2)
	var body := make_stand_in(Vector2(0, 0))
	await wait_physics_frames(3)
	assert_eq(body.modifiers.get(puddle), [0.55, 0.75, 0.6], "modifier applied")
	puddle.active = false
	assert_false(body.modifiers.has(puddle), "cleared when inactive")
	puddle.active = true
	assert_true(body.modifiers.has(puddle), "re-applied when active")
	body.position = Vector2(200, 0)
	await wait_physics_frames(3)
	assert_false(body.modifiers.has(puddle), "cleared on exit")
	assert_eq(body.calls.back()[0], "clear")
	# Bodies without the API are ignored (no error).
	var plain := StaticBody2D.new()
	plain.collision_layer = Layers.PLAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	shape.shape = rect
	plain.add_child(shape)
	add_test_node(plain)
	await wait_physics_frames(3)
	assert_eq(puddle.get_bodies().size(), 0, "plain body ignored")


func test_drip_emitter_toggles_puddles_on_period() -> void:
	var puddle := kit("sticky_puddle") as StickyPuddle
	var drip := kit("drip_emitter", Vector2(0, -60), func(n: Node) -> void:
		n.on_time = 1.0
		n.off_time = 1.0
		n.telegraph_time = 0.4
		n.running = false
		n.puddles = [puddle] as Array[StickyPuddle]) as DripEmitter
	var toggles: Array[bool] = []
	drip.toggled.connect(func(on: bool) -> void: toggles.append(on))
	var tele := [0]
	drip.telegraph_started.connect(func() -> void: tele[0] += 1)
	drip.running = true
	assert_true(drip.is_on and puddle.active, "starts on")
	drip._physics_process(1.1)
	assert_false(puddle.active, "off after on_time")
	drip._physics_process(0.6)  # t = 1.7 -> telegraph window (1.6 .. 2.0)
	assert_eq(tele[0], 1, "telegraph before the puddle returns")
	assert_true(drip.get_telegraph_progress() > 0.0)
	drip._physics_process(0.4)  # t = 2.1
	assert_true(puddle.active, "on again")
	assert_eq(toggles, [false, true] as Array[bool], "toggle sequence")
	assert_almost_eq(drip.get_drip_distance(), 60.0, 0.01, "drip falls to the puddle")
