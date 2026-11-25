class_name Interactor
extends Area2D
## Player child that selects ONE Interactable among the overlapping ones:
## highest interact_priority first, then nearest. Only targets whose
## can_focus(player) is true are considered. On `interact` (just pressed)
## it awaits target.interact(player); lock_movement targets lock player input
## (reason &"interaction") until they finish. Collision: layer 0, mask
## Interactable. Driven by Player.update_interaction() each physics frame.

signal target_changed(target: Interactable)
signal interaction_started(target: Interactable)
signal interaction_ended(target: Interactable)

const LOCK_REASON := &"interaction"

## Seconds after an interaction during which input stays locked and interact
## is ignored (prevents the closing press from re-triggering / jumping).
@export var post_interaction_cooldown: float = 0.15
## Optional prompt (InteractionPrompt). Auto-found as sibling "InteractionPrompt".
@export var prompt: InteractionPrompt

var target: Interactable = null
var is_busy: bool = false

var _player: Player
var _cooldown_left: float = 0.0


func _init() -> void:
	collision_layer = 0
	collision_mask = Layers.INTERACTABLE
	monitoring = true
	monitorable = false


func _ready() -> void:
	_player = get_parent() as Player
	if prompt == null:
		prompt = get_parent().get_node_or_null(^"InteractionPrompt") as InteractionPrompt


## Called by Player every physics frame with the (lock-filtered) input.
func update_interaction(input: PlayerInputState, delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
		if _cooldown_left == 0.0 and _player:
			_player.remove_input_lock(LOCK_REASON)
	if is_busy:
		return
	var best := find_best_target()
	_set_target(best)
	if input.interact_pressed and target and _cooldown_left <= 0.0:
		_run_interaction(target)


## Returns the best focusable Interactable currently overlapping (or null).
func find_best_target() -> Interactable:
	var actor: Node = _player if _player else get_parent()
	var best: Interactable = null
	var best_dist := INF
	for area in get_overlapping_areas():
		var it := area as Interactable
		if it == null or not it.can_focus(actor):
			continue
		var d := global_position.distance_squared_to(it.global_position)
		if best == null or it.interact_priority > best.interact_priority \
				or (it.interact_priority == best.interact_priority and d < best_dist):
			best = it
			best_dist = d
	return best


## Interacts with the current target immediately (tests / scripted use).
func interact_now() -> void:
	if not is_busy and target:
		await _run_interaction(target)


func _set_target(value: Interactable) -> void:
	if value == target and (value == null or is_instance_valid(value)):
		_refresh_prompt()
		return
	if target and is_instance_valid(target):
		target.set_focused(false)
	target = value
	if target:
		target.set_focused(true)
	_refresh_prompt()
	target_changed.emit(target)


func _refresh_prompt() -> void:
	if prompt == null:
		return
	if target and not is_busy and _cooldown_left <= 0.0:
		prompt.show_for(target)
	else:
		prompt.hide_prompt()


func _run_interaction(it: Interactable) -> void:
	is_busy = true
	var locks := it.lock_movement
	if locks and _player:
		_player.add_input_lock(LOCK_REASON)
	_refresh_prompt()
	interaction_started.emit(it)
	await it.interact(_player if _player else get_parent())
	if not is_inside_tree():
		return
	is_busy = false
	_cooldown_left = post_interaction_cooldown
	if locks and _player and _cooldown_left <= 0.0:
		_player.remove_input_lock(LOCK_REASON)
	_refresh_prompt()
	interaction_ended.emit(it)
