extends PlayerTestCase
## Review fixes: dead player guards, pause-safe context actions, perform_failed,
## checkpoint spawn overlap, full-stack pickups, derived flags, 8-way top-down.


func _dead_player(pos: Vector2) -> Player:
	var cfg: PlayerConfig = load("res://resources/player/default_player_config.tres").duplicate()
	cfg.death_respawn_delay = 100.0  # no respawn during the test
	var p := make_player(Player.MovementMode.TOP_DOWN, pos, cfg)
	await wait_physics_frames(2)
	return p


func test_lethal_hit_zeroes_velocity_without_knockback() -> void:
	var p := await _dead_player(Vector2.ZERO)
	GameState.apply_damage(4)
	p.velocity = Vector2(100, 0)
	var src := Node2D.new()
	src.position = Vector2(30, 0)
	add_test_node(src)
	assert_true(p.hurtbox.receive_hit(DamageEvent.create(1, src)), "lethal hit accepted")
	assert_true(p.is_dead(), "dead")
	assert_eq(p.velocity, Vector2.ZERO, "velocity zeroed")
	assert_false(p.is_stunned(), "no knockback stun on death")
	await wait_physics_frames(5)
	assert_almost_eq(p.global_position.length(), 0.0, 0.5, "corpse does not slide")


func test_dead_player_ignored_by_pickup_and_exit() -> void:
	var p := await _dead_player(Vector2(500, 0))
	GameState.set_flag(&"dummy", true)
	p.kill()
	assert_true(p.is_dead())
	var item := ItemData.new()
	item.id = &"fix_key"
	item.type = ItemData.ItemType.PROGRESSION
	var pk: Pickup = instantiate_scene("res://scenes/core/interaction/pickup.tscn")
	pk.item = item
	pk.global_position = Vector2(500, -10)
	var exit: SceneExit = instantiate_scene("res://scenes/core/interaction/scene_exit.tscn")
	exit.global_position = Vector2(500, 0)
	exit.target_scene = "res://scenes/tests/top_down_lab.tscn"
	await wait_physics_frames(6)
	assert_false(pk.is_collected, "dead player can't collect")
	assert_false(GameState.has_item(&"fix_key"))
	assert_false(SceneRouter.is_transitioning, "dead player can't use an exit")


func test_context_action_ignores_input_while_paused() -> void:
	var c: ContextActionInteractable = instantiate_scene("res://scenes/core/interaction/context_action.tscn")
	c.action_type = ContextActionInteractable.ActionType.HOLD
	c.hold_time = 0.4
	c.time_limit = 0.8
	c.interact(self)
	await wait_physics_frames(2)
	get_tree().paused = true
	Input.action_press(&"interact")
	await wait_seconds(1.0)
	await tap_action(&"dash")
	assert_true(c.is_running, "pause menu input neither cancels nor times out")
	assert_almost_eq(c.progress, 0.0, 0.001, "no progress while paused")
	get_tree().paused = false
	await wait_seconds(0.55)
	Input.action_release(&"interact")
	assert_true(c.is_completed, "completes after resuming")


func test_cancelled_context_action_keeps_required_item() -> void:
	var gem := ItemData.new()
	gem.id = &"fix_gem"
	GameState.add_item(gem)
	var c: ContextActionInteractable = instantiate_scene("res://scenes/core/interaction/context_action.tscn")
	c.action_type = ContextActionInteractable.ActionType.HOLD
	c.hold_time = 0.3
	c.required_item = &"fix_gem"
	c.consume_required_item = true
	c.one_shot = true
	c.interact(self)
	await wait_physics_frames(2)
	c.cancel()
	await wait_physics_frames(2)
	assert_true(GameState.has_item(&"fix_gem"), "cancel: item not consumed")
	assert_true(c.can_focus(self), "cancel: one_shot not spent")
	c.interact(self)
	await wait_physics_frames(2)
	Input.action_press(&"interact")
	await wait_seconds(0.4)
	Input.action_release(&"interact")
	await wait_physics_frames(2)
	assert_true(c.is_completed)
	assert_false(GameState.has_item(&"fix_gem"), "success: item consumed")


func test_checkpoint_ignores_spawn_overlap_until_left() -> void:
	var cp: Checkpoint = instantiate_scene("res://scenes/core/interaction/checkpoint.tscn")
	cp.checkpoint_id = &"fix"
	cp.global_position = Vector2(100, 0)
	await wait_physics_frames(1)
	var saves := [0]
	GameState.checkpoint_saved.connect(func(_s: Dictionary) -> void: saves[0] += 1)
	var p := make_player(Player.MovementMode.TOP_DOWN, cp.spawn_point.global_position)
	await wait_physics_frames(5)
	assert_eq(saves[0], 0, "respawning on the checkpoint does not re-save")
	input.move = Vector2.RIGHT
	await wait_physics_frames(25)
	assert_true(p.global_position.x > 130.0, "left the trigger (x=%.1f)" % p.global_position.x)
	input.move = Vector2.LEFT
	assert_true(await wait_until(func() -> bool: return p.global_position.x < 102.0, 2.0), "walked back in")
	input.move = Vector2.ZERO
	await wait_physics_frames(2)
	assert_eq(saves[0], 1, "re-entering after leaving saves")


func test_full_stack_pickup_stays() -> void:
	var coin := ItemData.new()
	coin.id = &"fix_coin"
	coin.type = ItemData.ItemType.CONSUMABLE
	coin.max_stack = 2
	GameState.add_item(coin, 2)
	var pk: Pickup = instantiate_scene("res://scenes/core/interaction/pickup.tscn")
	pk.item = coin
	pk.collected_flag = &"fix.coin.collected"
	await wait_physics_frames(1)
	assert_false(await pk.collect(null), "stack full")
	assert_false(pk.is_collected, "pickup stays in the world")
	assert_true(pk.visible)
	assert_false(GameState.has_flag(&"fix.coin.collected"), "flag not set")
	GameState.remove_item(&"fix_coin")
	assert_true(await pk.collect(null), "collectable once there is room")
	assert_true(GameState.has_flag(&"fix.coin.collected"))


func test_one_way_door_and_item_use_derive_flags() -> void:
	var packed: PackedScene = load("res://scenes/core/interaction/one_way_door.tscn")
	var door: OneWayDoor = packed.instantiate()
	door.name = "FixDoor"
	add_test_node(door)
	assert_true(String(door.open_flag).begins_with("auto."), "derived open_flag: %s" % door.open_flag)
	door.open()
	assert_true(GameState.has_flag(door.open_flag))
	var flag := door.open_flag
	door.free()
	var again: OneWayDoor = packed.instantiate()
	again.name = "FixDoor"
	add_test_node(again)
	assert_eq(again.open_flag, flag, "same node path -> same flag")
	assert_true(again.is_open, "persists without an authored flag")
	var spot := ItemUseInteractable.new()
	spot.name = "FixSpot"
	spot.required_item = &"fix_part"
	spot.consume_required_item = true
	add_test_node(spot)
	assert_true(String(spot.success_flag).begins_with("auto."), "derived success_flag")
	var part := ItemData.new()
	part.id = &"fix_part"
	GameState.add_item(part)
	await spot.interact(self)
	assert_true(GameState.has_flag(spot.success_flag), "consumed use persisted")


func test_top_down_snaps_to_eight_directions() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	await wait_physics_frames(2)
	input.move = Vector2(1.0, 0.3)
	await wait_physics_frames(30)
	assert_almost_eq(p.velocity.y, 0.0, 0.01, "near-horizontal input snaps to cardinal")
	assert_almost_eq(p.velocity.x, p.config.move_speed, 0.5, "full speed")
	input.move = Vector2(0.9, 0.5)
	await wait_physics_frames(30)
	assert_almost_eq(p.velocity.x, p.velocity.y, 0.5, "snapped to 45 degrees")
	assert_almost_eq(p.velocity.length(), p.config.move_speed, 0.5, "diagonal == cardinal speed")
	input.move = Vector2(0.35, 0.0)
	await wait_physics_frames(30)
	assert_almost_eq(p.velocity.x, p.config.move_speed * 0.35, 0.5, "analog magnitude kept")
