class_name DamageEvent
extends RefCounted
## Payload passed Hitbox -> Hurtbox -> Health. Created per hit.

var amount: int = 1
## Attacker root node (player, boss, projectile owner). May be null.
var source: Node = null
## The Hitbox that produced the hit (null for scripted damage).
var hitbox: Node = null
## Knockback velocity (direction * strength, px/s). Zero = none.
var knockback: Vector2 = Vector2.ZERO
## World position where the hit was registered.
var position: Vector2 = Vector2.ZERO
## Free-form tags, e.g. &"melee", &"projectile", &"hazard".
var tags: Array[StringName] = []

static func create(p_amount: int, p_source: Node = null, p_knockback: Vector2 = Vector2.ZERO) -> DamageEvent:
	var e := DamageEvent.new()
	e.amount = p_amount
	e.source = p_source
	e.knockback = p_knockback
	return e

func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
