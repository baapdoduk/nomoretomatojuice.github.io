extends Control
## Controller Lab (res://scenes/tests/controller_lab.tscn).
## Shows what the connected pad REALLY reports, so the DS4 mapping can be verified
## on hardware instead of trusting assumed indices: raw buttons 0..JOY_BUTTON_SDL_MAX-1
## (+ any higher index), raw axes, sticks with dead-zone, L2/R2, every gameplay
## action, device info, connection log, vibration / light bar / motion tests and an
## auto-filled support table.
## Pad buttons are being monitored, so lab tests are triggered from the KEYBOARD:
##   Tab next page | 1 weak 2 strong 3 both 4 stop (InputFeedback, honours settings)
##   5 weak 6 strong 7 both 0 stop (raw Input.start_joy_vibration) | L light colour
##   M motion sensors on/off | C motion calibration start/stop | N next device
##   Backspace back to hub (or the pause menu: Esc / Options)

const StickView := preload("res://scripts/tests/controller_lab_stick_view.gd")
const PAGE_NAMES: PackedStringArray = ["Buttons & sticks", "Actions & devices", "Feedback & support"]
const LIGHT_COLORS: Array[Color] = [Color.RED, Color.GREEN, Color.BLUE, Color(1, 0.5, 0), Color.MAGENTA, Color.WHITE]
const MANUAL := "manual (see checklist)"
const RUMBLE_TEST_DURATION := 0.8
const LOG_LINES := 6

var device: int = -1
var page: int = 0

var _header: Label
var _device_label: Label
var _event_label: Label
var _pages: Array[Control] = []
var _button_cells: Array[Label] = []
var _extra_buttons: Label
var _left_stick: Control
var _right_stick: Control
var _stick_text: Label
var _l2_bar: ProgressBar
var _r2_bar: ProgressBar
var _trigger_text: Label
var _axes_text: Label
var _actions_text: Label
var _devices_text: Label
var _log_text: Label
var _feedback_text: Label
var _support_grid: GridContainer

var _event_log: PackedStringArray = []
var _connection_log: PackedStringArray = []
var _light_index := -1
var _touchpad_seen := false
var _last_feedback := "-"


func _ready() -> void:
	add_to_group(PauseMenu.NO_DISCONNECT_PAUSE_GROUP)
	_build_ui()
	InputFeedback.device_connected.connect(_on_connected)
	InputFeedback.device_disconnected.connect(_on_disconnected)
	_pick_device()
	_show_page(0)
	_refresh_support_table()


# --------------------------------------------------------------------------- public helpers (tests)

func get_page_count() -> int:
	return _pages.size()

func get_button_cell_count() -> int:
	return _button_cells.size()

## Rows of the support table: [feature, api_present, device_reports, macos_verification].
func get_support_rows() -> Array:
	var rows: Array = []
	var dev_ok := is_device_connected()
	rows.append(["Vibration", _yn(Input.has_method(&"start_joy_vibration")),
			_dev(dev_ok, _input_bool(&"has_joy_vibration", [device])), MANUAL])
	rows.append(["Light bar colour", _yn(Input.has_method(&"set_joy_light")),
			_dev(dev_ok, _input_bool(&"has_joy_light", [device])), MANUAL])
	rows.append(["Motion (gyro/accel)", _yn(Input.has_method(&"set_joy_motion_sensors_enabled")),
			_dev(dev_ok, _input_bool(&"has_joy_motion_sensors", [device])), MANUAL])
	rows.append(["Motion calibration", _yn(Input.has_method(&"start_joy_motion_sensors_calibration")),
			_dev(dev_ok, _input_bool(&"has_joy_motion_sensors", [device])), MANUAL])
	rows.append(["Touchpad click (btn 20)", "yes",
			("seen" if _touchpad_seen else "press to test") if dev_ok else "-", MANUAL])
	rows.append(["Touchpad coordinates", "no (no API)", "n/a", "not supported"])
	rows.append(["Known SDL mapping", _yn(Input.has_method(&"is_joy_known")),
			_dev(dev_ok, dev_ok and Input.is_joy_known(device)), MANUAL])
	rows.append(["Joy info / GUID", _yn(Input.has_method(&"get_joy_info")),
			_dev(dev_ok, dev_ok and not Input.get_joy_info(device).is_empty()), MANUAL])
	rows.append(["DS4 speaker", "no", "n/a", "out of scope"])
	return rows


func is_device_connected() -> bool:
	return device >= 0 and Input.get_connected_joypads().has(device)


func select_page(index: int) -> void:
	_show_page(index)


# --------------------------------------------------------------------------- devices

func _pick_device() -> void:
	var pads: Array[int] = InputFeedback.get_connected_joypads()
	if pads.has(InputFeedback.active_device):
		device = InputFeedback.active_device
	elif not pads.is_empty():
		device = pads[0]
	else:
		device = -1
	_refresh_support_table()


func _cycle_device() -> void:
	var pads: Array[int] = InputFeedback.get_connected_joypads()
	if pads.is_empty():
		device = -1
	else:
		var i := pads.find(device)
		device = pads[(i + 1) % pads.size()]
	_refresh_support_table()


func _on_connected(dev: int, dev_name: String) -> void:
	_log_connection("%s connected: dev %d %s" % [_time(), dev, dev_name])
	if device < 0:
		device = dev
	_refresh_support_table()


func _on_disconnected(dev: int, dev_name: String) -> void:
	_log_connection("%s disconnected: dev %d %s" % [_time(), dev, dev_name])
	if dev == device:
		_pick_device()
	_refresh_support_table()


func _log_connection(line: String) -> void:
	_connection_log.append(line)
	while _connection_log.size() > LOG_LINES:
		_connection_log.remove_at(0)


# --------------------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	var line := ""
	if event is InputEventJoypadButton:
		var b := event as InputEventJoypadButton
		line = "dev %d button %d (%s) %s" % [b.device, b.button_index, _button_name(b.button_index), "down" if b.pressed else "up"]
		if b.button_index == JOY_BUTTON_TOUCHPAD and b.pressed:
			_touchpad_seen = true
			_refresh_support_table()
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.6:
		var m := event as InputEventJoypadMotion
		line = "dev %d axis %d (%s) %.2f" % [m.device, m.axis, InputFeedback.DS4_AXIS_LABELS.get(m.axis, "?"), m.axis_value]
	if line != "" and (_event_log.is_empty() or _event_log[-1] != line):
		_event_log.append(line)
		while _event_log.size() > 4:
			_event_log.remove_at(0)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var handled := true
	match key.physical_keycode:
		KEY_TAB:
			_show_page((page + 1) % _pages.size())
		KEY_1:
			_feedback("InputFeedback weak", func() -> void: InputFeedback.rumble(1.0, 0.0, RUMBLE_TEST_DURATION, device))
		KEY_2:
			_feedback("InputFeedback strong", func() -> void: InputFeedback.rumble(0.0, 1.0, RUMBLE_TEST_DURATION, device))
		KEY_3:
			_feedback("InputFeedback both", func() -> void: InputFeedback.rumble(1.0, 1.0, RUMBLE_TEST_DURATION, device))
		KEY_4:
			_feedback("InputFeedback stop", InputFeedback.stop_all_rumble)
		KEY_5:
			_feedback("raw weak", func() -> void: Input.start_joy_vibration(device, 1.0, 0.0, RUMBLE_TEST_DURATION))
		KEY_6:
			_feedback("raw strong", func() -> void: Input.start_joy_vibration(device, 0.0, 1.0, RUMBLE_TEST_DURATION))
		KEY_7:
			_feedback("raw both", func() -> void: Input.start_joy_vibration(device, 1.0, 1.0, RUMBLE_TEST_DURATION))
		KEY_0:
			_feedback("raw stop", func() -> void: Input.stop_joy_vibration(device))
		KEY_L:
			_cycle_light()
		KEY_M:
			_toggle_motion()
		KEY_C:
			_toggle_calibration()
		KEY_N:
			_cycle_device()
		KEY_BACKSPACE:
			SceneRouter.go_to_hub()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _feedback(label: String, action: Callable) -> void:
	if not is_device_connected():
		_last_feedback = "%s: no controller connected" % label
		return
	action.call()
	_last_feedback = "%s sent to dev %d" % [label, device]


func _cycle_light() -> void:
	_light_index = (_light_index + 1) % LIGHT_COLORS.size()
	var color := LIGHT_COLORS[_light_index]
	var ok: bool = InputFeedback.set_light_color(color, device) if is_device_connected() else false
	_last_feedback = "light %s: %s" % [color.to_html(false), "sent" if ok else "not supported / no device"]


func _toggle_motion() -> void:
	if not is_device_connected() or not Input.has_method(&"set_joy_motion_sensors_enabled"):
		_last_feedback = "motion: no device / API missing"
		return
	var on := not _input_bool(&"is_joy_motion_sensors_enabled", [device])
	Input.call(&"set_joy_motion_sensors_enabled", device, on)
	_last_feedback = "motion sensors %s (device reports support: %s)" % ["ON" if on else "OFF", _yn(_input_bool(&"has_joy_motion_sensors", [device]))]


func _toggle_calibration() -> void:
	if not is_device_connected() or not Input.has_method(&"start_joy_motion_sensors_calibration"):
		_last_feedback = "calibration: no device / API missing"
		return
	if _input_bool(&"is_joy_motion_sensors_calibrating", [device]):
		Input.call(&"stop_joy_motion_sensors_calibration", device)
		_last_feedback = "calibration stopped (keep pad still while calibrating)"
	else:
		Input.call(&"start_joy_motion_sensors_calibration", device)
		_last_feedback = "calibration started - lay the pad flat, press C again to stop"


# --------------------------------------------------------------------------- per-frame refresh

func _process(_delta: float) -> void:
	var connected := is_device_connected()
	_header.text = "CONTROLLER LAB  -  page %d/%d: %s   [Tab] next page   [Backspace] hub   [N] next device" % [page + 1, _pages.size(), PAGE_NAMES[page]]
	if connected:
		_device_label.text = "Device %d: %s | GUID %s | known mapping: %s | CONNECTED | pads: %s" % [
			device, Input.get_joy_name(device), Input.get_joy_guid(device), _yn(Input.is_joy_known(device)), str(Input.get_connected_joypads())]
	else:
		_device_label.text = "No controller connected - plug in the DS4 (USB) or pair it (Bluetooth). Keyboard still works."
	_event_label.text = "Last raw pad events: " + (" | ".join(_event_log) if not _event_log.is_empty() else "(press something on the pad)")
	match page:
		0: _refresh_input_page(connected)
		1: _refresh_actions_page()
		2: _refresh_feedback_page(connected)


func _refresh_input_page(connected: bool) -> void:
	for i in _button_cells.size():
		var pressed := connected and Input.is_joy_button_pressed(device, i)
		_button_cells[i].modulate = Color(1.0, 0.9, 0.3) if pressed else Color(0.55, 0.55, 0.65)
	var extra: PackedStringArray = []
	if connected:
		for i in range(JOY_BUTTON_SDL_MAX, JOY_BUTTON_MAX):
			if Input.is_joy_button_pressed(device, i):
				extra.append(str(i))
	_extra_buttons.text = "Other pressed indices (>= %d): %s" % [JOY_BUTTON_SDL_MAX, ", ".join(extra) if not extra.is_empty() else "none"]
	var dz: float = InputFeedback.get_stick_deadzone()
	var lraw := _axis_pair(connected, JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var rraw := _axis_pair(connected, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
	var lproc := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var rproc: Vector2 = StickView.apply_radial_deadzone(rraw, dz)
	_left_stick.set(&"raw", lraw)
	_left_stick.set(&"processed", lproc)
	_left_stick.set(&"deadzone", dz)
	_right_stick.set(&"raw", rraw)
	_right_stick.set(&"processed", rproc)
	_right_stick.set(&"deadzone", dz)
	_stick_text.text = "Dead-zone %.2f (pause menu > Settings)\nL raw (%.2f, %.2f)\nL get_vector (%.2f, %.2f)\nR raw (%.2f, %.2f)\nR processed (%.2f, %.2f)" % [
		dz, lraw.x, lraw.y, lproc.x, lproc.y, rraw.x, rraw.y, rproc.x, rproc.y]
	var l2 := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) if connected else 0.0
	var r2 := Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) if connected else 0.0
	_l2_bar.value = l2
	_r2_bar.value = r2
	_trigger_text.text = "L2 raw %.2f  context_left %.2f\nR2 raw %.2f  context_right %.2f" % [
		l2, Input.get_action_strength(&"context_left"), r2, Input.get_action_strength(&"context_right")]
	var axes: PackedStringArray = []
	for a in JOY_AXIS_MAX:
		axes.append("a%d %+.2f" % [a, Input.get_joy_axis(device, a) if connected else 0.0])
	_axes_text.text = "Raw axes: " + "  ".join(axes)


func _refresh_actions_page() -> void:
	var lines: PackedStringArray = ["ACTION            PRESSED  STRENGTH"]
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		lines.append("%-17s %-8s %.2f" % [action, "YES" if Input.is_action_pressed(action) else "-", Input.get_action_strength(action)])
	_actions_text.text = "\n".join(lines)
	var dev_lines: PackedStringArray = ["CONNECTED DEVICES (monitored: %d)" % device]
	for d in Input.get_connected_joypads():
		dev_lines.append("dev %d: %s" % [d, Input.get_joy_name(d)])
		dev_lines.append("  GUID %s  known: %s" % [Input.get_joy_guid(d), _yn(Input.is_joy_known(d))])
		var info := Input.get_joy_info(d)
		for k in info:
			dev_lines.append("  %s: %s" % [k, str(info[k])])
	if Input.get_connected_joypads().is_empty():
		dev_lines.append("(none)")
	_devices_text.text = "\n".join(dev_lines)
	_log_text.text = "CONNECTION LOG\n" + ("\n".join(_connection_log) if not _connection_log.is_empty() else "(no connect/disconnect events yet)")


func _refresh_feedback_page(connected: bool) -> void:
	var lines: PackedStringArray = []
	lines.append("KEYS: 1 weak  2 strong  3 both  4 stop  (InputFeedback: vibration %s, strength %d%%)" % [
		"ON" if GameState.get_setting(&"vibration_enabled", true) else "OFF", roundi(float(GameState.get_setting(&"vibration_strength", 1.0)) * 100.0)])
	lines.append("      5 weak  6 strong  7 both  0 stop  (raw Input API, ignores settings)   L light   M motion   C calibrate")
	lines.append("Last test: " + _last_feedback)
	if connected:
		var vib := "vibrating: %s  weak/strong %s" % [_yn(_input_bool(&"is_joy_vibrating", [device])), str(Input.get_joy_vibration_strength(device))]
		lines.append(vib)
		var touch := Input.is_joy_button_pressed(device, JOY_BUTTON_TOUCHPAD)
		lines.append("Touchpad click: %s%s" % ["PRESSED" if touch else "-", "  (seen)" if _touchpad_seen else ""])
		if Input.has_method(&"get_joy_gyroscope"):
			var on := _input_bool(&"is_joy_motion_sensors_enabled", [device])
			lines.append("Motion: enabled %s  calibrating %s  calibrated %s" % [_yn(on),
					_yn(_input_bool(&"is_joy_motion_sensors_calibrating", [device])), _yn(_input_bool(&"is_joy_motion_sensors_calibrated", [device]))])
			var gyro: Vector3 = Input.call(&"get_joy_gyroscope", device)
			var accel: Vector3 = Input.call(&"get_joy_accelerometer", device)
			var grav: Vector3 = Input.call(&"get_joy_gravity", device)
			lines.append("  gyro %s  accel %s  gravity %s" % [_v3(gyro), _v3(accel), _v3(grav)])
		else:
			lines.append("Motion: API not present in this Godot build")
	else:
		lines.append("(connect a controller to run feedback / sensor tests)")
	_feedback_text.text = "\n".join(lines)


func _refresh_support_table() -> void:
	if _support_grid == null:
		return
	for child in _support_grid.get_children():
		child.queue_free()
	for header: String in ["FEATURE", "API IN BUILD", "DEVICE REPORTS", "macOS HW CHECK"]:
		_support_grid.add_child(_cell(header, Color(0.9, 0.8, 0.4)))
	for row: Array in get_support_rows():
		for value: String in row:
			_support_grid.add_child(_cell(value, Color(0.85, 0.85, 0.95)))


# --------------------------------------------------------------------------- helpers

func _show_page(index: int) -> void:
	page = clampi(index, 0, _pages.size() - 1)
	for i in _pages.size():
		_pages[i].visible = i == page
	if page == 2:
		_refresh_support_table()


func _axis_pair(connected: bool, ax: JoyAxis, ay: JoyAxis) -> Vector2:
	if not connected:
		return Vector2.ZERO
	return Vector2(Input.get_joy_axis(device, ax), Input.get_joy_axis(device, ay))


func _input_bool(method: StringName, args: Array) -> bool:
	if not Input.has_method(method) or (args.size() > 0 and not Input.get_connected_joypads().has(int(args[0]))):
		return false
	return bool(Input.callv(method, args))


func _button_name(index: int) -> String:
	return InputFeedback.DS4_BUTTON_LABELS.get(index, _extra_button_name(index))


func _extra_button_name(index: int) -> String:
	match index:
		JOY_BUTTON_MISC1: return "Misc1"
		JOY_BUTTON_PADDLE1: return "Paddle1"
		JOY_BUTTON_PADDLE2: return "Paddle2"
		JOY_BUTTON_PADDLE3: return "Paddle3"
		JOY_BUTTON_PADDLE4: return "Paddle4"
	return "-"


func _yn(v: bool) -> String:
	return "yes" if v else "no"


func _dev(has_device: bool, v: bool) -> String:
	return _yn(v) if has_device else "- (no device)"


func _v3(v: Vector3) -> String:
	return "(%+.2f %+.2f %+.2f)" % [v.x, v.y, v.z]


func _time() -> String:
	return "%.1fs" % (Time.get_ticks_msec() / 1000.0)


func _cell(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = color
	return l


# --------------------------------------------------------------------------- UI construction

func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	var t := Theme.new()
	t.default_font_size = 8
	theme = t

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override(&"separation", 2)
	margin.add_child(root)

	_header = Label.new()
	_header.add_theme_font_size_override(&"font_size", 10)
	_header.modulate = Color(1.0, 0.85, 0.4)
	root.add_child(_header)
	_device_label = Label.new()
	_device_label.clip_text = true
	root.add_child(_device_label)
	_event_label = Label.new()
	_event_label.clip_text = true
	_event_label.modulate = Color(0.7, 0.9, 1.0)
	root.add_child(_event_label)
	root.add_child(HSeparator.new())

	_pages.append(_build_input_page(root))
	_pages.append(_build_actions_page(root))
	_pages.append(_build_feedback_page(root))


func _build_input_page(parent: Control) -> Control:
	var page_box := VBoxContainer.new()
	page_box.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(page_box)
	var title := Label.new()
	title.text = "RAW BUTTONS (index + assumed DS4 name; lights up while held - verify each one)"
	page_box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override(&"h_separation", 4)
	page_box.add_child(grid)
	for i in JOY_BUTTON_SDL_MAX:
		var cell := Label.new()
		cell.text = "%2d %s" % [i, _button_name(i)]
		cell.custom_minimum_size = Vector2(84, 0)
		grid.add_child(cell)
		_button_cells.append(cell)
	_extra_buttons = Label.new()
	page_box.add_child(_extra_buttons)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	page_box.add_child(row)
	_left_stick = _add_stick(row, "L-Stick")
	_right_stick = _add_stick(row, "R-Stick")
	_stick_text = Label.new()
	_stick_text.custom_minimum_size = Vector2(150, 0)
	row.add_child(_stick_text)

	var trig := VBoxContainer.new()
	trig.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(trig)
	_l2_bar = _add_bar(trig, "L2")
	_r2_bar = _add_bar(trig, "R2")
	_trigger_text = Label.new()
	trig.add_child(_trigger_text)

	_axes_text = Label.new()
	_axes_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page_box.add_child(_axes_text)
	return page_box


func _add_stick(parent: Control, title: String) -> Control:
	var box := VBoxContainer.new()
	parent.add_child(box)
	var l := Label.new()
	l.text = title
	box.add_child(l)
	var view: Control = StickView.new()
	view.set(&"title", title)
	view.custom_minimum_size = Vector2(72, 72)
	box.add_child(view)
	return view


func _add_bar(parent: Control, title: String) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(16, 0)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 8)
	bar.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(bar)
	return bar


func _build_actions_page(parent: Control) -> Control:
	var page_box := HBoxContainer.new()
	page_box.size_flags_vertical = SIZE_EXPAND_FILL
	page_box.add_theme_constant_override(&"separation", 16)
	parent.add_child(page_box)
	_actions_text = Label.new()
	_actions_text.custom_minimum_size = Vector2(180, 0)
	page_box.add_child(_actions_text)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	page_box.add_child(right)
	_devices_text = Label.new()
	_devices_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	right.add_child(_devices_text)
	right.add_child(HSeparator.new())
	_log_text = Label.new()
	right.add_child(_log_text)
	return page_box


func _build_feedback_page(parent: Control) -> Control:
	var page_box := VBoxContainer.new()
	page_box.size_flags_vertical = SIZE_EXPAND_FILL
	parent.add_child(page_box)
	_feedback_text = Label.new()
	page_box.add_child(_feedback_text)
	page_box.add_child(HSeparator.new())
	var title := Label.new()
	title.text = "SUPPORT TABLE (auto-filled; hardware column is verified manually with docs/HARDWARE_CHECKLIST.md)"
	page_box.add_child(title)
	_support_grid = GridContainer.new()
	_support_grid.columns = 4
	_support_grid.add_theme_constant_override(&"h_separation", 14)
	page_box.add_child(_support_grid)
	return page_box
