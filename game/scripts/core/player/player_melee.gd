class_name PlayerMelee
extends Node2D
## Attack pivot + melee timing (startup -> active -> recovery).
## Rotates toward the attack direction so the child Hitbox (placed on +X at
## PlayerConfig.attack_range) covers left/right in side view and 8 directions
## in top-down. Each swing calls Hitbox.activate(), so one swing damages a
## target at most once.

signal attack_started(direction: Vector2)
signal attack_finished
## Forwarded from the Hitbox: a swing connected.
signal hit_confirmed(hurtbox: Hurtbox, event: DamageEvent)

enum Phase { IDLE, STARTUP, ACTIVE, RECOVERY }

## The melee hitbox (child). Layer PLAYER_ATTACK, mask ENEMY.
@export var hitbox: Hitbox

var config: PlayerConfig
var phase: Phase = Phase.IDLE
var direction: Vector2 = Vector2.RIGHT

var _timer: float = 0.0


func _ready() -> void:
	if hitbox == null:
		for child in get_children():
			if child is Hitbox:
				hitbox = child
				break
	if hitbox:
		hitbox.hit_landed.connect(func(h: Hurtbox, e: DamageEvent) -> void: hit_confirmed.emit(h, e))


## Applies config values to the hitbox (damage, knockback, shape size/offset).
func setup(p_config: PlayerConfig, source: Node) -> void:
	config = p_config
	if hitbox == null:
		return
	hitbox.source = source
	hitbox.damage = config.attack_damage
	hitbox.knockback_strength = config.attack_knockback
	hitbox.knockback_direction = Vector2.RIGHT
	hitbox.position = Vector2(config.attack_range, 0)
	for child in hitbox.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			child.shape = child.shape.duplicate()
			(child.shape as RectangleShape2D).size = config.attack_size
	hitbox.deactivate()


func can_attack() -> bool:
	return phase == Phase.IDLE

func is_attacking() -> bool:
	return phase != Phase.IDLE

## Starts a swing toward `dir` (normalized). Returns false if already swinging.
func start(dir: Vector2) -> bool:
	if not can_attack() or config == null:
		return false
	direction = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	rotation = direction.angle()
	phase = Phase.STARTUP
	_timer = config.attack_startup
	attack_started.emit(direction)
	if _timer <= 0.0:
		_advance()
	return true

## Called by Player every physics frame.
func update(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	_timer -= delta
	while phase != Phase.IDLE and _timer <= 0.0:
		_advance()

func cancel() -> void:
	if phase == Phase.IDLE:
		return
	if hitbox:
		hitbox.deactivate()
	phase = Phase.IDLE
	attack_finished.emit()


func _advance() -> void:
	match phase:
		Phase.STARTUP:
			phase = Phase.ACTIVE
			_timer += config.attack_active
			if hitbox:
				hitbox.activate()
		Phase.ACTIVE:
			phase = Phase.RECOVERY
			_timer += config.attack_recovery
			if hitbox:
				hitbox.deactivate()
		Phase.RECOVERY:
			phase = Phase.IDLE
			attack_finished.emit()
