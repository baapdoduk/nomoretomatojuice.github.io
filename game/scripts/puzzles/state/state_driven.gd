class_name StateDriven
extends Node2D
## Map-wide state transitions without simulation: a node subtree that is "on" when
## the int GameState flag `state_flag` (missing = `default_value`) is one of
## `active_values`. Visuals AND every collision shape below this node switch
## together (shapes are toggled deferred, so changes are safe from any callback).
##
## Typical uses: water level 0/1/2 (one StateDriven per level, each with its own
## water visual / raised platform / hazard area), power on/off, parallel-world
## layers (layer A active for [0], layer B for [1]).
##
## Changing the value is the job of StateLever, which validates first with
## StateDriven.find_blockers() so a newly enabled collider never traps the player
## or a pushable. Raw GameState.set_flag() changes are applied unvalidated.
## Every change notifies the light system (state can block / unblock beams).

enum InactiveDisplay {
	HIDE,  ## Hidden while inactive.
	GHOST, ## Drawn with `ghost_modulate` while inactive (parallel world preview).
}

const GROUP := &"state_driven"

signal state_applied(enabled: bool)

@export var state_flag: StringName = &""
@export var default_value: int = 0
@export var active_values: Array[int] = [1]
@export var inactive_display: InactiveDisplay = InactiveDisplay.HIDE
@export var ghost_modulate: Color = Color(1, 1, 1, 0.25)

var is_enabled: bool = false

var _shapes: Array[Node] = []
var _base_modulate := Color.WHITE
var _applied_once := false


func _ready() -> void:
	add_to_group(GROUP)
	_base_modulate = modulate
	_shapes = PuzzlePhysics.collect_all_shapes(self)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_restored.connect(_apply)
	_apply()


## Current value of the driving flag.
func get_state_value() -> int:
	return int(GameState.get_flag(state_flag, default_value))

## Whether this node is on for `value`.
func is_enabled_for(value: int) -> bool:
	return active_values.has(value)

## Solid shapes that would become enabled when the flag changes to `value`.
func get_shapes_enabled_by(value: int) -> Array[Node]:
	var out: Array[Node] = []
	if is_enabled or not is_enabled_for(value):
		return out
	for s in _shapes:
		if is_instance_valid(s) and s.get_parent() is PhysicsBody2D:
			out.append(s)
	return out

## Protected bodies (player / pushables) that this node's colliders would overlap
## after switching to `value`. Needs the space state (physics frame).
func find_blockers_for(value: int) -> Array[Node]:
	return PuzzlePhysics.find_blockers_for_shapes(PuzzlePhysics.space_of(self), get_shapes_enabled_by(value))


## All protected bodies that a change of `flag` to `value` would trap, across every
## StateDriven node in the tree listening to `flag`.
static func find_blockers(tree: SceneTree, flag: StringName, value: int) -> Array[Node]:
	var out: Array[Node] = []
	for node in tree.get_nodes_in_group(GROUP):
		var sd := node as StateDriven
		if sd == null or sd.state_flag != flag:
			continue
		for b in sd.find_blockers_for(value):
			if not out.has(b):
				out.append(b)
	return out


func _apply() -> void:
	var on := is_enabled_for(get_state_value())
	if _applied_once and on == is_enabled:
		return
	_applied_once = true
	is_enabled = on
	PuzzlePhysics.set_shapes_enabled(_shapes, on)
	if on:
		visible = true
		modulate = _base_modulate
	elif inactive_display == InactiveDisplay.GHOST:
		visible = true
		modulate = _base_modulate * ghost_modulate
	else:
		visible = false
	state_applied.emit(on)
	if is_inside_tree():
		LightTracer.notify_changed(get_tree())


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag == state_flag:
		_apply()
