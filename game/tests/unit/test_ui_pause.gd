extends TestCase
## PauseMenu (child of the InputFeedback autoload): pause ownership, rumble stop,
## transitions, settings, disconnect overlay, glyphs and the pad->ui bridge.

const HUB := "res://scenes/tests/test_hub.tscn"
const LAB := "res://scenes/tests/controller_lab.tscn"

var menu: PauseMenu
var _removed_group_from: Node


func before_each() -> void:
	menu = get_tree().get_first_node_in_group(PauseMenu.GROUP) as PauseMenu
	get_tree().paused = false


func after_each() -> void:
	if menu.is_open():
		menu.close()
	SceneRouter.is_transitioning = false
	get_tree().paused = false
	if _removed_group_from and is_instance_valid(_removed_group_from):
		_removed_group_from.add_to_group(PauseMenu.NO_DISCONNECT_PAUSE_GROUP)
	_removed_group_from = null


func _pause_event(pressed: bool = true) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = pressed
	return ev


## The current scene may be the hub / Controller Lab (which suppress the auto-pause).
func _allow_disconnect_pause() -> void:
	var scene := get_tree().current_scene
	if scene and scene.is_in_group(PauseMenu.NO_DISCONNECT_PAUSE_GROUP):
		scene.remove_from_group(PauseMenu.NO_DISCONNECT_PAUSE_GROUP)
		_removed_group_from = scene


func test_menu_is_autoload_child() -> void:
	assert_not_null(menu, "found via group")
	assert_eq(menu.get_parent(), InputFeedback, "child of InputFeedback")
	assert_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_false(menu.visible, "hidden by default")


func test_open_close_toggles_pause_and_stops_rumble() -> void:
	var stops := [0]
	var original := menu.rumble_stopper
	menu.rumble_stopper = func() -> void: stops[0] += 1
	assert_true(menu.open(), "opened")
	menu.rumble_stopper = original
	assert_true(get_tree().paused, "tree paused")
	assert_true(menu.visible and menu.is_open())
	assert_eq(stops[0], 1, "rumble stopped on open")
	var focus := get_viewport().gui_get_focus_owner()
	assert_eq(focus, menu.get_button(&"resume"), "Resume focused")
	menu.close()
	assert_false(get_tree().paused, "unpaused")
	assert_false(menu.visible)


func test_pause_action_opens_and_closes() -> void:
	menu._unhandled_input(_pause_event())
	assert_true(menu.is_open(), "pause opens")
	menu._input(_pause_event())
	assert_false(menu.is_open(), "pause again resumes")
	assert_false(get_tree().paused)


func test_close_restores_previous_pause_state() -> void:
	get_tree().paused = true  # e.g. a popup paused the game
	menu.open()
	menu.close()
	assert_true(get_tree().paused, "stays paused for the popup")


func test_blocked_during_transition() -> void:
	SceneRouter.is_transitioning = true
	assert_false(menu.open(), "refused")
	menu._unhandled_input(_pause_event())
	assert_false(menu.is_open())
	assert_false(get_tree().paused, "pause untouched")


func test_transition_start_hides_without_touching_pause() -> void:
	menu.open()
	SceneRouter.transition_started.emit("res://dummy.tscn", &"")
	assert_false(menu.is_open(), "force-hidden")
	assert_true(get_tree().paused, "router owns pause now")


func test_settings_page_writes_game_state() -> void:
	menu.open()
	menu.show_settings()
	assert_eq(menu.mode, PauseMenu.Mode.SETTINGS)
	menu._strength_slider.value = 0.5
	assert_almost_eq(float(GameState.get_setting(&"vibration_strength")), 0.5, 0.001, "strength")
	menu._deadzone_slider.value = 0.3
	assert_almost_eq(float(GameState.get_setting(&"stick_deadzone")), 0.3, 0.001, "deadzone setting")
	assert_almost_eq(InputMap.action_get_deadzone(&"move_left"), 0.3, 0.001, "deadzone applied")
	menu._vibration_check.button_pressed = false
	assert_eq(GameState.get_setting(&"vibration_enabled"), false)
	menu._assist_timing_check.button_pressed = true
	assert_eq(GameState.get_combat_timing_scale(), 1.35, "assist timing on")
	menu._assist_context_check.button_pressed = true
	assert_eq(GameState.get_setting(&"assist_context_actions"), true)
	menu._input(_pause_event())
	assert_eq(menu.mode, PauseMenu.Mode.MAIN, "back to main")
	# restore defaults
	GameState.set_setting(&"vibration_strength", 1.0)
	GameState.set_setting(&"vibration_enabled", true)
	GameState.set_setting(&"assist_combat_timing", false)
	GameState.set_setting(&"assist_context_actions", false)
	InputFeedback.set_stick_deadzone(0.2)


func test_disconnect_auto_pauses_and_keyboard_resumes() -> void:
	_allow_disconnect_pause()
	InputFeedback.device_disconnected.emit(0, "Wireless Controller")
	assert_true(menu.is_open(), "auto-opened")
	assert_eq(menu.mode, PauseMenu.Mode.DISCONNECT)
	assert_true(get_tree().paused, "paused")
	assert_true(menu.get_disconnect_text().contains("disconnected"))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.keycode = KEY_K
	key.pressed = true
	menu._input(key)
	assert_false(menu.is_open(), "any key continues with keyboard")
	assert_false(get_tree().paused)


func test_reconnect_shows_name_and_pad_resumes() -> void:
	_allow_disconnect_pause()
	InputFeedback.device_disconnected.emit(0, "Wireless Controller")
	var stray := InputEventJoypadButton.new()
	stray.button_index = JOY_BUTTON_X
	stray.pressed = true
	menu._input(stray)
	assert_true(menu.is_open(), "pad button ignored before reconnect")
	InputFeedback.device_connected.emit(0, "DUALSHOCK 4 Test")
	assert_true(menu.get_disconnect_text().contains("DUALSHOCK 4 Test"), "device name shown")
	menu._input(stray)
	assert_false(menu.is_open(), "pad button resumes after reconnect")
	assert_false(get_tree().paused)


func test_disconnect_during_transition_is_deferred() -> void:
	_allow_disconnect_pause()
	SceneRouter.is_transitioning = true
	InputFeedback.device_disconnected.emit(0, "Wireless Controller")
	assert_false(menu.is_open(), "not during transition")
	SceneRouter.is_transitioning = false
	SceneRouter.transition_finished.emit("res://dummy.tscn")
	assert_true(menu.is_open(), "opened after transition")
	assert_eq(menu.mode, PauseMenu.Mode.DISCONNECT)


func test_disconnect_in_suppressed_scene_only_toasts() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		await change_scene_and_wait(HUB)
		scene = get_tree().current_scene
	var had_group := scene.is_in_group(PauseMenu.NO_DISCONNECT_PAUSE_GROUP)
	scene.add_to_group(PauseMenu.NO_DISCONNECT_PAUSE_GROUP)
	var texts: Array[String] = []
	var cb := func(t: String, _d: float) -> void: texts.append(t)
	GameState.notification_requested.connect(cb)
	InputFeedback.device_disconnected.emit(0, "Wireless Controller")
	GameState.notification_requested.disconnect(cb)
	if not had_group:
		scene.remove_from_group(PauseMenu.NO_DISCONNECT_PAUSE_GROUP)
	assert_false(menu.is_open(), "no auto-pause")
	assert_eq(texts.size(), 1, "toast instead")


func test_return_to_hub_hands_pause_to_router() -> void:
	await change_scene_and_wait(LAB)
	menu.open()
	menu.get_button(&"hub").pressed.emit()
	assert_false(menu.is_open())
	assert_true(SceneRouter.is_transitioning, "router transition started")
	await SceneRouter.transition_finished
	assert_eq(SceneRouter.get_current_scene_path(), HUB)
	assert_false(get_tree().paused, "unpaused by router")
	menu.open()
	assert_true(menu.get_button(&"hub").disabled, "hub entry disabled on hub")
	assert_true(menu.get_button(&"checkpoint").disabled, "restart disabled on hub")


func test_glyph_labels_keyboard_vs_joypad() -> void:
	assert_eq(InputFeedback.get_action_glyph(&"jump", &"keyboard").label, "Space")
	assert_eq(InputFeedback.get_action_glyph(&"jump", &"joypad").label, "Cross")
	assert_eq(InputFeedback.get_action_glyph(&"pause", &"joypad").label, "Options")
	assert_eq(InputFeedback.get_action_glyph(&"context_left", &"joypad").label, "L2")
	var glyph := ButtonGlyph.new()
	glyph.action = &"interact"
	add_test_node(glyph)
	glyph.force_kind = &"keyboard"
	assert_eq(glyph.get_glyph().label, "E")
	glyph.force_kind = &"joypad"
	assert_eq(glyph.get_glyph().label, "Triangle")


func test_pad_cross_activates_focused_button() -> void:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	add_test_node(button)
	var hits := [0]
	button.pressed.connect(func() -> void: hits[0] += 1)
	button.grab_focus()
	await wait_frames(1)
	for pressed: bool in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.button_index = JOY_BUTTON_A
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await wait_frames(2)
	assert_eq(hits[0], 1, "Cross bridged to ui_accept")
	release_all_actions()
