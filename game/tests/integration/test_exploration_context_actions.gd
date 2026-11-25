extends PlayerTestCase
## ContextActionInteractable: every type completes without a time limit,
## assist mode, cancel, puzzle contract.

const CTX := "res://scenes/core/interaction/context_action.tscn"


func before_each() -> void:
	super.before_each()
	GameState.set_setting(&"assist_context_actions", false)


func after_each() -> void:
	super.after_each()
	GameState.set_setting(&"assist_context_actions", false)


func _ctx(type: ContextActionInteractable.ActionType, action: StringName, props := {}) -> ContextActionInteractable:
	var packed: PackedScene = load(CTX)
	var c: ContextActionInteractable = packed.instantiate()
	c.action_type = type
	c.action = action
	c.success_flag = StringName("ctx.test.%d" % type)
	for k in props:
		c.set(k, props[k])
	add_test_node(c)
	return c


func _start(c: ContextActionInteractable) -> void:
	c.interact(self)  # coroutine keeps running; not awaited on purpose
	await wait_physics_frames(2)
	assert_true(c.is_running, "started")


func _tap(action: StringName, times: int) -> void:
	for i in times:
		Input.action_press(action)
		await wait_physics_frames(2)
		Input.action_release(action)
		await wait_physics_frames(2)


func _assert_done(c: ContextActionInteractable, label: String) -> void:
	assert_true(c.is_completed, label + " completed")
	assert_false(c.is_running, label + " stopped")
	assert_true(c.is_active(), label + " puzzle contract active")
	assert_true(GameState.has_flag(c.success_flag), label + " success flag")


func test_press() -> void:
	var c := _ctx(ContextActionInteractable.ActionType.PRESS, &"attack")
	var done := [0]
	c.completed.connect(func() -> void: done[0] += 1)
	await _start(c)
	await wait_seconds(1.0)  # no time limit
	assert_true(c.is_running, "still waiting for the press")
	await _tap(&"attack", 1)
	_assert_done(c, "press")
	assert_eq(done[0], 1)


func test_press_with_interact_completes_immediately() -> void:
	var c := _ctx(ContextActionInteractable.ActionType.PRESS, &"interact")
	await c.interact(self)
	_assert_done(c, "press(interact)")


func test_hold() -> void:
	var c := _ctx(ContextActionInteractable.ActionType.HOLD, &"interact", {"hold_time": 1.0})
	await _start(c)
	await wait_seconds(2.0)  # idle for longer than the hold time: no failure
	assert_true(c.is_running, "no time limit")
	assert_almost_eq(c.progress, 0.0, 0.001)
	Input.action_press(&"interact")
	await wait_seconds(0.5)
	assert_almost_eq(c.progress, 0.5, 0.06, "half way after 0.5 s")
	assert_false(c.is_completed)
	await wait_seconds(0.6)
	Input.action_release(&"interact")
	_assert_done(c, "hold")


func test_mash() -> void:
	var c := _ctx(ContextActionInteractable.ActionType.MASH, &"interact", {"mash_count": 6})
	await _start(c)
	await _tap(&"interact", 3)
	assert_almost_eq(c.progress, 0.5, 0.01, "3 of 6 presses")
	await wait_seconds(1.5)
	assert_almost_eq(c.progress, 0.5, 0.01, "no decay / no time limit by default")
	await _tap(&"interact", 3)
	_assert_done(c, "mash")


func test_mash_becomes_hold_with_assist() -> void:
	GameState.set_setting(&"assist_context_actions", true)
	var c := _ctx(ContextActionInteractable.ActionType.MASH, &"interact", {"mash_count": 50, "hold_time": 0.5})
	assert_true(c.is_assisted())
	await _start(c)
	Input.action_press(&"interact")
	await wait_seconds(0.6)
	Input.action_release(&"interact")
	_assert_done(c, "assisted mash")


func test_stick_direction() -> void:
	var c := _ctx(ContextActionInteractable.ActionType.STICK_DIRECTION, &"interact",
		{"stick_direction": Vector2.LEFT, "confirm_time": 0.3})
	await _start(c)
	Input.action_press(&"move_right")
	await wait_seconds(1.0)
	Input.action_release(&"move_right")
	assert_false(c.is_completed, "wrong direction does nothing")
	assert_true(c.is_running)
	Input.action_press(&"move_left")
	await wait_seconds(0.4)
	Input.action_release(&"move_left")
	_assert_done(c, "stick")


func test_trigger_depth() -> void:
	var c := _ctx(ContextActionInteractable.ActionType.TRIGGER_DEPTH, &"context_right",
		{"trigger_threshold": 0.85, "confirm_time": 0.3})
	await _start(c)
	Input.action_press(&"context_right", 0.5)
	await wait_seconds(1.0)
	assert_almost_eq(c.current_depth, 0.5, 0.06, "depth read from analog strength")
	assert_false(c.is_completed, "half-pulled trigger is not enough")
	Input.action_press(&"context_right", 1.0)
	await wait_seconds(0.4)
	Input.action_release(&"context_right")
	_assert_done(c, "trigger")


func test_trigger_becomes_hold_with_assist() -> void:
	GameState.set_setting(&"assist_context_actions", true)
	var c := _ctx(ContextActionInteractable.ActionType.TRIGGER_DEPTH, &"context_left", {"hold_time": 0.5})
	await _start(c)
	Input.action_press(&"context_left", 0.3)
	await wait_seconds(0.6)
	Input.action_release(&"context_left")
	_assert_done(c, "assisted trigger")


func test_cancel_and_retry() -> void:
	var c := _ctx(ContextActionInteractable.ActionType.HOLD, &"interact", {"hold_time": 0.5})
	var cancelled := [0]
	c.cancelled.connect(func() -> void: cancelled[0] += 1)
	await _start(c)
	Input.action_press(&"interact")
	await wait_seconds(0.2)
	Input.action_release(&"interact")
	await _tap(&"dash", 1)
	assert_eq(cancelled[0], 1, "cancelled with dash")
	assert_false(c.is_running)
	assert_false(c.is_completed)
	assert_eq(c.progress, 0.0, "progress reset")
	await wait_physics_frames(1)
	assert_true(c.can_focus(self), "can retry after cancel")
	await _start(c)
	Input.action_press(&"interact")
	await wait_seconds(0.6)
	Input.action_release(&"interact")
	_assert_done(c, "retry")
	assert_false(c.can_focus(self), "done (not repeatable)")


func test_optional_time_limit_fails() -> void:
	var c := _ctx(ContextActionInteractable.ActionType.MASH, &"interact", {"time_limit": 0.3})
	var failed := [0]
	c.failed.connect(func() -> void: failed[0] += 1)
	await _start(c)
	await wait_seconds(0.5)
	assert_eq(failed[0], 1, "time limit enforced when set")
	assert_false(c.is_completed)


func test_player_interaction_locks_during_action() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	var c := _ctx(ContextActionInteractable.ActionType.HOLD, &"interact", {"hold_time": 0.3})
	c.position = Vector2(6, 2)
	await wait_physics_frames(4)
	assert_eq(p.interactor.target, c)
	input.interact_pressed = true
	await wait_physics_frames(3)
	assert_true(c.is_running)
	assert_true(p.has_input_lock(Interactor.LOCK_REASON), "movement locked while running")
	Input.action_press(&"interact")
	await wait_seconds(0.4)
	Input.action_release(&"interact")
	assert_true(c.is_completed)
	await wait_seconds(0.25)
	assert_false(p.is_input_locked(), "unlocked afterwards")
