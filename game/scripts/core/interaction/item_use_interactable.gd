class_name ItemUseInteractable
extends Interactable
## "Use item here" spot (keyhole, offering, missing part). Needs the base
## `required_item` (optionally consumed via consume_required_item). On success
## it sets `success_flag`, emits `used` and becomes active.
## Puzzle input contract: activated_changed(active) + is_active().
## Restores its used state from success_flag on scene load.

signal used(item_id: StringName)
signal activated_changed(active: bool)

## GameState flag set on success (also restores the state on reload).
@export var success_flag: StringName = &""
@export var success_message: String = ""

var _active: bool = false


func _init() -> void:
	super._init()
	prompt_text = "Use"
	one_shot = true


func _ready() -> void:
	if success_flag == &"" and consume_required_item and required_item != &"":
		# A consumed item without persistence would soft-lock after a reload.
		success_flag = InteractionUtils.derive_flag(self, "success_flag")
	if success_flag != &"" and GameState.has_flag(success_flag):
		has_been_used = true
		_active = true
		_on_restored()


func is_active() -> bool:
	return _active


func _perform(_actor: Node) -> void:
	_active = true
	if success_flag != &"":
		GameState.set_flag(success_flag, true)
	GameState.commit_progress()  # milestone: item spent + effect committed together
	if success_message != "":
		GameState.notify(success_message)
	used.emit(required_item)
	activated_changed.emit(true)
	_on_used()


## Override hooks for subclasses (e.g. LockedDoor removes its blocker).
func _on_used() -> void:
	pass

func _on_restored() -> void:
	_on_used()
