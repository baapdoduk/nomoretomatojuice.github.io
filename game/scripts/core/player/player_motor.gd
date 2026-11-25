class_name PlayerMotor
extends Node
## Base class for player movement motors. A motor owns ONLY movement physics
## (velocity integration, jump, dash timing) and calls move_and_slide().
## Shared state (facing, input locks, knockback/stun, attack, death) lives in
## Player and its components; motors read it through `player`.
##
## Player selects one motor per scene instance (Player.movement_mode) and calls
## enter() once, then physics_update() every physics frame.

## The owning player (set by Player before enter()).
var player: Player
## Shortcut to player.config.
var config: PlayerConfig

var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO


## Called when the player activates this motor.
func enter(p_player: Player) -> void:
	player = p_player
	config = player.config
	reset_state()


## Clears timers (spawn / respawn).
func reset_state() -> void:
	_dash_time_left = 0.0
	_dash_cooldown_left = 0.0
	_dash_direction = Vector2.ZERO


## Override: integrate one physics step and call player.move_and_slide().
func physics_update(_input: PlayerInputState, _delta: float) -> void:
	pass


func is_dashing() -> bool:
	return _dash_time_left > 0.0

func get_dash_cooldown_left() -> float:
	return _dash_cooldown_left

func get_dash_direction() -> Vector2:
	return _dash_direction

## Override: true while the motor considers the player airborne.
func is_airborne() -> bool:
	return false

## Override: extra numbers for debug overlays.
func get_debug_info() -> Dictionary:
	return {"dash_left": _dash_time_left, "dash_cooldown": _dash_cooldown_left}

## Ends a dash early (e.g. when hurt).
func cancel_dash() -> void:
	_dash_time_left = 0.0


# ------------------------------------------------------------------ helpers for subclasses

func _tick_dash_timers(delta: float) -> void:
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	if _dash_time_left > 0.0:
		_dash_time_left = maxf(0.0, _dash_time_left - delta)

func _can_start_dash() -> bool:
	return _dash_time_left <= 0.0 and _dash_cooldown_left <= 0.0 and not player.is_stunned()

## Starts a dash in `direction` (normalized). Cooldown starts with the dash.
func _start_dash(direction: Vector2) -> void:
	_dash_direction = direction.normalized()
	_dash_time_left = config.dash_duration
	_dash_cooldown_left = config.dash_cooldown
	player._on_motor_dashed(_dash_direction)

static func _approach(current: float, target: float, amount: float) -> float:
	return move_toward(current, target, amount)
