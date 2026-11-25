class_name PlayerInputState
extends RefCounted
## Player input for one physics frame. Gathered once by Player and passed to
## the motor, melee and Interactor so every system sees the same values.
##
## Tests drive the player with Player.set_input_override(state): "held" fields
## persist until changed, "*_pressed" (just-pressed) fields are consumed
## (reset to false) after the player has read them once.

## Movement vector (dead-zone already applied), length <= 1.
var move: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var jump_held: bool = false
var dash_pressed: bool = false
var attack_pressed: bool = false
var interact_pressed: bool = false
var interact_held: bool = false


## Reads the Input singleton (call from _physics_process).
static func from_input() -> PlayerInputState:
	var s := PlayerInputState.new()
	s.move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	s.jump_pressed = Input.is_action_just_pressed(&"jump")
	s.jump_held = Input.is_action_pressed(&"jump")
	s.dash_pressed = Input.is_action_just_pressed(&"dash")
	s.attack_pressed = Input.is_action_just_pressed(&"attack")
	s.interact_pressed = Input.is_action_just_pressed(&"interact")
	s.interact_held = Input.is_action_pressed(&"interact")
	return s


## Copy of this state (used to hand overrides to the systems without mutation).
func copy() -> PlayerInputState:
	var s := PlayerInputState.new()
	s.move = move
	s.jump_pressed = jump_pressed
	s.jump_held = jump_held
	s.dash_pressed = dash_pressed
	s.attack_pressed = attack_pressed
	s.interact_pressed = interact_pressed
	s.interact_held = interact_held
	return s


## Clears the one-frame "pressed" edges.
func consume_presses() -> void:
	jump_pressed = false
	dash_pressed = false
	attack_pressed = false
	interact_pressed = false
