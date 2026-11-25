class_name Interactable
extends Area2D
## Base class for everything the player can interact with (doors, switches,
## pickups, photo/dialog popups, item-use spots, context actions).
##
## Contract:
##  - Lives on physics layer INTERACTABLE (layer 6), monitorable, not monitoring.
##  - The player's Interactor focuses the nearest Interactable whose
##    can_focus(actor) is true and calls interact(actor) on the `interact` action.
##  - Subclasses override _perform(actor) (may `await`) and optionally
##    _can_interact(actor). interaction_finished is emitted when _perform returns.
##  - While a lock_movement interaction runs, the Interactor locks player input.
##  - Conditions (required_item / required_flags) are checked in interact();
##    if unmet, blocked_message is shown and nothing else happens.

signal interacted(actor: Node)
signal interaction_finished
signal focus_changed(focused: bool)

@export var prompt_text: String = "Interact"
## Action shown in the prompt glyph (normally &"interact").
@export var prompt_action: StringName = &"interact"
@export var enabled: bool = true
## Higher priority wins over distance when several targets overlap.
@export var interact_priority: int = 0
## Lock player movement until interaction_finished.
@export var lock_movement: bool = false
## Disable after the first successful interaction.
@export var one_shot: bool = false
## Prompt anchor relative to this node.
@export var prompt_offset: Vector2 = Vector2(0, -28)

@export_group("Conditions")
## Item id required to interact (empty = none). See consume_required_item.
@export var required_item: StringName = &""
@export var consume_required_item: bool = false
@export var required_flags: Array[StringName] = []
## Toast shown when conditions are not met.
@export var blocked_message: String = ""
## Prompt text while conditions are unmet (empty = use prompt_text).
@export var locked_prompt_text: String = ""

var is_busy: bool = false
var has_been_used: bool = false
var is_focused: bool = false


func _init() -> void:
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true


## Whether the Interactor may select this target (prompt shown).
func can_focus(actor: Node) -> bool:
	return enabled and not is_busy and not (one_shot and has_been_used) and _can_interact(actor)

func conditions_met() -> bool:
	if required_item != &"" and not GameState.has_item(required_item):
		return false
	for flag in required_flags:
		if not GameState.has_flag(flag):
			return false
	return true

func get_prompt_text() -> String:
	if not conditions_met() and locked_prompt_text != "":
		return locked_prompt_text
	return prompt_text

func get_prompt_position() -> Vector2:
	return global_position + prompt_offset

func set_focused(value: bool) -> void:
	if value == is_focused:
		return
	is_focused = value
	focus_changed.emit(value)

## Entry point used by the Interactor (and tests). Coroutine.
func interact(actor: Node) -> void:
	if not can_focus(actor):
		return
	if not conditions_met():
		if blocked_message != "":
			GameState.notify(blocked_message)
		return
	is_busy = true
	if required_item != &"" and consume_required_item:
		GameState.remove_item(required_item)
	interacted.emit(actor)
	await _perform(actor)
	has_been_used = true
	is_busy = false
	interaction_finished.emit()


## Override: extra availability rules (e.g. one-way door side check).
func _can_interact(_actor: Node) -> bool:
	return true

## Override: the actual effect. May await (popups, context actions, ...).
func _perform(_actor: Node) -> void:
	pass
