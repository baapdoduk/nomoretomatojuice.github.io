class_name Player
extends CharacterBody2D
## The player character. One shared component set (Health, Hurtbox, melee,
## Interactor, prompt, Visual, Camera2D) + two movement motors; only the motor
## selected by `movement_mode` runs. Movement physics lives in the motors;
## facing, input locks, hurt/knockback, attack and death live here.
##
## Scene: res://scenes/core/player/player.tscn (group "player").
## Presentation nodes (Visual, SFX) subscribe to the signals below; the logic
## never depends on them.

## Emitted when the derived presentation state changes:
## &"idle", &"run", &"jump", &"fall", &"dash", &"attack", &"hurt", &"dead".
signal state_changed(state: StringName)
signal facing_changed(facing: Vector2)
signal jumped
signal landed
signal dashed(direction: Vector2)
signal attacked(direction: Vector2)
signal hurt(event: DamageEvent)
signal died

enum MovementMode { SIDE_VIEW, TOP_DOWN }

const STATE_IDLE := &"idle"
const STATE_RUN := &"run"
const STATE_JUMP := &"jump"
const STATE_FALL := &"fall"
const STATE_DASH := &"dash"
const STATE_ATTACK := &"attack"
const STATE_HURT := &"hurt"
const STATE_DEAD := &"dead"
const LOCK_DEATH := &"death"
const CAMERA_BOUNDS_GROUP := &"camera_bounds"

## Which motor runs for this scene instance.
@export var movement_mode: MovementMode = MovementMode.SIDE_VIEW
## Tuning data. Falls back to a default PlayerConfig.new() when empty.
@export var config: PlayerConfig
## When true, the Camera2D child is enabled and picks up a CameraBounds node.
@export var use_camera: bool = true

@onready var side_view_motor: SideViewMotor = get_node_or_null(^"SideViewMotor")
@onready var top_down_motor: TopDownMotor = get_node_or_null(^"TopDownMotor")
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var melee: PlayerMelee = $AttackPivot
@onready var interactor: Interactor = $Interactor
@onready var camera: Camera2D = get_node_or_null(^"Camera2D")

## Current presentation state (see state_changed).
var state: StringName = STATE_IDLE
## Last frame's input (after locks were applied).
var last_input: PlayerInputState = PlayerInputState.new()

var _motor: PlayerMotor
var _facing: Vector2 = Vector2.RIGHT
var _locks: Dictionary = {}
var _input_override: PlayerInputState = null
var _stun_left: float = 0.0
var _dead: bool = false


func _ready() -> void:
	add_to_group(Layers.GROUP_PLAYER)
	if config == null:
		config = PlayerConfig.new()
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD
	health.use_game_state = true
	health.invulnerability_time = config.invulnerability_time
	health.damaged.connect(_on_damaged)
	health.died.connect(_start_death)
	GameState.player_died.connect(_start_death)
	melee.setup(config, self)
	melee.attack_started.connect(func(dir: Vector2) -> void: attacked.emit(dir))
	melee.hit_confirmed.connect(_on_hit_confirmed)
	_select_motor()
	if camera:
		camera.enabled = use_camera
		if use_camera:
			apply_camera_bounds.call_deferred()


func _select_motor() -> void:
	var use_side := movement_mode == MovementMode.SIDE_VIEW
	_motor = side_view_motor if use_side else top_down_motor
	for m: PlayerMotor in [side_view_motor, top_down_motor]:
		if m:
			m.process_mode = Node.PROCESS_MODE_INHERIT if m == _motor else Node.PROCESS_MODE_DISABLED
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED if use_side else CharacterBody2D.MOTION_MODE_FLOATING
	if not use_side and _facing.y == 0.0 and _facing.x == 0.0:
		_facing = Vector2.DOWN
	assert(_motor != null, "Player: motor node for the selected movement_mode is missing")
	_motor.enter(self)


func _physics_process(delta: float) -> void:
	var input := _gather_input()
	last_input = input
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
	if not _dead and not is_stunned() and not _motor.is_dashing() and not melee.is_attacking():
		_update_facing(input.move)
	_motor.physics_update(input, delta)
	melee.update(delta)
	if input.attack_pressed and can_attack():
		melee.start(_get_attack_direction())
	interactor.update_interaction(input, delta)
	_update_state()


# ------------------------------------------------------------------ input

func _gather_input() -> PlayerInputState:
	var input: PlayerInputState
	if _input_override:
		input = _input_override.copy()
		_input_override.consume_presses()
	else:
		input = PlayerInputState.from_input()
	if is_input_locked() or _dead:
		return PlayerInputState.new()
	return input

## Test hook: drive the player with a scripted state instead of Input.
## Pass null to return to real input. See PlayerInputState for semantics.
func set_input_override(input_state: PlayerInputState) -> void:
	_input_override = input_state

## Named input lock (interaction, popup, death, cutscene...). Locks stack.
func add_input_lock(reason: StringName) -> void:
	_locks[reason] = true

func remove_input_lock(reason: StringName) -> void:
	_locks.erase(reason)

func has_input_lock(reason: StringName) -> bool:
	return _locks.has(reason)

func is_input_locked() -> bool:
	return not _locks.is_empty()


# ------------------------------------------------------------------ facing / queries

func _update_facing(move: Vector2) -> void:
	if move.length() < 0.2:
		return
	var f: Vector2
	if movement_mode == MovementMode.SIDE_VIEW:
		if absf(move.x) < 0.2:
			return
		f = Vector2(signf(move.x), 0.0)
	else:
		# Snap to 8 directions.
		var angle := snappedf(move.angle(), PI / 4.0)
		f = Vector2.from_angle(angle)
		f = Vector2(snappedf(f.x, 0.0001), snappedf(f.y, 0.0001))
	set_facing(f)

## Sets the facing direction (normalized). Side view keeps only the x sign.
func set_facing(value: Vector2) -> void:
	if value == Vector2.ZERO:
		return
	if movement_mode == MovementMode.SIDE_VIEW:
		value = Vector2(signf(value.x) if value.x != 0.0 else _facing.x, 0.0)
	value = value.normalized()
	if value.is_equal_approx(_facing):
		return
	_facing = value
	facing_changed.emit(_facing)

func get_facing() -> Vector2:
	return _facing

func get_motor() -> PlayerMotor:
	return _motor

func is_dashing() -> bool:
	return _motor != null and _motor.is_dashing()

func is_stunned() -> bool:
	return _stun_left > 0.0

func is_dead() -> bool:
	return _dead

func can_attack() -> bool:
	return not _dead and not is_stunned() and not is_dashing() and melee.can_attack()

func _get_attack_direction() -> Vector2:
	return _facing

## Debug numbers for lab overlays.
func get_debug_info() -> Dictionary:
	var info := _motor.get_debug_info() if _motor else {}
	info["state"] = state
	info["velocity"] = velocity
	info["facing"] = _facing
	info["locks"] = _locks.keys()
	info["invulnerable"] = health.is_invulnerable()
	return info


# ------------------------------------------------------------------ state

func _update_state() -> void:
	var s := STATE_IDLE
	if _dead:
		s = STATE_DEAD
	elif is_stunned():
		s = STATE_HURT
	elif is_dashing():
		s = STATE_DASH
	elif melee.is_attacking():
		s = STATE_ATTACK
	elif _motor.is_airborne():
		if movement_mode == MovementMode.SIDE_VIEW:
			s = STATE_JUMP if velocity.y < 0.0 else STATE_FALL
		else:
			s = STATE_JUMP
	elif velocity.length() > 5.0:
		s = STATE_RUN
	if s != state:
		state = s
		state_changed.emit(s)


# ------------------------------------------------------------------ motor callbacks

func _on_motor_jumped() -> void:
	jumped.emit()

func _on_motor_landed() -> void:
	landed.emit()

func _on_motor_dashed(direction: Vector2) -> void:
	if config.dash_iframe_time > 0.0:
		health.set_invulnerable_for(config.dash_iframe_time)
	melee.cancel()
	dashed.emit(direction)


# ------------------------------------------------------------------ hurt / death

## Applies a knockback velocity and removes control for `duration` seconds.
func apply_knockback(knockback_velocity: Vector2, duration: float) -> void:
	velocity = knockback_velocity
	_stun_left = maxf(_stun_left, duration)
	_motor.cancel_dash()

func _on_damaged(event: DamageEvent) -> void:
	melee.cancel()
	var kb := event.knockback
	if kb == Vector2.ZERO:
		var from := global_position
		if event.source is Node2D:
			from = (event.source as Node2D).global_position
		elif event.position != Vector2.ZERO:
			from = event.position
		var dir := (global_position - from).normalized()
		if dir == Vector2.ZERO:
			dir = -_facing
		kb = dir * config.hurt_knockback_speed
	if movement_mode == MovementMode.SIDE_VIEW:
		kb.y = minf(kb.y, 0.0) - config.hurt_knockback_lift
	apply_knockback(kb, config.hurt_stun_time)
	InputFeedback.rumble_preset(&"player_hurt")
	hurt.emit(event)

func _on_hit_confirmed(_hurtbox: Hurtbox, _event: DamageEvent) -> void:
	InputFeedback.rumble_preset(&"hit_confirm")

## Instantly kills the player (kill zones, scripted deaths).
func kill() -> void:
	if _dead:
		return
	if GameState.health > 0:
		GameState.apply_damage(GameState.health)  # emits player_died -> _start_death
	_start_death()

func _start_death() -> void:
	if _dead or not is_inside_tree():
		return
	_dead = true
	health.is_dead = true
	melee.cancel()
	_motor.cancel_dash()
	add_input_lock(LOCK_DEATH)
	_update_state()
	died.emit()
	await get_tree().create_timer(config.death_respawn_delay, false, true).timeout
	if is_inside_tree():
		SceneRouter.respawn_at_checkpoint()


# ------------------------------------------------------------------ spawning / camera

## Called by SceneRouter after placing the player at a SpawnPoint.
func on_spawned(spawn: Node2D) -> void:
	velocity = Vector2.ZERO
	_stun_left = 0.0
	if _motor:
		_motor.reset_state()
	var f: Variant = spawn.get(&"facing") if spawn else null
	if f is Vector2 and f != Vector2.ZERO:
		set_facing(f)
	if camera and use_camera:
		apply_camera_bounds()
		camera.reset_smoothing()

## Copies limits from the first node in group "camera_bounds" (a CameraBounds).
func apply_camera_bounds() -> void:
	if camera == null or not is_inside_tree():
		return
	var bounds := get_tree().get_first_node_in_group(CAMERA_BOUNDS_GROUP)
	if bounds and bounds.has_method(&"get_global_rect"):
		var r: Rect2 = bounds.call(&"get_global_rect")
		camera.limit_left = int(r.position.x)
		camera.limit_top = int(r.position.y)
		camera.limit_right = int(r.end.x)
		camera.limit_bottom = int(r.end.y)
	camera.reset_smoothing()
