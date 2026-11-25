class_name Health
extends Node
## Hit points + invulnerability. Shared by player, enemies and bosses.
##
## Player instances set `use_game_state = true`: GameState.health is then the
## single source of truth and this node only adds i-frames and signals.
## Invulnerability has two sources: a timer (i-frames after a hit, dash) and
## named flags (e.g. &"boss_attacking") toggled by state machines.

signal health_changed(current: int, max_health: int)
signal damaged(event: DamageEvent)
signal healed(amount: int)
signal died
signal invulnerability_changed(active: bool)

@export var max_health: int = 5
## Seconds of invulnerability granted after every accepted hit.
@export var invulnerability_time: float = 0.0
## Player only: read/write GameState.health instead of a local value.
@export var use_game_state: bool = false

var current: int:
	get:
		return GameState.health if use_game_state else _current
var is_dead: bool = false

var _current: int = 0
var _invuln_timer: float = 0.0
var _invuln_flags: Dictionary = {}
var _was_invulnerable := false


func _ready() -> void:
	if use_game_state:
		max_health = GameState.max_health
		is_dead = GameState.health <= 0
		GameState.health_changed.connect(_on_game_state_health_changed)
	else:
		_current = max_health


func _physics_process(delta: float) -> void:
	if _invuln_timer > 0.0:
		_invuln_timer = maxf(0.0, _invuln_timer - delta)
	_update_invuln_signal()


## Returns true if the damage was applied.
func apply_damage(event: DamageEvent) -> bool:
	if is_dead or event == null or event.amount <= 0 or is_invulnerable():
		return false
	if use_game_state:
		GameState.apply_damage(event.amount)  # emits health_changed via callback
	else:
		_current = maxi(0, _current - event.amount)
		health_changed.emit(_current, max_health)
	damaged.emit(event)
	if invulnerability_time > 0.0:
		set_invulnerable_for(invulnerability_time)
	if current <= 0 and not is_dead:
		is_dead = true
		died.emit()
	return true

func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	if use_game_state:
		GameState.heal(amount)
	else:
		_current = mini(max_health, _current + amount)
		health_changed.emit(_current, max_health)
	healed.emit(amount)

## Restores full health (or keeps the current value when full=false) and revives.
func reset(full: bool = true) -> void:
	is_dead = false
	_invuln_timer = 0.0
	_invuln_flags.clear()
	if use_game_state:
		if full:
			GameState.refill_health()
	else:
		if full:
			_current = max_health
		health_changed.emit(_current, max_health)
	_update_invuln_signal()

func get_ratio() -> float:
	return float(current) / float(maxi(1, max_health))

func set_invulnerable_for(seconds: float) -> void:
	_invuln_timer = maxf(_invuln_timer, seconds)
	_update_invuln_signal()

## Named, untimed invulnerability (e.g. &"boss_attacking", &"cutscene").
func set_invulnerable_flag(reason: StringName, enabled: bool) -> void:
	if enabled:
		_invuln_flags[reason] = true
	else:
		_invuln_flags.erase(reason)
	_update_invuln_signal()

func is_invulnerable() -> bool:
	return _invuln_timer > 0.0 or not _invuln_flags.is_empty()

func _update_invuln_signal() -> void:
	var now := is_invulnerable()
	if now != _was_invulnerable:
		_was_invulnerable = now
		invulnerability_changed.emit(now)

func _on_game_state_health_changed(value: int, max_value: int) -> void:
	max_health = max_value
	if value > 0:
		is_dead = false
	health_changed.emit(value, max_value)
