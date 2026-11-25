class_name Hurtbox
extends Area2D
## Receives hits from Hitboxes and forwards them to a Health node.
## Put it on layer PLAYER (player) or ENEMY (enemies/bosses); mask stays 0.

## Emitted when damage was accepted.
signal hurt(event: DamageEvent)
## Emitted when a hit was rejected (invulnerable / disabled).
signal hit_ignored(event: DamageEvent)

## If unset, the first Health found among siblings / owner children is used.
@export var health: Health
@export var enabled: bool = true


func _ready() -> void:
	monitoring = false
	monitorable = true
	if health == null:
		health = _find_health()
	if health == null:
		push_warning("Hurtbox %s has no Health" % get_path())


func receive_hit(event: DamageEvent) -> bool:
	if not enabled or health == null:
		hit_ignored.emit(event)
		return false
	if health.apply_damage(event):
		hurt.emit(event)
		return true
	hit_ignored.emit(event)
	return false

## Identity used by Hitbox to avoid hitting the same target twice per activation
## (several Hurtboxes sharing one Health count as one target).
func get_target_id() -> int:
	return health.get_instance_id() if health else get_instance_id()

func _find_health() -> Health:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child is Health:
				return child
	if owner:
		for child in owner.get_children():
			if child is Health:
				return child
	return null
