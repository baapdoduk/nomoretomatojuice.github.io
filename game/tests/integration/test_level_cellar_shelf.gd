extends PlayerTestCase
## The Cellar Shelf (scenes/levels/cellar_shelf.tscn): structure + scripted
## traversal of the critical path. Tests teleport between beat markers
## (SideViewLevel.get_beat_position) but every key obstacle is crossed by
## simulated input (PlayerInputState override): the intro pit by a jump, the
## first dash gap and a finale gap by jump + air-dash, the drip step by a jump
## once the puddle is dry. Shard 1 (skill) is checked both ways: a plain running
## jump from its clean tile must miss, jump + air-dash must collect it.

const LEVEL := "res://scenes/levels/cellar_shelf.tscn"
const TILE := 16.0

var level: SideViewLevel
var player: Player


func before_each() -> void:
	super.before_each()
	disable_feel_settings()
	await change_scene_and_wait(LEVEL, &"start")
	level = get_tree().current_scene as SideViewLevel
	player = get_tree().get_first_node_in_group(Layers.GROUP_PLAYER) as Player
	player.set_input_override(input)
	await wait_physics_frames(2)


func after_each() -> void:
	super.after_each()
	await unload_current_scene()
	restore_feel_settings()


# ------------------------------------------------------------------ helpers

## Teleports the player's feet to `feet` (like a respawn) and waits for the floor.
## Parks the player outside every area first, so puddles see a fresh entry.
func place(feet: Vector2) -> void:
	input.move = Vector2.ZERO
	release_jump()
	player.global_position = Vector2(feet.x, -2000.0)
	await wait_physics_frames(2)
	player.global_position = feet
	player.on_spawned(null)
	await wait_physics_frames(2)
	await wait_until(func() -> bool: return player.is_on_floor(), 1.0)


func place_at_beat(id: StringName) -> void:
	var pos := level.get_beat_position(id)
	assert_ne(pos, Vector2.INF, "beat marker " + id)
	await place(pos)


func remove_corks() -> void:
	for c in level.get_node(^"Enemies").get_children():
		c.queue_free()
	await wait_physics_frames(1)


## Runs right; jumps (full hold) once x >= jump_x; optionally air-dashes at the
## apex. Ends on landing or when `stop` returns true. Returns the frame count.
func run_and_jump(jump_x: float, dash: bool, stop: Callable = Callable()) -> int:
	input.move = Vector2.RIGHT
	var jumped := false
	var dashed := false
	var jump_frame := 0
	var frames := 0
	while frames < 600:
		await wait_physics_frames(1)
		frames += 1
		input.jump_pressed = false
		input.dash_pressed = false
		if not jumped and player.global_position.x >= jump_x:
			press_jump()
			jumped = true
			jump_frame = frames
		elif jumped and dash and not dashed and frames - jump_frame > 2 and player.velocity.y >= 0.0:
			press_dash()
			dashed = true
		if jumped and frames - jump_frame > 3 and player.is_on_floor():
			break
		if stop.is_valid() and stop.call():
			break
	input.move = Vector2.ZERO
	release_jump()
	await wait_physics_frames(1)
	return frames


func shard_flag(index: int) -> StringName:
	return StringName("shard.cellar_shelf.%d" % index)


# ------------------------------------------------------------------ structure

func test_level_loads_with_info_hud_shards_and_door() -> void:
	assert_not_null(level, "SideViewLevel root")
	var info := LevelInfo.find_in(get_tree())
	assert_not_null(info, "LevelInfo")
	assert_eq(String(info.level_id), "cellar_shelf", "level id")
	assert_eq(info.shard_count, 3, "3 shards")
	assert_not_null(level.get_node_or_null(^"HUD"), "HUD")
	var shards: Array[int] = []
	var doors := 0
	var stack: Array[Node] = [level]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MemoryShard:
			shards.append((n as MemoryShard).index)
		elif n is MemoryDoor:
			doors += 1
	shards.sort()
	assert_eq(shards, [0, 1, 2] as Array[int], "shard indices")
	assert_eq(doors, 1, "one Memory Door")
	assert_eq(player.movement_mode, Player.MovementMode.SIDE_VIEW, "side view")
	var world := level.get_node(^"World") as TileMapLayer
	assert_true(world.get_used_cells().size() > 1000, "painted terrain saved in the scene")
	assert_true(level.get_beat_ids().size() >= 10, "beat markers")


# ------------------------------------------------------------------ introduce

func test_intro_sticky_puddle_slows_and_arc_jump_collects_shard_0() -> void:
	var puddle := level.get_node(^"Puddles/IntroPuddle") as StickyPuddle
	# clean run speed
	await place(Vector2(40, -1))
	input.move = Vector2.RIGHT
	await wait_physics_frames(25)
	var clean_speed := player.velocity.x
	input.move = Vector2.ZERO
	# speed inside the puddle
	await place(Vector2(puddle.global_position.x - puddle.width * 0.5 + 8.0, -1))
	input.move = Vector2.RIGHT
	await wait_physics_frames(25)
	var sticky_speed := player.velocity.x
	assert_true(player.has_surface_modifier(puddle), "puddle applies the modifier")
	input.move = Vector2.ZERO
	assert_true(clean_speed > 170.0, "clean run ~180 px/s (%.0f)" % clean_speed)
	assert_true(sticky_speed < clean_speed * 0.65, "puddle slows the run (%.0f vs %.0f)" % [sticky_speed, clean_speed])
	# the taught arc: jump from inside the puddle where the Fizz arc starts
	await place(Vector2(176, -1))
	var arc := level.get_node(^"Pickups/FizzIntroArc") as Node2D
	await run_and_jump(arc.global_position.x - 4.0, false)
	assert_true(GameState.has_flag(shard_flag(0)), "shard 0 at the apex of the sticky arc")


func test_intro_pit_crossed_by_jump() -> void:
	await place_at_beat(&"intro_pit")
	await run_and_jump(30 * TILE - 6.0, false)
	assert_false(player.is_dead(), "alive")
	assert_true(player.is_on_floor(), "landed")
	assert_true(player.global_position.x > 32 * TILE, "across the 2-tile pit (x %.0f)" % player.global_position.x)
	assert_almost_eq(player.global_position.y, 0.0, 1.5, "on the floor")


# ------------------------------------------------------------------ develop

func test_first_dash_gap_needs_jump_plus_dash_from_the_puddle() -> void:
	await remove_corks()
	var edge := 98 * TILE
	var take_off_y := -1 * TILE
	# plain sticky jump: falls short (stop before the kill zone)
	await place_at_beat(&"dash_gap")
	assert_true(player.get_surface_jump_multiplier() < 1.0, "take-off is sticky")
	await run_and_jump(edge - 4.0, false, func() -> bool:
		return player.global_position.x > edge and player.global_position.y > take_off_y + 4.0)
	assert_true(player.global_position.y > take_off_y, "plain jump falls into the gap")
	# jump + air-dash: lands on the far shelf (2 tiles higher)
	await place_at_beat(&"dash_gap")
	await run_and_jump(edge - 4.0, true)
	assert_true(player.is_on_floor(), "landed")
	assert_true(player.global_position.x >= 104 * TILE, "across the 6-tile gap (x %.0f)" % player.global_position.x)
	assert_almost_eq(player.global_position.y, -3 * TILE, 1.5, "on the landing shelf")


func test_shard_1_needs_jump_plus_air_dash_from_the_clean_tile() -> void:
	var clean_tile_right := 125 * TILE
	var shelf_top := -7 * TILE
	# plain running jump at full speed from the clean tile: misses
	await place_at_beat(&"shard_shelf")
	assert_false(player.has_surface_modifier(level.get_node(^"Puddles/SkillPuddleA")), "clean tile")
	player.global_position.x = clean_tile_right - 6.0
	player.velocity.x = 180.0
	var best := {"min_y": 0.0}
	await run_and_jump(0.0, false, func() -> bool:
		best.min_y = minf(best.min_y, player.global_position.y)
		return false)
	assert_false(GameState.has_flag(shard_flag(1)), "plain running jump does not reach shard 1")
	assert_true(player.global_position.y > shelf_top + 8.0, "did not land on the shelf (y %.0f)" % player.global_position.y)
	# walk out of the puddle onto the clean tile, jump + air-dash: collects it
	await place(Vector2(1952, -49))
	await run_and_jump(clean_tile_right - 8.0, true)
	assert_true(GameState.has_flag(shard_flag(1)), "jump + air-dash reaches shard 1")


# ------------------------------------------------------------------ breather

func test_checkpoint_mid_level_respawns_there() -> void:
	var cushion := level.get_node(^"Cushion") as CatnapCushion
	var cushion_x := cushion.global_position.x
	var bounds := get_tree().get_first_node_in_group(&"camera_bounds") as CameraBounds
	var frac := cushion.global_position.x / bounds.get_global_rect().size.x
	assert_true(frac > 0.4 and frac < 0.6, "checkpoint at ~50 %% (%.2f)" % frac)
	await place_at_beat(&"breather")
	input.move = Vector2.RIGHT
	await wait_until(func() -> bool: return GameState.has_checkpoint(), 3.0)
	input.move = Vector2.ZERO
	assert_eq(String(GameState.checkpoint.get("spawn_id", "")), "cp_cellar_mid", "checkpoint saved")
	player.kill()
	var respawned := await wait_until(func() -> bool:
		var p := get_tree().get_first_node_in_group(Layers.GROUP_PLAYER) as Player
		return p != null and p != player and not SceneRouter.is_transitioning, 6.0)
	assert_true(respawned, "respawned")
	var p2 := get_tree().get_first_node_in_group(Layers.GROUP_PLAYER) as Player
	if p2:
		assert_almost_eq(p2.global_position.x, cushion_x, 24.0, "at the cushion")


# ------------------------------------------------------------------ twist

func test_drip_emitter_toggles_and_gates_the_step() -> void:
	var drip := level.get_node(^"Drips/Drip1") as DripEmitter
	var puddle := level.get_node(^"Puddles/DripPuddle1") as StickyPuddle
	var states: Array[bool] = []
	drip.toggled.connect(func(on: bool) -> void: states.append(on))
	await wait_seconds(drip.get_cycle() + 0.2)
	assert_true(states.has(true) and states.has(false), "toggles on and off on its rhythm")
	assert_eq(puddle.active, drip.is_on, "puddle follows the drip")
	# wet: the 3-tile step is out of reach; dry: one jump
	var step_x := 184 * TILE
	drip.running = false
	for wet: bool in [true, false]:
		drip.is_on = wet
		drip._apply_state()
		await place(Vector2(step_x - 60.0, -1))
		await run_and_jump(step_x - 40.0, false, func() -> bool: return player.global_position.x > step_x + 24.0)
		await wait_until(func() -> bool: return player.is_on_floor(), 1.5)
		var on_step := player.global_position.y < -2.5 * TILE
		if wet:
			assert_false(on_step, "wet puddle: cannot climb the step")
		else:
			assert_true(on_step, "dry: climbs the step (y %.0f)" % player.global_position.y)
	# wet, but jump + air-dash at full speed from the last dry tile: still short
	drip.is_on = true
	drip._apply_state()
	await place(Vector2(puddle.global_position.x - puddle.width * 0.5 - 40.0, -1))
	player.velocity.x = 180.0
	await run_and_jump(puddle.global_position.x - puddle.width * 0.5 - 2.0, true,
		func() -> bool: return player.global_position.x > step_x + 24.0)
	await wait_until(func() -> bool: return player.is_on_floor(), 1.5)
	assert_false(player.global_position.y < -2.5 * TILE, "jump + dash cannot skip the wet puddle")


## Full-hold jump steering toward target_x; returns once landed.
func hop_to(target_x: float) -> void:
	press_jump()
	var frames := 0
	while frames < 180:
		await wait_physics_frames(1)
		frames += 1
		input.jump_pressed = false
		var dx := target_x - player.global_position.x
		input.move = Vector2(signf(dx) if absf(dx) > 3.0 else 0.0, 0)
		if frames > 3 and player.is_on_floor():
			break
	input.move = Vector2.ZERO
	release_jump()
	await wait_physics_frames(4)


func test_one_way_shelf_climb_with_platform_snap_camera() -> void:
	await place_at_beat(&"climb")
	var cam := player.camera as Camera2D
	var cam_y0 := cam.global_position.y
	var left := 202 * TILE + 8.0
	var right := 207 * TILE + 8.0
	var rows := [-9, -12, -15, -18, -21]
	for i in rows.size():
		await hop_to(right if i % 2 == 0 else left)
		assert_almost_eq(player.global_position.y, rows[i] * TILE, 1.5, "on shelf row %d" % rows[i])
	await hop_to(217 * TILE)
	assert_almost_eq(player.global_position.y, -24 * TILE, 1.5, "top corridor reached")
	await wait_seconds(0.6)
	assert_true(cam.global_position.y < cam_y0 - 12 * TILE, "camera climbed with the player (%.0f -> %.0f)" % [cam_y0, cam.global_position.y])


func test_secret_pocket_via_drop_through_shelf_holds_shard_2() -> void:
	var shelf := level.get_node(^"SecretDrop") as CellarShelf
	var secret := level.get_node(^"SecretArea") as SecretArea
	await place(shelf.global_position + Vector2(0, -1))
	assert_almost_eq(player.global_position.y, shelf.global_position.y, 1.5, "standing on the shelf")
	input.move = Vector2(0, 1)
	press_jump()
	await wait_physics_frames(2)
	input.jump_pressed = false
	release_jump()
	input.move = Vector2.ZERO
	await wait_physics_frames(10)
	await wait_until(func() -> bool: return player.is_on_floor(), 1.5)
	assert_almost_eq(player.global_position.y, -21 * TILE, 1.5, "dropped into the pocket")
	assert_true(secret.is_player_inside(), "secret revealed")
	input.move = Vector2.RIGHT
	await wait_until(func() -> bool: return GameState.has_flag(shard_flag(2)), 2.0)
	input.move = Vector2.ZERO
	assert_true(GameState.has_flag(shard_flag(2)), "shard 2 collected")
	# way out: jump back up through the one-way shelf
	await place(Vector2(shelf.global_position.x, -21 * TILE - 1.0))
	press_jump()
	await wait_physics_frames(2)
	input.jump_pressed = false
	await wait_physics_frames(30)
	release_jump()
	await wait_until(func() -> bool: return player.is_on_floor(), 1.5)
	assert_almost_eq(player.global_position.y, shelf.global_position.y, 1.5, "back on the shelf")


# ------------------------------------------------------------------ finale + goal

func test_finale_gap_crossed_by_jump_plus_dash() -> void:
	await remove_corks()
	await place_at_beat(&"finale_gap2")
	var hp := player.health.current
	await run_and_jump(287 * TILE - 4.0, true)
	assert_true(player.is_on_floor(), "landed")
	assert_true(player.global_position.x >= 298 * TILE, "across the 11-tile spike gap (x %.0f)" % player.global_position.x)
	assert_almost_eq(player.global_position.y, 0.0, 1.5, "on the platform")
	assert_eq(player.health.current, hp, "no spike damage")


func test_finale_drip_gap_is_timed() -> void:
	await remove_corks()
	var drip := level.get_node(^"Drips/Drip3") as DripEmitter
	drip.running = false
	var edge := 265 * TILE
	for wet: bool in [true, false]:
		drip.is_on = wet
		drip._apply_state()
		await place(Vector2(edge - 7 * TILE, -1))
		await run_and_jump(edge - 4.0, true, func() -> bool:
			return player.global_position.x > edge and player.global_position.y > 4.0)
		var across := player.is_on_floor() and player.global_position.x >= 277 * TILE
		if wet:
			assert_false(across, "wet take-off: jump + dash falls short of the 12-tile gap")
		else:
			assert_true(across, "dry take-off: jump + dash crosses (x %.0f)" % player.global_position.x)


func test_memory_door_clears_level_and_returns_to_hub() -> void:
	var targets: Array[String] = []
	var on_start := func(path: String, _spawn: StringName) -> void: targets.append(path)
	SceneRouter.transition_started.connect(on_start)
	await place_at_beat(&"runway")
	input.move = Vector2.RIGHT
	var cleared := await wait_until(func() -> bool: return GameState.has_flag(&"level.cellar_shelf.clear"), 5.0)
	input.move = Vector2.ZERO
	assert_true(cleared, "level.cellar_shelf.clear set")
	assert_true(await wait_until(func() -> bool: return not targets.is_empty(), 4.0), "scene change started")
	SceneRouter.transition_started.disconnect(on_start)
	if not targets.is_empty():
		assert_eq(targets[0], String(ProjectSettings.get_setting("application/run/main_scene")), "back to the hub")
	await wait_transition()
