class_name StateLever
extends Node2D
## Changes a map-wide int state (GameState flag) - e.g. water level or power -
## through a child Interactable, but only after validating that no collider the
## change would enable overlaps the player or a pushable (StateDriven.find_blockers).
## A refused change shows `blocked_message` via GameState.notify and emits
## change_refused; nothing changes, so the player can move and retry.
##
## Modes: CYCLE steps through `cycle_values`; SET always requests `target_value`.
## Also satisfies the puzzle input contract (active = value != default_value).

enum Mode { CYCLE, SET }

signal value_changed(value: int)
signal change_refused(value: int, blockers: Array[Node])
signal activated_changed(active: bool)

@export var state_flag: StringName = &""
@export var default_value: int = 0
@export var mode: Mode = Mode.CYCLE
@export var cycle_values: Array[int] = [0, 1]
@export var target_value: int = 1
@export var blocked_message: String = "Something is in the way - the change is blocked."
## Interactable that pulls the lever (optional; auto-found/created).
@export var interactable: Interactable

var _was_active := false
var _pending_reset := false


func _ready() -> void:
	interactable = PuzzlePhysics.ensure_interactable(self, interactable, "Pull")
	interactable.interacted.connect(_on_interacted)
	_was_active = is_active()
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_restored.connect(_emit_if_changed)
	set_physics_process(false)


func is_active() -> bool:
	return get_value() != default_value


func get_value() -> int:
	return int(GameState.get_flag(state_flag, default_value))

## The value the next use would request.
func get_next_value() -> int:
	if mode == Mode.SET or cycle_values.is_empty():
		return target_value
	var i := cycle_values.find(get_value())
	return cycle_values[(i + 1) % cycle_values.size()]

## Protected bodies that block changing to `value` (empty = allowed). Physics frame only.
func get_blockers(value: int) -> Array[Node]:
	return StateDriven.find_blockers(get_tree(), state_flag, value)

func can_apply(value: int) -> bool:
	return get_blockers(value).is_empty()

## Validates and applies `value`. Returns true on success (or no-op). Physics frame only.
func request_value(value: int) -> bool:
	if value == get_value():
		return true
	var blockers := get_blockers(value)
	if not blockers.is_empty():
		if blocked_message != "":
			GameState.notify(blocked_message)
		change_refused.emit(value, blockers)
		return false
	GameState.set_flag(state_flag, value)
	value_changed.emit(value)
	return true

## Requests get_next_value(). Physics frame only.
func request_next() -> bool:
	return request_value(get_next_value())

## Back to `default_value` on the next physics frame. Validated like any change:
## while blocked it keeps retrying silently until the change is safe.
func reset() -> void:
	_pending_reset = true
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not _pending_reset:
		set_physics_process(false)
		return
	if get_value() == default_value or can_apply(default_value):
		GameState.set_flag(state_flag, default_value)
		_pending_reset = false
		set_physics_process(false)


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag == state_flag:
		_emit_if_changed()


func _emit_if_changed() -> void:
	var now := is_active()
	if now != _was_active:
		_was_active = now
		activated_changed.emit(now)


func _on_interacted(_actor: Node) -> void:
	# Space queries need a physics frame; physics_frame also fires while the tree
	# is paused (pause menu / transitions), so hold until gameplay runs again.
	await get_tree().physics_frame
	while is_instance_valid(self) and is_inside_tree() and get_tree().paused:
		await get_tree().physics_frame
	if is_instance_valid(self) and is_inside_tree():
		request_next()
