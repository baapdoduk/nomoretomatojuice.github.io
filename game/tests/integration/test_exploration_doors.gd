extends PlayerTestCase
## OneWayDoor side rule + persistence, LockedDoor / ItemUseInteractable.

const ONE_WAY := "res://scenes/core/interaction/one_way_door.tscn"
const LOCKED := "res://scenes/core/interaction/locked_door.tscn"


func _door(flag: StringName) -> OneWayDoor:
	var packed: PackedScene = load(ONE_WAY)
	var d: OneWayDoor = packed.instantiate()
	d.open_side = Vector2.RIGHT
	d.open_flag = flag
	add_test_node(d)
	return d


func test_one_way_door_side_rule_and_persistence() -> void:
	capture_toasts()
	var door := _door(&"door.test_shortcut.open")
	var opened := [0]
	door.opened.connect(func() -> void: opened[0] += 1)
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2(-20, -2))
	await wait_physics_frames(4)
	# Wrong side: focusable, shows the locked prompt, refuses to open, blocks.
	assert_eq(p.interactor.target, door, "door focusable from the wrong side")
	assert_eq(door.get_prompt_text(), door.wrong_side_prompt, "locked prompt")
	input.interact_pressed = true
	await wait_physics_frames(3)
	assert_false(door.is_open, "cannot open from the wrong side")
	assert_true(toasts.has(door.wrong_side_message), "wrong-side message")
	input.move = Vector2.RIGHT
	await wait_physics_frames(40)
	input.move = Vector2.ZERO
	assert_true(p.global_position.x < -9.0, "blocked by the closed door (x=%.1f)" % p.global_position.x)
	# Right side: opens, sets the flag, passage clear.
	p.global_position = Vector2(20, -2)
	await wait_physics_frames(15)
	assert_eq(door.get_prompt_text(), "Open")
	input.interact_pressed = true
	await wait_physics_frames(3)
	assert_true(door.is_open, "opened from the open side")
	assert_true(door.is_active(), "puzzle contract")
	assert_eq(opened[0], 1)
	assert_true(GameState.has_flag(&"door.test_shortcut.open"), "flag persisted")
	input.move = Vector2.LEFT
	await wait_physics_frames(30)
	input.move = Vector2.ZERO
	assert_true(p.global_position.x < -30.0, "walked through (x=%.1f)" % p.global_position.x)
	# Re-entry: a fresh instance with the same flag starts open.
	door.queue_free()
	var again := _door(&"door.test_shortcut.open")
	await wait_physics_frames(2)
	assert_true(again.is_open, "open on reload")
	assert_true((again.blocker.get_child(0) as CollisionShape2D).disabled, "blocker disabled")
	assert_false(again.can_focus(p), "no prompt once open")


func test_locked_door_needs_key() -> void:
	capture_toasts()
	var packed: PackedScene = load(LOCKED)
	var door: LockedDoor = packed.instantiate()
	door.required_item = &"test_key"
	door.success_flag = &"door.test_locked.open"
	door.blocked_message = "Locked."
	add_test_node(door)
	var used := [0]
	door.used.connect(func(_id: StringName) -> void: used[0] += 1)
	await wait_physics_frames(1)
	assert_eq(door.get_prompt_text(), "Locked", "locked prompt without key")
	await door.interact(self)
	assert_false(door.is_open())
	assert_true(toasts.has("Locked."))
	var key := ItemData.new()
	key.id = &"test_key"
	key.type = ItemData.ItemType.PROGRESSION
	GameState.add_item(key)
	assert_eq(door.get_prompt_text(), "Unlock")
	await door.interact(self)
	await wait_physics_frames(2)
	assert_true(door.is_open(), "unlocked")
	assert_eq(used[0], 1)
	assert_true(GameState.has_flag(&"door.test_locked.open"))
	assert_true((door.blocker.get_child(0) as CollisionShape2D).disabled, "blocker removed")
	var again: LockedDoor = packed.instantiate()
	again.required_item = &"test_key"
	again.success_flag = &"door.test_locked.open"
	add_test_node(again)
	await wait_physics_frames(2)
	assert_true(again.is_open(), "stays open on reload")


func test_item_use_consumes_and_sets_flag() -> void:
	var spot := ItemUseInteractable.new()
	spot.required_item = &"test_gem"
	spot.consume_required_item = true
	spot.success_flag = &"altar.test.done"
	add_test_node(spot)
	var changes: Array[bool] = []
	spot.activated_changed.connect(func(a: bool) -> void: changes.append(a))
	var gem := ItemData.new()
	gem.id = &"test_gem"
	GameState.add_item(gem)
	await spot.interact(self)
	assert_true(spot.is_active())
	assert_false(GameState.has_item(&"test_gem"), "consumed")
	assert_true(GameState.has_flag(&"altar.test.done"))
	assert_eq(changes, [true] as Array[bool])
	assert_false(spot.can_focus(self), "one-shot")
