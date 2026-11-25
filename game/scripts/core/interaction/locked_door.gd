class_name LockedDoor
extends ItemUseInteractable
## Physical door in the level opened with a key item (ItemUseInteractable).
## The child StaticBody2D ("Blocker", layer World) is disabled once used; the
## open state persists through success_flag.

signal opened

## Blocking body (auto-found child StaticBody2D when empty).
@export var blocker: StaticBody2D


func _init() -> void:
	super._init()
	prompt_text = "Unlock"
	locked_prompt_text = "Locked"


func _ready() -> void:
	if blocker == null:
		for child in get_children():
			if child is StaticBody2D:
				blocker = child
				break
	super._ready()


func is_open() -> bool:
	return is_active()


func _on_used() -> void:
	if blocker:
		for child in blocker.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				child.set_deferred(&"disabled", true)
	opened.emit()
