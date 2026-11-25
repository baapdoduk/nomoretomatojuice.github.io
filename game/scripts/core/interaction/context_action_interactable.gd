class_name ContextActionInteractable
extends Interactable
## Context-sensitive action (pull lever, push block, pry open, squeeze...).
## Interact starts it (movement locked); then the player performs `action_type`:
##   PRESS           press `action` once (completes immediately when action == prompt_action)
##   HOLD            hold `action` for hold_time
##   MASH            press `action` mash_count times
##   STICK_DIRECTION hold the move stick toward stick_direction for confirm_time
##   TRIGGER_DEPTH   hold analog `action` (context_left/right, L2/R2) beyond
##                   trigger_threshold for confirm_time
## No time limit by default (time_limit = 0). With the GameState setting
## &"assist_context_actions", MASH and TRIGGER_DEPTH become simple holds.
## `cancel_action` (default dash / Circle) or cancel() aborts without penalty.
## On success: success_flag set, `completed` + activated_changed(true) emitted.
## Puzzle input contract: activated_changed(active) + is_active().

signal started
signal progress_changed(progress: float)
signal completed
signal cancelled
## Emitted when time_limit (> 0) ran out.
signal failed
signal activated_changed(active: bool)

enum ActionType { PRESS, HOLD, MASH, STICK_DIRECTION, TRIGGER_DEPTH }

@export var action_type: ActionType = ActionType.HOLD
## Button / analog action to perform once started.
@export var action: StringName = &"interact"
## HOLD: seconds to hold. Also the assist hold time for MASH.
@export var hold_time: float = 1.0
@export var mash_count: int = 8
## MASH: progress lost per second while not pressing (0 = none).
@export var mash_decay: float = 0.0
@export var stick_direction: Vector2 = Vector2.RIGHT
@export_range(0.1, 1.0) var stick_threshold: float = 0.7
@export_range(0.05, 1.0) var trigger_threshold: float = 0.85
## STICK_DIRECTION / TRIGGER_DEPTH: seconds the input must be kept.
@export var confirm_time: float = 0.3
## Seconds allowed once started (0 = unlimited).
@export var time_limit: float = 0.0
@export var cancel_action: StringName = &"dash"
## Can be completed again after success.
@export var repeatable: bool = false
@export var success_flag: StringName = &""
@export var success_message: String = ""

## 0..1 while running.
var progress: float = 0.0
var is_running: bool = false
var is_completed: bool = false
## TRIGGER_DEPTH: last read analog value (for UI).
var current_depth: float = 0.0
var elapsed: float = 0.0

var _first_step: bool = false


func _init() -> void:
	super._init()
	prompt_text = "Use"
	lock_movement = true


func _ready() -> void:
	if success_flag != &"" and GameState.has_flag(success_flag):
		is_completed = true


func is_active() -> bool:
	return is_completed

## True when assist mode turns this action into a simple hold.
func is_assisted() -> bool:
	return bool(GameState.get_setting(&"assist_context_actions", false)) \
		and action_type in [ActionType.MASH, ActionType.TRIGGER_DEPTH]

## Aborts a running action (progress reset, no penalty).
func cancel() -> void:
	if not is_running:
		return
	is_running = false
	perform_failed = true
	_set_progress(0.0)
	cancelled.emit()


func _can_interact(_actor: Node) -> bool:
	return repeatable or not is_completed


func _perform(actor: Node) -> void:
	is_running = true
	elapsed = 0.0
	current_depth = 0.0
	_set_progress(0.0)
	_first_step = true
	started.emit()
	if action_type == ActionType.PRESS and action == prompt_action:
		_complete()
		return
	while is_running:
		await get_tree().physics_frame
		if not is_inside_tree() or (actor is Player and (actor as Player).is_dead()):
			cancel()
			break
		if get_tree().paused or not can_process():
			# Pause menu open: ignore its input and don't tick time_limit; the
			# first step after resuming ignores just-pressed edges.
			_first_step = true
			continue
		if is_running:
			_step(get_physics_process_delta_time())


func _step(delta: float) -> void:
	var first := _first_step
	_first_step = false
	elapsed += delta
	if not first and cancel_action != &"" and Input.is_action_just_pressed(cancel_action):
		cancel()
		return
	if time_limit > 0.0 and elapsed > time_limit:
		is_running = false
		perform_failed = true
		_set_progress(0.0)
		failed.emit()
		return
	var p := progress
	var assisted := is_assisted()
	match action_type:
		ActionType.PRESS:
			if not first and Input.is_action_just_pressed(action):
				p = 1.0
		ActionType.HOLD:
			p = _hold_step(p, Input.is_action_pressed(action), hold_time, delta)
		ActionType.MASH:
			if assisted:
				p = _hold_step(p, Input.is_action_pressed(action), hold_time, delta)
			elif not first and Input.is_action_just_pressed(action):
				p += 1.0 / float(maxi(1, mash_count))
			elif mash_decay > 0.0:
				p = maxf(0.0, p - mash_decay * delta)
		ActionType.STICK_DIRECTION:
			var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
			var ok := v.length() >= stick_threshold and v.normalized().dot(stick_direction.normalized()) >= 0.8
			p = _hold_step(p, ok, confirm_time, delta)
		ActionType.TRIGGER_DEPTH:
			current_depth = Input.get_action_strength(action)
			var ok := current_depth > 0.05 if assisted else current_depth >= trigger_threshold
			p = _hold_step(p, ok, hold_time if assisted else confirm_time, delta)
	if p >= 1.0 - 0.0001:
		p = 1.0
	_set_progress(clampf(p, 0.0, 1.0))
	if progress >= 1.0:
		_complete()


## Fills while `held`, drains twice as fast otherwise.
func _hold_step(p: float, held: bool, duration: float, delta: float) -> float:
	var rate := delta / maxf(0.01, duration)
	return p + rate if held else maxf(0.0, p - rate * 2.0)


func _set_progress(value: float) -> void:
	if is_equal_approx(value, progress):
		progress = value
		return
	progress = value
	progress_changed.emit(progress)


func _complete() -> void:
	is_running = false
	_set_progress(1.0)
	var was := is_completed
	is_completed = true
	if success_flag != &"":
		GameState.set_flag(success_flag, true)
	if success_message != "":
		GameState.notify(success_message)
	completed.emit()
	if not was:
		activated_changed.emit(true)
