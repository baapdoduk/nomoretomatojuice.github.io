extends Node
## InputFeedback (autoload scene: res://scenes/core/autoload/input_feedback.tscn)
##
## Owns: joypad connection tracking, last-used input kind (for button prompts),
## vibration (rumble), stick dead-zone setting, optional DS4 extras (light bar,
## motion sensors) behind capability checks. Every hardware call fails silently
## when unsupported, so gameplay never depends on it.
## The PauseMenu UI is a child of this autoload scene (owned by the UI module).

signal device_connected(device: int, device_name: String)
signal device_disconnected(device: int, device_name: String)
## &"keyboard" or &"joypad" — prompts re-draw on this.
signal input_kind_changed(kind: StringName)

const KIND_KEYBOARD := &"keyboard"
const KIND_JOYPAD := &"joypad"
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const AXIS_ACTIVITY_THRESHOLD := 0.5

## Rumble presets: [weak_magnitude, strong_magnitude, duration_seconds].
const RUMBLE_PRESETS := {
	&"ui": [0.25, 0.0, 0.06],
	&"light": [0.45, 0.1, 0.10],
	&"medium": [0.6, 0.45, 0.16],
	&"heavy": [0.8, 1.0, 0.30],
	&"player_hurt": [0.7, 0.8, 0.25],
	&"hit_confirm": [0.5, 0.2, 0.08],
	&"boss_slam": [0.4, 0.9, 0.35],
}

## DS4 names for Godot's SDL-standard joypad buttons.
const DS4_BUTTON_LABELS := {
	JOY_BUTTON_A: "Cross", JOY_BUTTON_B: "Circle", JOY_BUTTON_X: "Square", JOY_BUTTON_Y: "Triangle",
	JOY_BUTTON_BACK: "Share", JOY_BUTTON_GUIDE: "PS", JOY_BUTTON_START: "Options",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1",
	JOY_BUTTON_DPAD_UP: "D-Up", JOY_BUTTON_DPAD_DOWN: "D-Down",
	JOY_BUTTON_DPAD_LEFT: "D-Left", JOY_BUTTON_DPAD_RIGHT: "D-Right",
	JOY_BUTTON_TOUCHPAD: "Touchpad",
}
const DS4_AXIS_LABELS := {
	JOY_AXIS_LEFT_X: "L-Stick", JOY_AXIS_LEFT_Y: "L-Stick",
	JOY_AXIS_RIGHT_X: "R-Stick", JOY_AXIS_RIGHT_Y: "R-Stick",
	JOY_AXIS_TRIGGER_LEFT: "L2", JOY_AXIS_TRIGGER_RIGHT: "R2",
}

var last_input_kind: StringName = KIND_KEYBOARD
## Last joypad that produced input (-1 = none yet).
var active_device: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if not get_connected_joypads().is_empty():
		active_device = get_connected_joypads()[0]
	set_stick_deadzone(float(GameState.get_setting(&"stick_deadzone", 0.2)))


func _input(event: InputEvent) -> void:
	var kind := last_input_kind
	if event is InputEventJoypadButton and event.pressed:
		kind = KIND_JOYPAD
		active_device = event.device
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= AXIS_ACTIVITY_THRESHOLD:
		kind = KIND_JOYPAD
		active_device = event.device
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		kind = KIND_KEYBOARD
	if kind != last_input_kind:
		last_input_kind = kind
		input_kind_changed.emit(kind)


# --------------------------------------------------------------------------- devices

func get_connected_joypads() -> Array[int]:
	var out: Array[int] = []
	out.assign(Input.get_connected_joypads())
	return out

func has_joypad() -> bool:
	return not Input.get_connected_joypads().is_empty()

func get_device_name(device: int) -> String:
	return Input.get_joy_name(device)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	var device_name := Input.get_joy_name(device)
	if connected:
		if active_device < 0:
			active_device = device
		device_connected.emit(device, device_name)
	else:
		_safe_stop(device)
		if active_device == device:
			var remaining := get_connected_joypads()
			active_device = remaining[0] if not remaining.is_empty() else -1
			if active_device < 0 and last_input_kind == KIND_JOYPAD:
				last_input_kind = KIND_KEYBOARD
				input_kind_changed.emit(last_input_kind)
		device_disconnected.emit(device, device_name)


# --------------------------------------------------------------------------- rumble

## Starts vibration. device = -1 targets the active joypad (or all connected).
## Silently does nothing when disabled in settings or unsupported by the device.
func rumble(weak: float, strong: float, duration: float, device: int = -1) -> void:
	if not bool(GameState.get_setting(&"vibration_enabled", true)):
		return
	var scale := clampf(float(GameState.get_setting(&"vibration_strength", 1.0)), 0.0, 1.0)
	for d in _target_devices(device):
		Input.start_joy_vibration(d, clampf(weak * scale, 0.0, 1.0), clampf(strong * scale, 0.0, 1.0), duration)

func rumble_preset(preset: StringName, device: int = -1) -> void:
	if not RUMBLE_PRESETS.has(preset):
		push_warning("InputFeedback: unknown rumble preset %s" % preset)
		return
	var p: Array = RUMBLE_PRESETS[preset]
	rumble(p[0], p[1], p[2], device)

## Called on scene transitions, pause and disconnects.
func stop_all_rumble() -> void:
	for d in Input.get_connected_joypads():
		_safe_stop(d)

func _safe_stop(device: int) -> void:
	Input.stop_joy_vibration(device)

func _target_devices(device: int) -> Array[int]:
	if device >= 0:
		return [device]
	if active_device >= 0 and Input.get_connected_joypads().has(active_device):
		return [active_device]
	return get_connected_joypads()


# --------------------------------------------------------------------------- settings

func set_stick_deadzone(value: float) -> void:
	value = clampf(value, 0.0, 0.9)
	for action in MOVE_ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, value)
	if not is_equal_approx(float(GameState.get_setting(&"stick_deadzone", -1.0)), value):
		GameState.set_setting(&"stick_deadzone", value)

func get_stick_deadzone() -> float:
	return float(GameState.get_setting(&"stick_deadzone", 0.2))


# --------------------------------------------------------------------------- prompts

## Describes how to show `action` for the given (or current) input kind:
## { "kind": KIND_*, "label": String, "joy_button": int, "joy_axis": int, "key": int }
## Joypad labels use DS4 names ("Triangle", "L2", ...); keyboard labels use key names ("E").
func get_action_glyph(action: StringName, kind: StringName = &"") -> Dictionary:
	if kind == &"":
		kind = last_input_kind
	var info := {"kind": kind, "label": String(action), "joy_button": -1, "joy_axis": -1, "key": -1}
	if not InputMap.has_action(action):
		return info
	for event in InputMap.action_get_events(action):
		if kind == KIND_JOYPAD and event is InputEventJoypadButton:
			info.joy_button = event.button_index
			info.label = DS4_BUTTON_LABELS.get(event.button_index, "B%d" % event.button_index)
			return info
		if kind == KIND_JOYPAD and event is InputEventJoypadMotion:
			info.joy_axis = event.axis
			info.label = DS4_AXIS_LABELS.get(event.axis, "Axis%d" % event.axis)
			return info
		if kind == KIND_KEYBOARD and event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			info.key = code
			info.label = OS.get_keycode_string(code)
			return info
	return info


# --------------------------------------------------------------------------- DS4 extras (P2)

## Capability query. feature: &"vibration", &"light", &"motion".
## Uses has_method() so the project still runs on Godot builds without these APIs.
func supports_feature(feature: StringName, device: int = -1) -> bool:
	if device < 0:
		device = active_device
	if device < 0:
		return false
	match feature:
		&"vibration":
			return Input.has_method(&"has_joy_vibration") and Input.call(&"has_joy_vibration", device)
		&"light":
			return Input.has_method(&"has_joy_light") and Input.call(&"has_joy_light", device)
		&"motion":
			return Input.has_method(&"has_joy_motion_sensors") and Input.call(&"has_joy_motion_sensors", device)
	return false

## Sets the DS4 light bar if supported. Returns true when the call was made.
func set_light_color(color: Color, device: int = -1) -> bool:
	if device < 0:
		device = active_device
	if not supports_feature(&"light", device):
		return false
	Input.call(&"set_joy_light", device, color)
	return true
