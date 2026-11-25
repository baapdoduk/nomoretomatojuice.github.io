class_name PuzzleDevice
extends Node2D
## Base for boolean puzzle devices (switch, pressure plate, receiver, controller...).
##
## "Puzzle input contract" (duck-typed, so non-PuzzleDevice nodes can join):
##   signal activated_changed(active: bool)
##   func is_active() -> bool
## Outputs (Gate, PuzzleController, StateDriven nodes) accept any node that
## satisfies it via exported Array[Node] references - no hard-coded paths.
##
## Persistence: if persist_flag is set, the state is written to that GameState
## flag and restored in _ready (re-entering a scene keeps solved states).
## Without it, the device resets whenever its scene reloads.

signal activated_changed(active: bool)

@export var persist_flag: StringName = &""
@export var start_active: bool = false

var active: bool = false


func _ready() -> void:
	var initial := start_active
	if persist_flag != &"" and GameState.has_flag(persist_flag):
		initial = bool(GameState.get_flag(persist_flag))
	active = initial
	_apply_state(active, true)


func is_active() -> bool:
	return active

func set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	if persist_flag != &"":
		GameState.set_flag(persist_flag, value)
	_apply_state(value, false)
	activated_changed.emit(value)

## Return to the initial state (also clears the persist flag).
func reset() -> void:
	if persist_flag != &"":
		GameState.clear_flag(persist_flag)
	set_active(start_active)

## Override for visuals / collision. `instant` = called from _ready (no tweens/sfx).
func _apply_state(_value: bool, _instant: bool) -> void:
	pass
