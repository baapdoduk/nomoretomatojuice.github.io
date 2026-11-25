extends SceneTree
## Regenerates the project's Input Map (project.godot [input] section).
## Run:  godot --headless --path game --script res://tools/gen_input_map.gd
## Edit the ACTIONS table below (or edit Project Settings > Input Map in the editor).
## Joypad indices use Godot's SDL-standard layout (device-agnostic):
##   JOY_BUTTON_A = DS4 Cross, B = Circle, X = Square, Y = Triangle, START = Options.
## Verify on real hardware with ControllerLab (shows raw indices per press).

const STICK_DEADZONE := 0.2
const BUTTON_DEADZONE := 0.5
const TRIGGER_DEADZONE := 0.05

func _key(physical: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1  # all devices, like editor-created events
	e.physical_keycode = physical
	return e

func _btn(index: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = index
	return e

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e

func _init() -> void:
	var actions := {
		"move_left": [STICK_DEADZONE, [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0), _btn(JOY_BUTTON_DPAD_LEFT)]],
		"move_right": [STICK_DEADZONE, [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0), _btn(JOY_BUTTON_DPAD_RIGHT)]],
		"move_up": [STICK_DEADZONE, [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _btn(JOY_BUTTON_DPAD_UP)]],
		"move_down": [STICK_DEADZONE, [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _btn(JOY_BUTTON_DPAD_DOWN)]],
		"jump": [BUTTON_DEADZONE, [_key(KEY_SPACE), _btn(JOY_BUTTON_A)]],
		"dash": [BUTTON_DEADZONE, [_key(KEY_SHIFT), _btn(JOY_BUTTON_B)]],
		"attack": [BUTTON_DEADZONE, [_key(KEY_J), _btn(JOY_BUTTON_X)]],
		"interact": [BUTTON_DEADZONE, [_key(KEY_E), _btn(JOY_BUTTON_Y)]],
		"context_left": [TRIGGER_DEADZONE, [_key(KEY_Q), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)]],
		"context_right": [TRIGGER_DEADZONE, [_key(KEY_R), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)]],
		"pause": [BUTTON_DEADZONE, [_key(KEY_ESCAPE), _btn(JOY_BUTTON_START)]],
	}
	for action_name: String in actions:
		var entry: Array = actions[action_name]
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": entry[0], "events": entry[1]})
	var err := ProjectSettings.save()
	print("Input map written: ", error_string(err))
	quit(0 if err == OK else 1)
