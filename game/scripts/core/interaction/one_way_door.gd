class_name OneWayDoor
extends Interactable
## Shortcut / loop-back door. A StaticBody2D child ("Blocker", layer World)
## blocks passage until the door is opened, which is only possible from
## `open_side` (direction from the door to the player, in the door's local
## space). From the wrong side it shows `wrong_side_prompt` and refuses.
## Once opened, `open_flag` is set in GameState so it stays open on re-entry.
## Also satisfies the puzzle input contract (activated_changed / is_active).

signal opened
signal activated_changed(active: bool)

## Side the player must stand on to open it (local space, e.g. Vector2.RIGHT).
@export var open_side: Vector2 = Vector2.RIGHT
## GameState flag that persists the open state (e.g. &"door.lab_shortcut.open").
@export var open_flag: StringName = &""
@export var wrong_side_prompt: String = "Locked from this side"
@export var wrong_side_message: String = "It won't open from this side."
@export var opened_message: String = "Shortcut opened"
## Blocking body (auto-found child StaticBody2D when empty).
@export var blocker: StaticBody2D

var is_open: bool = false
var _last_actor: Node2D = null


func _init() -> void:
	super._init()
	prompt_text = "Open"


func _ready() -> void:
	if blocker == null:
		for child in get_children():
			if child is StaticBody2D:
				blocker = child
				break
	if open_flag != &"" and GameState.has_flag(open_flag):
		_set_open(true, true)


func is_active() -> bool:
	return is_open

## True when `actor` stands on the side the door opens from.
func is_on_open_side(actor: Node2D) -> bool:
	if actor == null:
		return false
	var to_actor := actor.global_position - global_position
	var side := open_side.rotated(global_rotation).normalized()
	return to_actor.dot(side) > 0.0

func get_prompt_text() -> String:
	if _last_actor and is_instance_valid(_last_actor) and not is_on_open_side(_last_actor):
		return wrong_side_prompt
	return super.get_prompt_text()

## Opens the door (ignores the side rule; for scripts / puzzles).
func open() -> void:
	_set_open(true, false)


func _can_interact(actor: Node) -> bool:
	_last_actor = actor as Node2D
	return not is_open


func _perform(actor: Node) -> void:
	if not is_on_open_side(actor as Node2D):
		if wrong_side_message != "":
			GameState.notify(wrong_side_message)
		return
	_set_open(true, false)
	if opened_message != "":
		GameState.notify(opened_message)


func _set_open(value: bool, instant: bool) -> void:
	if value == is_open:
		return
	is_open = value
	if blocker:
		for child in blocker.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred(&"disabled", value)
	if value and open_flag != &"":
		GameState.set_flag(open_flag, true)
	if value:
		opened.emit()
	if not instant:
		activated_changed.emit(value)
