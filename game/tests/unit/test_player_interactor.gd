extends PlayerTestCase
## Interactor target selection (priority, then distance), interaction locks,
## prompt and popup flow.


func test_interactor_picks_nearest_then_priority() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	# Interactor centre is at (0, -10).
	var far := make_interactable_at(Vector2(12, -10))
	var near := make_interactable_at(Vector2(-5, -10))
	var disabled := make_interactable_at(Vector2(0, -10))
	disabled.enabled = false
	var outside := make_interactable_at(Vector2(80, -10))
	outside.interact_priority = 99
	await wait_physics_frames(4)
	assert_eq(p.interactor.target, near, "nearest focusable target")
	assert_true(near.is_focused, "focused flag set")
	assert_false(far.is_focused)
	far.interact_priority = 1
	await wait_physics_frames(2)
	assert_eq(p.interactor.target, far, "higher priority wins over distance")
	assert_false(near.is_focused, "previous target unfocused")
	far.enabled = false
	near.enabled = false
	await wait_physics_frames(2)
	assert_null(p.interactor.target, "no focusable target in range")
	assert_false(p.get_node("InteractionPrompt").visible, "prompt hidden")


func test_interact_press_calls_target_and_shows_prompt() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	var it := make_interactable_at(Vector2(6, -10))
	it.prompt_text = "Talk"
	var hits := [0]
	it.interacted.connect(func(_a: Node) -> void: hits[0] += 1)
	await wait_physics_frames(4)
	var prompt: InteractionPrompt = p.get_node("InteractionPrompt")
	assert_true(prompt.visible, "prompt visible")
	assert_eq(prompt.get_text(), "Talk")
	assert_vec_almost_eq(prompt.global_position, it.get_prompt_position(), 0.01, "prompt above target")
	input.interact_pressed = true
	await wait_physics_frames(2)
	assert_eq(hits[0], 1, "interact called once")


func test_popup_locks_movement_until_closed() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	var sign: PopupInteractable = instantiate_scene("res://scenes/core/interaction/popup_interactable.tscn")
	sign.position = Vector2(8, 0)
	sign.title = "Hello"
	sign.body = "World"
	sign.read_flag = &"test.sign.read"
	await wait_physics_frames(4)
	assert_eq(p.interactor.target, sign)
	input.interact_pressed = true
	await wait_physics_frames(3)
	assert_not_null(sign.current_popup, "popup open")
	assert_true(sign.current_popup.is_open())
	assert_true(p.is_input_locked(), "movement locked")
	assert_false(p.get_node("InteractionPrompt").visible, "prompt hidden while busy")
	input.move = Vector2.RIGHT
	await wait_physics_frames(5)
	assert_almost_eq(p.velocity.length(), 0.0, 0.01, "no movement while popup open")
	# Close with the real interact action (keyboard / pad path).
	Input.action_press(&"interact")
	await wait_frames(2)
	Input.action_release(&"interact")
	await wait_frames(2)
	assert_null(sign.current_popup, "popup closed by interact")
	assert_true(GameState.has_flag(&"test.sign.read"), "read flag set")
	await wait_seconds(0.25)
	assert_false(p.is_input_locked(), "unlocked after close + cooldown")
	await wait_physics_frames(5)
	assert_true(p.velocity.x > 0.0, "moves again")


func test_popup_closes_with_jump() -> void:
	var popup: InfoPopup = instantiate_scene("res://scenes/core/ui/popup_panel.tscn")
	var closed := [0]
	popup.closed.connect(func() -> void: closed[0] += 1)
	Input.action_press(&"jump")  # held while opening: must not close it
	popup.show_popup("T", "B", null)
	await wait_frames(3)
	assert_true(popup.is_open(), "opening press ignored")
	Input.action_release(&"jump")
	await wait_frames(1)
	Input.action_press(&"jump")
	await wait_frames(2)
	assert_false(popup.is_open(), "closed with jump")
	assert_eq(closed[0], 1)
