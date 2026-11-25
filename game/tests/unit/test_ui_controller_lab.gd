extends TestCase
## Controller Lab runs headless without a pad: all pages refresh, keyboard test keys
## are safe with no device, support table is filled.

const LAB := "res://scenes/tests/controller_lab.tscn"

func after_each() -> void:
	# Simulated disconnects may auto-open the pause menu outside suppressed scenes.
	var menu := get_tree().get_first_node_in_group(PauseMenu.GROUP) as PauseMenu
	if menu.is_open():
		menu.close()

func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	return ev

func test_pages_and_support_table() -> void:
	var lab := instantiate_scene(LAB)
	assert_eq(lab.call(&"get_button_cell_count"), JOY_BUTTON_SDL_MAX, "one cell per SDL button")
	assert_eq(lab.call(&"get_page_count"), 3)
	for i in 3:
		lab.call(&"select_page", i)
		await wait_frames(2)
	var rows: Array = lab.call(&"get_support_rows")
	assert_true(rows.size() >= 8, "support rows")
	for row: Array in rows:
		assert_eq(row.size(), 4, "4 columns: " + str(row))
	assert_eq(rows[0][0], "Vibration")
	assert_eq(rows[0][1], "yes", "vibration API present in 4.7")
	assert_true(lab.is_in_group(PauseMenu.NO_DISCONNECT_PAUSE_GROUP))

func test_keyboard_test_keys_without_device() -> void:
	var lab := instantiate_scene(LAB)
	if InputFeedback.has_joypad():
		return
	for code: Key in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_0, KEY_L, KEY_M, KEY_C, KEY_N]:
		lab._unhandled_key_input(_key(code))
	assert_true(String(lab.get(&"_last_feedback")) != "-", "feedback reported")
	lab._unhandled_key_input(_key(KEY_TAB))
	assert_eq(lab.get(&"page"), 1, "Tab = next page")
	await wait_frames(2)

func test_simulated_connection_events_logged() -> void:
	var lab := instantiate_scene(LAB)
	InputFeedback.device_connected.emit(3, "Fake Pad")
	InputFeedback.device_disconnected.emit(3, "Fake Pad")
	var log: PackedStringArray = lab.get(&"_connection_log")
	assert_eq(log.size(), 2, "both events logged")
	assert_true(log[0].contains("Fake Pad"))
	lab.call(&"select_page", 1)
	await wait_frames(2)
