class_name Projectile
extends Hitbox
## Straight-moving damaging projectile (layer ENEMY_ATTACK, mask PLAYER | WORLD).
## Damages at most one target once, then frees itself. Also removed when its
## lifetime ends, when it leaves the screen (VisibleOnScreenNotifier2D) or when
## it touches a World body. Hits rejected by i-frames let it fly on.
## Missing children (Collision, ScreenNotifier, Visual) are created in code.

## reason: &"hit", &"lifetime", &"offscreen", &"world", &"cancelled".
signal despawned(reason: StringName)

## Travel velocity (px/s). Rotation follows it.
@export var velocity: Vector2 = Vector2.ZERO
@export_range(0.05, 60.0, 0.05) var lifetime: float = 2.0
@export_range(1.0, 200.0, 0.5) var radius: float = 6.0
## Free on touching World bodies.
@export var destroy_on_world: bool = true
@export var color: Color = Color(1.0, 0.95, 0.75)

var age: float = 0.0
var _done := false


## Convenience setup before add_child().
func configure(p_velocity: Vector2, p_damage: int, p_knockback: float, p_lifetime: float, p_radius: float, p_source: Node = null) -> void:
	velocity = p_velocity
	damage = p_damage
	knockback_strength = p_knockback
	lifetime = p_lifetime
	radius = p_radius
	source = p_source


func _ready() -> void:
	super._ready()
	# Godot Physics only pairs an Area2D with static bodies when it is monitorable;
	# required for World (StaticBody2D) detection. Nothing masks ENEMY_ATTACK.
	monitorable = true
	collision_layer = Layers.ENEMY_ATTACK
	collision_mask = Layers.PLAYER | Layers.WORLD
	knockback_direction = Vector2.RIGHT  # along travel (rotated by the node)
	if velocity != Vector2.ZERO:
		rotation = velocity.angle()
	var shape := get_node_or_null(^"Collision") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "Collision"
		add_child(shape)
	if shape.shape == null or shape.shape is CircleShape2D:
		var circle := CircleShape2D.new()  # per-instance: radius comes from the pattern
		circle.radius = radius
		shape.shape = circle
	var notifier := get_node_or_null(^"ScreenNotifier") as VisibleOnScreenNotifier2D
	if notifier == null:
		notifier = VisibleOnScreenNotifier2D.new()
		notifier.name = "ScreenNotifier"
		notifier.rect = Rect2(-radius, -radius, radius * 2.0, radius * 2.0)
		add_child(notifier)
	notifier.screen_exited.connect(_on_screen_exited)
	if get_node_or_null(^"Visual") == null:
		var vis := Polygon2D.new()
		vis.name = "Visual"
		vis.polygon = AttackShape.circle(radius, 12)
		vis.color = color
		add_child(vis)
	hit_landed.connect(_on_hit_landed)
	body_entered.connect(_on_body_entered)
	activate()


func _physics_process(delta: float) -> void:
	if _done:
		return
	super._physics_process(delta)
	if _done:
		return
	global_position += velocity * delta
	age += delta
	if age >= lifetime - 0.0001:
		despawn(&"lifetime")


## Removes the projectile (idempotent).
func despawn(reason: StringName) -> void:
	if _done:
		return
	_done = true
	deactivate()
	set_deferred(&"monitoring", false)
	despawned.emit(reason)
	queue_free()


func _on_hit_landed(_hurtbox: Hurtbox, _event: DamageEvent) -> void:
	despawn(&"hit")

func _on_screen_exited() -> void:
	despawn(&"offscreen")

func _on_body_entered(body: Node2D) -> void:
	if destroy_on_world and body is CollisionObject2D \
			and ((body as CollisionObject2D).collision_layer & Layers.WORLD) != 0:
		despawn(&"world")
