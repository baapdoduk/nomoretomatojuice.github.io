class_name AttackArea
extends Node2D
## One placed instance of an AttackPattern: telegraph (harmless) -> active -> freed.
##
## Children (created in code when missing, so AttackArea.new() works; a scene may
## provide them to customise the look):
##   Hitbox (core Hitbox, layer ENEMY_ATTACK, mask PLAYER) / Collision (CollisionPolygon2D)
##   Visual (Telegraph)
## The polygon from AttackShape.build_polygon() is assigned to BOTH Collision and
## Visual, which have identity transforms under this node -> identical areas.
## Projectile patterns use the area as a warning only (`deals_damage` = false) and
## emit `active_started` so the AttackRunner can fire the projectiles.

signal telegraph_started
signal active_started
signal active_ended
## Emitted right before the node frees itself.
signal finished

enum Phase { TELEGRAPH, ACTIVE, DONE }

var pattern: AttackPattern
## Effective (already scaled) telegraph duration.
var telegraph_time: float = 1.6
var active_time: float = 0.25
## Area damage during ACTIVE (false for projectile patterns).
var deals_damage: bool = true
## Attacker root, forwarded to Hitbox.source.
var source: Node = null
## Repeat index inside the running pattern (set by AttackRunner).
var repeat_index: int = 0
var phase: Phase = Phase.TELEGRAPH
var elapsed: float = 0.0

var hitbox: Hitbox
var collision: CollisionPolygon2D
var visual: Telegraph
var _polygon := PackedVector2Array()
var _polygons: Array[PackedVector2Array] = []
## Minimum physics frames the Hitbox is active (so active_time 0 still damages).
const MIN_ACTIVE_TICKS := 1
var _active_ticks := 0
var _age_ticks := 0


## Call before adding to the tree.
func configure(p_pattern: AttackPattern, p_telegraph_time: float, p_source: Node = null) -> void:
	pattern = p_pattern
	telegraph_time = maxf(0.0, p_telegraph_time)
	active_time = maxf(0.0, pattern.active_time)
	deals_damage = not pattern.is_projectile_attack()
	source = p_source
	_polygons = AttackShape.build_polygons(pattern)
	_polygon = _polygons[0] if not _polygons.is_empty() else PackedVector2Array()


func _ready() -> void:
	_ensure_children()
	if pattern:
		collision.polygon = _polygon
		collision.disabled = not deals_damage
		visual.polygons = _polygons
		visual.telegraph_color = pattern.telegraph_color
		visual.active_color = pattern.active_color
		visual.pulse_speed = pattern.pulse_speed
		hitbox.damage = pattern.damage
		hitbox.knockback_strength = pattern.knockback
		hitbox.tags = pattern.tags.duplicate()
	hitbox.source = source
	hitbox.active = false
	visual.area = self
	phase = Phase.TELEGRAPH
	telegraph_started.emit()
	if telegraph_time <= 0.0:
		_begin_active()


func _physics_process(delta: float) -> void:
	if phase == Phase.DONE:
		return
	elapsed += delta
	if phase == Phase.ACTIVE and _active_ticks >= MIN_ACTIVE_TICKS \
			and elapsed >= telegraph_time + active_time - 0.0001:
		_finish()
		return
	if phase == Phase.TELEGRAPH and elapsed >= telegraph_time - 0.0001:
		_begin_active()
	if phase == Phase.ACTIVE and _age_ticks >= 1:
		_active_ticks += 1
	_age_ticks += 1


func is_active() -> bool:
	return phase == Phase.ACTIVE

func get_telegraph_progress() -> float:
	if phase != Phase.TELEGRAPH:
		return 1.0
	return clampf(elapsed / telegraph_time, 0.0, 1.0) if telegraph_time > 0.0 else 1.0

## Local polygon shared by telegraph and collision (area attacks; first lane for projectiles).
func get_polygon() -> PackedVector2Array:
	return _polygon

## All local polygons (area: 1; projectile pattern: one lane per projectile).
func get_polygons() -> Array[PackedVector2Array]:
	return _polygons

func get_telegraph_polygon_global(index: int = 0) -> PackedVector2Array:
	return visual.global_transform * visual.polygons[index]

func get_collision_polygon_global() -> PackedVector2Array:
	return collision.global_transform * collision.polygon

## Stops immediately without emitting `finished` (used by AttackRunner.cancel()).
func cancel() -> void:
	phase = Phase.DONE
	if hitbox:
		hitbox.deactivate()
	queue_free()


func _begin_active() -> void:
	phase = Phase.ACTIVE
	if deals_damage:
		hitbox.activate()
	active_started.emit()
	# active_time 0 still gets one physics frame of damage: _finish() only runs
	# from _physics_process, after the Hitbox has had its overlap check.

func _finish() -> void:
	if phase == Phase.DONE:
		return
	phase = Phase.DONE
	hitbox.deactivate()
	active_ended.emit()
	finished.emit()
	queue_free()

func _ensure_children() -> void:
	hitbox = get_node_or_null(^"Hitbox") as Hitbox
	if hitbox == null:
		hitbox = Hitbox.new()
		hitbox.name = "Hitbox"
		add_child(hitbox)
	hitbox.collision_layer = Layers.ENEMY_ATTACK
	hitbox.collision_mask = Layers.PLAYER
	collision = hitbox.get_node_or_null(^"Collision") as CollisionPolygon2D
	if collision == null:
		collision = CollisionPolygon2D.new()
		collision.name = "Collision"
		hitbox.add_child(collision)
	visual = get_node_or_null(^"Visual") as Telegraph
	if visual == null:
		visual = Telegraph.new()
		visual.name = "Visual"
		visual.z_index = -1
		add_child(visual)
