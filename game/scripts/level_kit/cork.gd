class_name Cork
extends CharacterBody2D
## Cork: wobbling cork-blob walker. Patrols left/right, turns at walls and at
## ledges, hurts the player on contact (Hitbox on ENEMY_ATTACK), and is defeated
## only by damage to its Hurtbox (the player's sword) — there is no stomp.
## Body + Hurtbox on layer ENEMY; body masks WORLD.
## Expected children: Health, Hurtbox (+shape), ContactHitbox (Hitbox +shape),
## CollisionShape2D, Visual (swappable; placeholder CorkVisual reads `direction`,
## `hurt_flash` and `is_defeated`). Origin = feet centre.

signal turned(direction: int)
signal defeated

@export var walk_speed: float = 36.0
## Initial direction: -1 left, 1 right.
@export_range(-1, 1, 2) var start_direction: int = -1
@export var gravity: float = 900.0
## How far ahead of the feet (px) the ledge probe looks for ground.
@export var ledge_probe_ahead: float = 7.0
@export var ledge_probe_depth: float = 10.0
@export var turn_at_ledges: bool = true
@export var hurt_flash_time: float = 0.15
@export var defeat_time: float = 0.45

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact_hitbox: Hitbox = $ContactHitbox

var direction: int = -1
var is_defeated: bool = false
## Seconds of hurt flash left (for the visual).
var hurt_flash: float = 0.0
var _defeat_anim: float = -1.0
var _turn_cooldown: float = 0.0


func _ready() -> void:
	direction = start_direction if start_direction != 0 else -1
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD
	hurtbox.collision_layer = Layers.ENEMY
	hurtbox.collision_mask = 0
	contact_hitbox.collision_layer = Layers.ENEMY_ATTACK
	contact_hitbox.collision_mask = Layers.PLAYER
	contact_hitbox.source = self
	contact_hitbox.active = true
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	hurt_flash = maxf(0.0, hurt_flash - delta)
	_turn_cooldown = maxf(0.0, _turn_cooldown - delta)
	if is_defeated:
		_defeat_anim += delta / maxf(defeat_time, 0.01)
		position += Vector2(-direction * 40.0, -60.0 + _defeat_anim * 160.0) * delta
		rotation += direction * -10.0 * delta
		modulate.a = clampf(1.0 - _defeat_anim, 0.0, 1.0)
		if _defeat_anim >= 1.0:
			queue_free()
		return
	# Contact damage repeats whenever the player's i-frames allow it.
	contact_hitbox.reset_hits()
	velocity.y = minf(velocity.y + gravity * delta, 400.0)
	velocity.x = direction * walk_speed
	move_and_slide()
	if _turn_cooldown <= 0.0:
		if is_on_wall() and signf(get_wall_normal().x) == -direction:
			turn()
		elif turn_at_ledges and is_on_floor() and not _has_ground_ahead():
			turn()


## Reverses the walking direction.
func turn() -> void:
	direction = -direction
	_turn_cooldown = 0.1
	turned.emit(direction)


func _has_ground_ahead() -> bool:
	var from := global_position + Vector2(direction * ledge_probe_ahead, -2.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, ledge_probe_depth + 2.0), Layers.WORLD, [get_rid()])
	query.hit_from_inside = true
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _on_damaged(event: DamageEvent) -> void:
	hurt_flash = hurt_flash_time
	if event.knockback.x != 0.0:
		position.x += signf(event.knockback.x) * 3.0


func _on_died() -> void:
	is_defeated = true
	_defeat_anim = 0.0
	contact_hitbox.active = false
	hurtbox.enabled = false
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)
	defeated.emit()

