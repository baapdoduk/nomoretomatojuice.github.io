class_name Hitbox
extends Area2D
## Deals damage to overlapping Hurtboxes while `active`.
## Each activation hits a given target at most once (see activate()).
## Layer: PLAYER_ATTACK (mask ENEMY) or ENEMY_ATTACK (mask PLAYER).
## monitoring stays on; `active` gates damage so already-overlapping targets
## are hit on the first active physics frame.

signal hit_landed(hurtbox: Hurtbox, event: DamageEvent)

@export var damage: int = 1
@export var knockback_strength: float = 0.0
## If non-zero, knockback uses this direction (rotated by the hitbox) instead of
## "away from hitbox center".
@export var knockback_direction: Vector2 = Vector2.ZERO
@export var active: bool = false:
	set = set_active
## Attacker root; defaults to owner. Hurtboxes sharing this source's Health are ignored.
@export var source: Node
@export var tags: Array[StringName] = []

var _hit_targets: Dictionary = {}


func _ready() -> void:
	monitoring = true
	monitorable = false
	if source == null:
		source = owner


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		if area is Hurtbox:
			_try_hit(area)


## Starts a new attack instance: clears the per-activation hit registry.
func activate() -> void:
	_hit_targets.clear()
	active = true

func deactivate() -> void:
	active = false

func set_active(value: bool) -> void:
	if value and not active:
		_hit_targets.clear()
	active = value

func reset_hits() -> void:
	_hit_targets.clear()

func has_hit(hurtbox: Hurtbox) -> bool:
	return _hit_targets.has(hurtbox.get_target_id())

func _try_hit(hurtbox: Hurtbox) -> void:
	var target_id := hurtbox.get_target_id()
	if _hit_targets.has(target_id):
		return
	if source and hurtbox.owner == source:
		return
	var event := DamageEvent.create(damage, source)
	event.hitbox = self
	event.position = hurtbox.global_position
	event.tags = tags.duplicate()
	if knockback_strength > 0.0:
		var dir := knockback_direction.rotated(global_rotation) if knockback_direction != Vector2.ZERO \
			else (hurtbox.global_position - global_position)
		event.knockback = dir.normalized() * knockback_strength
	# Only accepted hits are registered: a target that was invulnerable (dash,
	# i-frames) can still be hit later in the same activation if it stays inside.
	if hurtbox.receive_hit(event):
		_hit_targets[target_id] = true
		hit_landed.emit(hurtbox, event)
