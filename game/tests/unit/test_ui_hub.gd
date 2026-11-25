extends TestCase
## Test hub: lab availability, entering labs as chapters, new game, status line.

const HUB := "res://scenes/tests/test_hub.tscn"
const LAB := "res://scenes/tests/controller_lab.tscn"
const MISSING := "res://scenes/tests/__missing_lab_for_test.tscn"

func before_each() -> void:
	GameState.new_game(5)

func _make_hub(custom_labs: Array[Dictionary] = []) -> Control:
	var hub: Control = (load(HUB) as PackedScene).instantiate()
	if not custom_labs.is_empty():
		hub.set(&"labs", custom_labs)
	add_test_node(hub)
	return hub

func test_default_labs_match_files() -> void:
	var hub := _make_hub()
	var labs: Array[Dictionary] = hub.get(&"labs")
	assert_eq(labs.size(), 6, "six labs listed")
	for lab in labs:
		var button: Button = hub.call(&"get_lab_button", lab.id)
		assert_not_null(button, "button for %s" % lab.id)
		assert_eq(button.disabled, not ResourceLoader.exists(lab.path), "disabled iff missing: %s" % lab.id)
	assert_false((hub.call(&"get_lab_button", &"controller_lab") as Button).disabled, "controller lab exists")

func test_missing_lab_disabled_and_not_enterable() -> void:
	var labs: Array[Dictionary] = [
		{"id": &"controller_lab", "title": "Controller Lab", "path": LAB, "description": ""},
		{"id": &"ghost", "title": "Ghost", "path": MISSING, "description": ""},
	]
	var hub := _make_hub(labs)
	var ghost: Button = hub.call(&"get_lab_button", &"ghost")
	assert_true(ghost.disabled, "missing lab disabled")
	assert_eq(ghost.focus_mode, Control.FOCUS_NONE, "not focusable")
	assert_false(hub.call(&"enter_lab", &"ghost"), "cannot enter")
	assert_false(SceneRouter.is_transitioning)
	await wait_frames(1)
	assert_eq(get_viewport().gui_get_focus_owner(), hub.call(&"get_lab_button", &"controller_lab"), "first available focused")

func test_enter_lab_begins_chapter() -> void:
	var hub := _make_hub()
	assert_true(hub.call(&"enter_lab", &"controller_lab"))
	await SceneRouter.transition_finished
	assert_eq(GameState.current_chapter, &"controller_lab")
	assert_eq(String(GameState.chapter_start.get("scene_path")), LAB)
	assert_eq(SceneRouter.get_current_scene_path(), LAB)
	await change_scene_and_wait(HUB)

func test_new_game_resets_state() -> void:
	var hub := _make_hub()
	var item := ItemData.new()
	item.id = &"hub_test_item"
	GameState.add_item(item)
	GameState.set_flag(&"hub.test")
	hub.call(&"new_game")
	assert_false(GameState.has_item(&"hub_test_item"))
	assert_false(GameState.has_flag(&"hub.test"))

func test_status_line_without_controller() -> void:
	var hub := _make_hub()
	if InputFeedback.has_joypad():
		return
	assert_true(String(hub.call(&"get_status_text")).contains("keyboard"), "keyboard status")
