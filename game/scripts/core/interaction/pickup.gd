class_name Pickup
extends Interactable
## World item. Collected on touch (auto_collect) or on interact.
## GameState.add_item() is the duplicate guard. Hides itself on scene load if
## the (non-stackable) item is already owned or `collected_flag` is set, so a
## pickup never respawns after collection — unless a respawn restored a
## snapshot taken before it was collected (then it reappears, by design).
## Shows a toast via GameState.notify and, for MEMORY items, an optional popup.

signal collected(item: ItemData)

@export var item: ItemData
## true: collect on touch. false: focusable, collect with interact.
@export var auto_collect: bool = true
## Optional GameState flag set on collection (needed for stackable items).
@export var collected_flag: StringName = &""
## Show an InfoPopup with the item's name/description/icon for MEMORY items.
@export var popup_for_memory: bool = true
## Toast format; %s = item display name.
@export var toast_format: String = "Got %s"
@export var popup_scene: PackedScene

var is_collected: bool = false


func _init() -> void:
	super._init()
	prompt_text = "Pick up"


func _ready() -> void:
	collision_mask = Layers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)
	if item:
		GameState.register_item(item)
	if _already_collected():
		_hide_collected()


func _already_collected() -> bool:
	if collected_flag != &"" and GameState.has_flag(collected_flag):
		return true
	return item != null and item.get_stack_limit() == 1 and GameState.has_item(item.id)


func _can_interact(_actor: Node) -> bool:
	return not auto_collect and not is_collected


func _on_body_entered(body: Node2D) -> void:
	if auto_collect and body is Player and not is_collected and enabled:
		collect(body as Player)


func _perform(actor: Node) -> void:
	await collect(actor as Player)


## Collects the item for `player`. Returns true when the inventory changed.
## Coroutine when a popup is shown.
func collect(player: Player = null) -> bool:
	if is_collected or item == null:
		return false
	if not item.requirements_met():
		if blocked_message != "":
			GameState.notify(blocked_message)
		return false
	var added := GameState.add_item(item)
	if collected_flag != &"":
		GameState.set_flag(collected_flag, true)
	_hide_collected()
	if not added:
		return false
	var label := item.display_name if item.display_name != "" else String(item.id)
	if toast_format != "":
		GameState.notify(toast_format % label if toast_format.contains("%s") else toast_format)
	collected.emit(item)
	if popup_for_memory and item.type == ItemData.ItemType.MEMORY:
		var host: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
		await InfoPopup.show_and_wait(host, label, item.description, item.icon, popup_scene, player)
	return true


func _hide_collected() -> void:
	is_collected = true
	enabled = false
	visible = false
	set_deferred(&"monitoring", false)
