class_name Spikes
extends Hitbox
## Red/white spike strip: a Hitbox on layer ENEMY_ATTACK (mask PLAYER) that is
## always active. Deals `damage` (default 1) with knockback along the spikes'
## local up (rotate the node for wall/ceiling spikes) — not an instant kill.
## Hits a given target once per contact: the target must leave before it can be
## hit again (Player i-frames cover the rest).
## Origin = bottom centre of the strip; the strip is `width` px wide.
## Visuals: swappable `Visual` child (placeholder: SpikesVisual); delete it when
## spike tiles provide the art.

@export var width: float = 32.0
@export var height: float = 10.0


func _init() -> void:
	damage = 1
	knockback_strength = 240.0
	knockback_direction = Vector2.UP
	tags = [&"hazard"]


func _ready() -> void:
	super._ready()
	collision_layer = Layers.ENEMY_ATTACK
	collision_mask = Layers.PLAYER
	KitUtil.ensure_rect_shape(self, Vector2(width - 4.0, height - 2.0), Vector2(0, -(height - 2.0) * 0.5))
	area_exited.connect(_on_area_exited)
	active = true


## Forget a target when it leaves, so the next contact hits again.
func _on_area_exited(area: Area2D) -> void:
	if area is Hurtbox:
		_hit_targets.erase((area as Hurtbox).get_target_id())

