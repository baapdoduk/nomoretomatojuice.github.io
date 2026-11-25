extends Control
## Test hub (main scene, res://scenes/tests/test_hub.tscn).
## Pad/keyboard-navigable list of labs. A lab whose scene file does not exist
## (yet) is shown disabled; availability is checked at runtime with
## ResourceLoader.exists, so labs light up automatically once they are merged.
## Entering a lab: GameState.begin_chapter(id, path, &"start") + SceneRouter.change_scene(path, &"start").
## Every lab returns here via the pause menu ("Return to hub").

const LAB_DIR := "res://scenes/tests/"

## Lab entries: { id: StringName, title: String, path: String, description: String }.
## Assign before the node enters the tree to customise (tests do this).
var labs: Array[Dictionary] = [
	{"id": &"controller_lab", "title": "Controller Lab", "path": LAB_DIR + "controller_lab.tscn",
		"description": "Raw DS4 buttons, sticks, triggers, rumble, light bar, motion, support table."},
	{"id": &"side_view_lab", "title": "Side-View Lab", "path": LAB_DIR + "side_view_lab.tscn",
		"description": "Platforming movement: run, jump, dash, ladders, interactions."},
	{"id": &"top_down_lab", "title": "Top-Down Lab", "path": LAB_DIR + "top_down_lab.tscn",
		"description": "Top-down exploration movement and interactions."},
	{"id": &"combat_lab", "title": "Combat Lab", "path": LAB_DIR + "combat_lab.tscn",
		"description": "Attacks, dummies, boss patterns, telegraphs."},
	{"id": &"puzzle_lab", "title": "Puzzle Lab", "path": LAB_DIR + "puzzle_lab.tscn",
		"description": "Switches, plates, gates, light and mirror puzzles."},
	{"id": &"integration_overworld", "title": "Integration (overworld)", "path": LAB_DIR + "integration_overworld.tscn",
		"description": "Everything together: doors, checkpoints, items, puzzles, combat."},
]

var _buttons: Dictionary = {}  # StringName -> Button
var _list: VBoxContainer
var _description: Label
var _status: Label
var _last_focused: Control


func _ready() -> void:
	add_to_group(PauseMenu.NO_DISCONNECT_PAUSE_GROUP)
	_build_ui()
	InputFeedback.device_connected.connect(func(_d: int, _n: String) -> void: _update_status())
	InputFeedback.device_disconnected.connect(func(_d: int, _n: String) -> void: _update_status.call_deferred())
	InputFeedback.input_kind_changed.connect(func(_k: StringName) -> void: _update_status())
	_update_status()
	_focus_default()


func _process(_delta: float) -> void:
	# Regain focus after the pause menu closes or a mouse click cleared it.
	if get_viewport().gui_get_focus_owner() == null:
		_focus_default()


# --------------------------------------------------------------------------- public API

func is_lab_available(id: StringName) -> bool:
	var lab := _find_lab(id)
	return not lab.is_empty() and ResourceLoader.exists(String(lab.path))

func get_lab_button(id: StringName) -> Button:
	return _buttons.get(id, null)

## Starts a lab as a chapter. Returns false when the lab is unknown/missing or a transition runs.
func enter_lab(id: StringName) -> bool:
	if SceneRouter.is_transitioning or not is_lab_available(id):
		return false
	var path := String(_find_lab(id).path)
	GameState.begin_chapter(id, path, &"start")
	SceneRouter.change_scene(path, &"start")
	return true

## Resets all progress (health, items, flags, checkpoints).
func new_game() -> void:
	GameState.new_game()
	GameState.notify("New game: state reset.", 2.0)


func get_status_text() -> String:
	return _status.text


# --------------------------------------------------------------------------- internals

func _find_lab(id: StringName) -> Dictionary:
	for lab in labs:
		if lab.id == id:
			return lab
	return {}


func _update_status() -> void:
	var pads: Array[int] = InputFeedback.get_connected_joypads()
	var text := ""
	if pads.is_empty():
		text = "Controller: none (keyboard)"
	else:
		var dev: int = InputFeedback.active_device if InputFeedback.active_device >= 0 else pads[0]
		text = "Controller: %s (device %d)" % [InputFeedback.get_device_name(dev), dev]
		if pads.size() > 1:
			text += " +%d more" % (pads.size() - 1)
	text += "   |   last input: %s" % InputFeedback.last_input_kind
	_status.text = text


func _focus_default() -> void:
	if _last_focused and is_instance_valid(_last_focused) and _last_focused.focus_mode != FOCUS_NONE:
		_last_focused.grab_focus()
		return
	for child in _list.get_children():
		var b := child as Button
		if b and not b.disabled:
			b.grab_focus()
			return


func _on_focus(button: Button, description: String) -> void:
	_last_focused = button
	_description.text = description


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var theme_res := Theme.new()
	theme_res.default_font_size = 11
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1.0, 0.85, 0.3)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	theme_res.set_stylebox(&"focus", &"Button", focus)
	theme = theme_res

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.11)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 4)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "NMTJ Gameplay Framework - Test Hub"
	title.add_theme_font_size_override(&"font_size", 16)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Pick a lab. In any lab, open the pause menu to return here."
	sub.add_theme_font_size_override(&"font_size", 9)
	sub.modulate = Color(0.75, 0.75, 0.85)
	vbox.add_child(sub)

	var row := HBoxContainer.new()
	row.size_flags_vertical = SIZE_EXPAND_FILL
	row.add_theme_constant_override(&"separation", 12)
	vbox.add_child(row)

	_list = VBoxContainer.new()
	_list.name = "LabList"
	_list.custom_minimum_size = Vector2(220, 0)
	_list.add_theme_constant_override(&"separation", 3)
	row.add_child(_list)

	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.size_flags_horizontal = SIZE_EXPAND_FILL
	_description.add_theme_font_size_override(&"font_size", 10)
	_description.modulate = Color(0.85, 0.85, 0.95)
	row.add_child(_description)

	for lab in labs:
		var available := ResourceLoader.exists(String(lab.path))
		var b := Button.new()
		b.name = String(lab.id).to_pascal_case()
		b.text = String(lab.title) + ("" if available else "  (not available yet)")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not available
		b.focus_mode = FOCUS_ALL if available else FOCUS_NONE
		var lab_id: StringName = lab.id
		b.pressed.connect(func() -> void: enter_lab(lab_id))
		var desc := String(lab.get("description", "")) + ("" if available else "\n(Scene file missing: %s)" % lab.path)
		b.focus_entered.connect(_on_focus.bind(b, desc))
		_list.add_child(b)
		_buttons[lab_id] = b

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_list.add_child(spacer)
	var reset := Button.new()
	reset.name = "NewGame"
	reset.text = "New game (reset state)"
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.focus_mode = FOCUS_ALL
	reset.pressed.connect(new_game)
	reset.focus_entered.connect(_on_focus.bind(reset, "Reset health, items, flags and checkpoints."))
	_list.add_child(reset)
	_buttons[&"new_game"] = reset

	_link_focus_ring()

	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 9)
	_status.modulate = Color(0.7, 0.9, 0.7)
	vbox.add_child(_status)

	var hints := HBoxContainer.new()
	hints.add_theme_constant_override(&"separation", 4)
	vbox.add_child(hints)
	for pair: Array in [[&"move_up", "Navigate"], [&"jump", "Select"], [&"pause", "Menu / Settings"]]:
		var glyph := ButtonGlyph.new()
		glyph.action = pair[0]
		glyph.custom_minimum_size = Vector2(14, 14)
		hints.add_child(glyph)
		var l := Label.new()
		l.text = pair[1]
		l.add_theme_font_size_override(&"font_size", 9)
		hints.add_child(l)


func _link_focus_ring() -> void:
	var items: Array[Button] = []
	for child in _list.get_children():
		var b := child as Button
		if b and b.focus_mode == FOCUS_ALL:
			items.append(b)
	for i in items.size():
		var prev := items[(i - 1 + items.size()) % items.size()]
		var next := items[(i + 1) % items.size()]
		items[i].focus_neighbor_top = items[i].get_path_to(prev)
		items[i].focus_neighbor_bottom = items[i].get_path_to(next)
		items[i].focus_neighbor_left = NodePath(".")
		items[i].focus_neighbor_right = NodePath(".")
