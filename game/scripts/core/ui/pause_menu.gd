class_name PauseMenu
extends CanvasLayer
## Pause menu + settings + controller-disconnect overlay.
## Lives as the child "PauseMenu" of the InputFeedback autoload scene, so it exists
## in every scene (process_mode ALWAYS). Reach it with get_tree().get_first_node_in_group(&"pause_menu").
##
## Pause ownership rules:
##   - open() remembers whether the tree was already paused (e.g. by a popup) and
##     close() restores exactly that value.
##   - open() is refused while SceneRouter.is_transitioning (the router owns pause then).
##   - Menu actions that change scene hand pause over to SceneRouter; if the router
##     refused to start a transition, the previous pause state is restored.
##   - A transition starting while the menu is open force-hides it without touching pause.
## "Restart from checkpoint" uses SceneRouter.respawn_at_checkpoint(), which counts
## as a death (death_count / assist tip) - intentionally treated as a "retry".
##
## Pad bridge: while a GUI control has focus, Cross/Circle (JOY_BUTTON_A/B) are
## re-emitted as ui_accept/ui_cancel unless the Input Map already maps them
## (Godot 4.7's default ui_accept/ui_cancel have no joypad events).
##
## Disconnect: when the active joypad disconnects (and no other pad remains active)
## the menu auto-opens in disconnect mode. Any keyboard key continues with keyboard;
## after a reconnect any pad button (or Resume) continues. Scenes in group
## "no_disconnect_pause" (hub, Controller Lab) only get a toast. If a transition is
## running, the overlay opens once it finishes.

signal opened
signal closed

const GROUP := &"pause_menu"
const NO_DISCONNECT_PAUSE_GROUP := &"no_disconnect_pause"
const CONTROLLER_LAB_PATH := "res://scenes/tests/controller_lab.tscn"

enum Mode { CLOSED, MAIN, SETTINGS, DISCONNECT }

var mode: Mode = Mode.CLOSED

var _paused_before := false
var _pending_disconnect := false
var _reconnected := false
var _last_active_device := -1

var _root: Control
var _title: Label
var _main_box: VBoxContainer
var _settings_box: VBoxContainer
var _disconnect_box: VBoxContainer
var _disconnect_label: Label
var _hint_row: HBoxContainer
var _buttons: Dictionary = {}   # StringName -> Button
var _vibration_check: CheckButton
var _strength_slider: HSlider
var _strength_value: Label
var _deadzone_slider: HSlider
var _deadzone_value: Label
var _assist_timing_check: CheckButton
var _assist_context_check: CheckButton
var _syncing := false

## Called when the menu opens. Defaults to InputFeedback.stop_all_rumble (tests may swap in a spy).
var rumble_stopper: Callable = func() -> void: InputFeedback.stop_all_rumble()


func _ready() -> void:
	add_to_group(GROUP)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_build_ui()
	visible = false
	_connect_signals.call_deferred()


func _connect_signals() -> void:
	InputFeedback.device_disconnected.connect(_on_device_disconnected)
	InputFeedback.device_connected.connect(_on_device_connected)
	SceneRouter.transition_started.connect(_on_transition_started)
	SceneRouter.transition_finished.connect(_on_transition_finished)
	_last_active_device = InputFeedback.active_device


# --------------------------------------------------------------------------- public API

func is_open() -> bool:
	return mode != Mode.CLOSED

## Opens the menu (pausing the tree). Returns false when refused (transition running).
func open(disconnect_mode: bool = false) -> bool:
	if SceneRouter.is_transitioning:
		return false
	if not is_open():
		_paused_before = get_tree().paused
		get_tree().paused = true
		rumble_stopper.call()
		visible = true
		opened.emit()
	if disconnect_mode:
		_show_disconnect()
	else:
		_show_main()
	return true

## Resumes: hides the menu and restores the pause state from before open().
func close() -> void:
	if not is_open():
		return
	_hide_menu()
	if not SceneRouter.is_transitioning:
		get_tree().paused = _paused_before

func toggle() -> void:
	if is_open():
		close()
	else:
		open()

func show_settings() -> void:
	if not is_open():
		return
	mode = Mode.SETTINGS
	_sync_settings_ui()
	_set_page(_settings_box, "Settings")
	_focus_first(_settings_box)

## Back from settings, otherwise resume.
func back() -> void:
	if mode == Mode.SETTINGS:
		_show_main()
		_focus_button(&"settings")
	else:
		close()

## Button lookup for tests: &"resume", &"checkpoint", &"chapter", &"controller_lab", &"settings", &"hub".
func get_button(id: StringName) -> Button:
	return _buttons.get(id, null)

func get_disconnect_text() -> String:
	return _disconnect_label.text


# --------------------------------------------------------------------------- input

func _process(_delta: float) -> void:
	if InputFeedback.active_device >= 0:
		_last_active_device = InputFeedback.active_device


func _input(event: InputEvent) -> void:
	_bridge_pad_to_ui(event)
	if not is_open():
		return
	if mode == Mode.DISCONNECT:
		var key := event as InputEventKey
		var joy := event as InputEventJoypadButton
		if (key and key.pressed and not key.echo) or (joy and joy.pressed and _reconnected):
			get_viewport().set_input_as_handled()
			close()
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() and event.is_action_pressed(&"pause") and not event.is_echo():
		if open():
			get_viewport().set_input_as_handled()


func _bridge_pad_to_ui(event: InputEvent) -> void:
	var jb := event as InputEventJoypadButton
	if jb == null:
		return
	var action := &""
	if jb.button_index == JOY_BUTTON_A:
		action = &"ui_accept"
	elif jb.button_index == JOY_BUTTON_B:
		action = &"ui_cancel"
	else:
		return
	if event.is_action(action) or get_viewport().gui_get_focus_owner() == null:
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = jb.pressed
	Input.parse_input_event(ev)


# --------------------------------------------------------------------------- devices

func _on_device_disconnected(device: int, device_name: String) -> void:
	# _last_active_device is last frame's value: InputFeedback already switched it.
	var was_active: bool = device == _last_active_device or not InputFeedback.has_joypad()
	_last_active_device = InputFeedback.active_device
	if not was_active:
		GameState.notify("Controller disconnected: %s" % _name_or_default(device_name), 2.5)
		return
	var scene := get_tree().current_scene
	if scene and scene.is_in_group(NO_DISCONNECT_PAUSE_GROUP):
		GameState.notify("Controller disconnected: %s" % _name_or_default(device_name), 2.5)
		return
	_reconnected = false
	if SceneRouter.is_transitioning:
		_pending_disconnect = true
		return
	if mode == Mode.MAIN or mode == Mode.SETTINGS:
		_show_disconnect()
	else:
		open(true)


func _on_device_connected(device: int, device_name: String) -> void:
	if mode == Mode.DISCONNECT:
		_reconnected = true
		_disconnect_label.text = "Controller connected:\n%s\n\nPress any button (or Resume) to continue." % _name_or_default(device_name)
		_focus_button(&"disconnect_resume")
	else:
		_pending_disconnect = false
		GameState.notify("Controller connected: %s" % _name_or_default(device_name), 2.5)
	_last_active_device = device if InputFeedback.active_device < 0 else InputFeedback.active_device


func _name_or_default(device_name: String) -> String:
	return device_name if device_name != "" else "Unknown controller"


func _on_transition_started(_path: String, _spawn: StringName) -> void:
	if is_open():
		_hide_menu()


func _on_transition_finished(_path: String) -> void:
	if _pending_disconnect:
		_pending_disconnect = false
		if not InputFeedback.has_joypad():
			open(true)


# --------------------------------------------------------------------------- actions

func _on_resume() -> void:
	close()

func _on_restart_checkpoint() -> void:
	_run_router_action(SceneRouter.respawn_at_checkpoint)

func _on_restart_chapter() -> void:
	_run_router_action(SceneRouter.restart_chapter)

func _on_controller_lab() -> void:
	_run_router_action(func() -> void: SceneRouter.change_scene(CONTROLLER_LAB_PATH))

func _on_hub() -> void:
	_run_router_action(SceneRouter.go_to_hub)

## Hands pause over to SceneRouter; restores it if no transition started.
func _run_router_action(action: Callable) -> void:
	var restore := _paused_before
	_hide_menu()
	action.call()
	if not SceneRouter.is_transitioning:
		get_tree().paused = restore


func _hide_menu() -> void:
	mode = Mode.CLOSED
	visible = false
	var focus := _root.get_viewport().gui_get_focus_owner()
	if focus and _root.is_ancestor_of(focus):
		focus.release_focus()
	closed.emit()


func _is_on_hub() -> bool:
	var scene := get_tree().current_scene
	var main_scene := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	return scene != null and scene.scene_file_path == main_scene


# --------------------------------------------------------------------------- pages

func _show_main() -> void:
	mode = Mode.MAIN
	var on_hub := _is_on_hub()
	for id: StringName in [&"checkpoint", &"chapter", &"hub"]:
		_set_enabled(_buttons[id], not on_hub)
	_set_enabled(_buttons[&"controller_lab"], ResourceLoader.exists(CONTROLLER_LAB_PATH))
	_set_page(_main_box, "Paused")
	_link_focus_ring(_main_box)
	_focus_first(_main_box)


func _show_disconnect() -> void:
	mode = Mode.DISCONNECT
	_disconnect_label.text = "Controller disconnected.\nReconnect it, or press any key\nto continue with keyboard."
	_set_page(_disconnect_box, "Controller")
	_focus_button(&"disconnect_resume")


func _set_page(page: Control, title: String) -> void:
	_title.text = title
	for p: Control in [_main_box, _settings_box, _disconnect_box]:
		p.visible = p == page
	_hint_row.visible = page != _disconnect_box


func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _focus_first(box: Control) -> void:
	for child in box.get_children():
		var c := _focusable_in(child)
		if c:
			c.grab_focus()
			return


func _focus_button(id: StringName) -> void:
	var b: Button = _buttons.get(id, null)
	if b and b.is_visible_in_tree() and not b.disabled:
		b.grab_focus()


func _focusable_in(node: Node) -> Control:
	if node is Control and (node as Control).focus_mode == Control.FOCUS_ALL and (node as Control).visible:
		return node
	for child in node.get_children():
		var c := _focusable_in(child)
		if c:
			return c
	return null


## Vertical wrap-around focus between the focusable controls of a page.
func _link_focus_ring(box: Control) -> void:
	var items: Array[Control] = []
	for child in box.get_children():
		var c := _focusable_in(child)
		if c:
			items.append(c)
	for i in items.size():
		var prev := items[(i - 1 + items.size()) % items.size()]
		var next := items[(i + 1) % items.size()]
		items[i].focus_neighbor_top = items[i].get_path_to(prev)
		items[i].focus_neighbor_bottom = items[i].get_path_to(next)
		items[i].focus_previous = items[i].get_path_to(prev)
		items[i].focus_next = items[i].get_path_to(next)


# --------------------------------------------------------------------------- settings

func _sync_settings_ui() -> void:
	_syncing = true
	_vibration_check.button_pressed = bool(GameState.get_setting(&"vibration_enabled", true))
	_strength_slider.value = float(GameState.get_setting(&"vibration_strength", 1.0))
	_deadzone_slider.value = InputFeedback.get_stick_deadzone()
	_assist_timing_check.button_pressed = bool(GameState.get_setting(&"assist_combat_timing", false))
	_assist_context_check.button_pressed = bool(GameState.get_setting(&"assist_context_actions", false))
	_strength_value.text = "%d%%" % roundi(_strength_slider.value * 100.0)
	_deadzone_value.text = "%.2f" % _deadzone_slider.value
	_syncing = false
	_link_focus_ring(_settings_box)


func _on_vibration_toggled(on: bool) -> void:
	if _syncing:
		return
	GameState.set_setting(&"vibration_enabled", on)
	if on:
		InputFeedback.rumble_preset(&"ui")


func _on_strength_changed(value: float) -> void:
	_strength_value.text = "%d%%" % roundi(value * 100.0)
	if _syncing:
		return
	GameState.set_setting(&"vibration_strength", value)
	InputFeedback.rumble_preset(&"ui")


func _on_deadzone_changed(value: float) -> void:
	_deadzone_value.text = "%.2f" % value
	if _syncing:
		return
	InputFeedback.set_stick_deadzone(value)


func _on_assist_toggled(on: bool, key: StringName) -> void:
	if _syncing:
		return
	GameState.set_setting(key, on)


# --------------------------------------------------------------------------- UI construction

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 4)
	panel.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 14)
	vbox.add_child(_title)

	_main_box = VBoxContainer.new()
	_main_box.name = "Main"
	vbox.add_child(_main_box)
	_add_button(_main_box, &"resume", "Resume", _on_resume)
	_add_button(_main_box, &"checkpoint", "Restart from checkpoint", _on_restart_checkpoint)
	_add_button(_main_box, &"chapter", "Restart chapter", _on_restart_chapter)
	_add_button(_main_box, &"controller_lab", "Controller Lab", _on_controller_lab)
	_add_button(_main_box, &"settings", "Settings", show_settings)
	_add_button(_main_box, &"hub", "Return to hub", _on_hub)

	_settings_box = VBoxContainer.new()
	_settings_box.name = "Settings"
	vbox.add_child(_settings_box)
	_vibration_check = _add_check(_settings_box, "Vibration", _on_vibration_toggled)
	var strength := _add_slider(_settings_box, "Vibration strength", 0.0, 1.0, 0.1, _on_strength_changed)
	_strength_slider = strength[0]
	_strength_value = strength[1]
	var deadzone := _add_slider(_settings_box, "Stick dead-zone", 0.05, 0.6, 0.05, _on_deadzone_changed)
	_deadzone_slider = deadzone[0]
	_deadzone_value = deadzone[1]
	_assist_timing_check = _add_check(_settings_box, "Assist: combat timing",
			_on_assist_toggled.bind(&"assist_combat_timing"))
	_assist_context_check = _add_check(_settings_box, "Assist: context actions (hold)",
			_on_assist_toggled.bind(&"assist_context_actions"))
	_add_button(_settings_box, &"settings_back", "Back", back)

	_disconnect_box = VBoxContainer.new()
	_disconnect_box.name = "Disconnect"
	vbox.add_child(_disconnect_box)
	_disconnect_label = Label.new()
	_disconnect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disconnect_box.add_child(_disconnect_label)
	_add_button(_disconnect_box, &"disconnect_resume", "Resume", _on_resume)

	_hint_row = HBoxContainer.new()
	_hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hint_row.add_theme_constant_override(&"separation", 4)
	vbox.add_child(_hint_row)
	_add_hint(&"jump", "Select")
	_add_hint(&"pause", "Back")


func _add_button(box: Control, id: StringName, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.name = String(id).to_pascal_case()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	box.add_child(b)
	_buttons[id] = b
	return b


func _add_check(box: Control, text: String, callback: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(callback)
	box.add_child(c)
	return c


func _add_slider(box: Control, text: String, min_v: float, max_v: float, step: float, callback: Callable) -> Array:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(110, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(callback)
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size = Vector2(32, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	box.add_child(row)
	return [slider, value]


func _add_hint(action: StringName, text: String) -> void:
	var glyph := ButtonGlyph.new()
	glyph.action = action
	glyph.custom_minimum_size = Vector2(14, 14)
	_hint_row.add_child(glyph)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 9)
	_hint_row.add_child(label)


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 11
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.07, 0.12, 0.95)
	panel.border_color = Color(0.45, 0.4, 0.7)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(4)
	panel.set_content_margin_all(10)
	theme.set_stylebox(&"panel", &"PanelContainer", panel)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1.0, 0.85, 0.3)
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	for type: StringName in [&"Button", &"CheckButton", &"HSlider"]:
		theme.set_stylebox(&"focus", type, focus)
	return theme
