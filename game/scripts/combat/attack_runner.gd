class_name AttackRunner
extends Node2D
## Executes an AttackPattern from this node's global position toward a target.
##
## Target = `target` if set, else the first node in group "player" (may be absent:
## then the attack aims along `forward`, rotated by this node's global rotation).
## Spawned AttackAreas / Projectiles are top_level children of the runner, so they
## stay in world space and cancel() / freeing the runner removes them.
## Timeline: repeat i spawns at i * repeat_interval; when every repeat's active
## window has ended -> `attacks_resolved`, then recovery -> `pattern_finished`.
## Telegraph and recovery are multiplied by GameState.get_combat_timing_scale().

signal telegraph_started(pattern: AttackPattern, repeat_index: int)
signal active_started(pattern: AttackPattern, repeat_index: int)
## Every active window of the pattern has ended (recovery begins).
signal attacks_resolved(pattern: AttackPattern)
signal pattern_finished(pattern: AttackPattern)
signal area_spawned(area: AttackArea)
signal projectile_spawned(projectile: Projectile)
signal cancelled

## Attacker root used as damage source (defaults to owner, else parent).
@export var source: Node
## Explicit target; null = first node in group "player".
@export var target: Node2D
## Local aim direction used when there is no target.
@export var forward: Vector2 = Vector2.RIGHT
## Apply GameState.get_combat_timing_scale() to telegraph and recovery.
@export var use_timing_scale: bool = true
## Optional custom AttackArea scene (root must be an AttackArea). Null = built in code.
@export var attack_area_scene: PackedScene
## Default projectile scene when the pattern has none (root must be a Projectile).
@export var projectile_scene: PackedScene

var pattern: AttackPattern
var is_running: bool = false
var is_recovering: bool = false
## Scale captured at run() (constant during one pattern).
var timing_scale: float = 1.0

var _elapsed := 0.0
var _spawned_repeats := 0
var _resolved_repeats := 0
var _recovery_left := 0.0
var _recovery_time := 0.0
var _first_origin := Vector2.ZERO
var _first_angle := 0.0
var _spawned: Array[Node] = []


func _ready() -> void:
	if source == null:
		source = owner if owner else get_parent()


## Starts `p_pattern` (cancels a running one). recovery_override >= 0 replaces the
## pattern's recovery_time (before timing scale).
func run(p_pattern: AttackPattern, recovery_override: float = -1.0) -> void:
	if p_pattern == null:
		push_warning("AttackRunner.run: null pattern")
		return
	if is_running:
		cancel()
	pattern = p_pattern
	is_running = true
	is_recovering = false
	timing_scale = GameState.get_combat_timing_scale() if use_timing_scale else 1.0
	_recovery_time = (recovery_override if recovery_override >= 0.0 else pattern.recovery_time) * timing_scale
	_elapsed = 0.0
	_spawned_repeats = 0
	_resolved_repeats = 0
	_spawn_due()


## Stops the pattern and frees every spawned area / projectile.
func cancel() -> void:
	var was_running := is_running
	is_running = false
	is_recovering = false
	for node in _spawned:
		if is_instance_valid(node):
			if node is AttackArea:
				(node as AttackArea).cancel()
			elif node is Projectile:
				(node as Projectile).despawn(&"cancelled")
			else:
				node.queue_free()
	_spawned.clear()
	if was_running:
		cancelled.emit()

func get_telegraph_time() -> float:
	return pattern.telegraph_time * timing_scale if pattern else 0.0

func get_recovery_time() -> float:
	return _recovery_time

## Live spawned areas / projectiles.
func get_spawned() -> Array[Node]:
	var out: Array[Node] = []
	for n in _spawned:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			out.append(n)
	return out

func get_target() -> Node2D:
	if target and is_instance_valid(target):
		return target
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(Layers.GROUP_PLAYER) as Node2D


func _physics_process(delta: float) -> void:
	if not is_running:
		return
	if is_recovering:
		_recovery_left -= delta
		if _recovery_left <= 0.0001:
			_finish()
		return
	_elapsed += delta
	_spawn_due()


func _spawn_due() -> void:
	while is_running and not is_recovering and _spawned_repeats < pattern.repeat_count \
			and _elapsed >= float(_spawned_repeats) * pattern.repeat_interval - 0.0001:
		var index := _spawned_repeats
		_spawned_repeats += 1
		_spawn_repeat(index)


func _spawn_repeat(index: int) -> void:
	var placement := compute_placement(index)
	var area: AttackArea = null
	if attack_area_scene:
		area = attack_area_scene.instantiate() as AttackArea
	if area == null:
		area = AttackArea.new()
	area.configure(pattern, pattern.telegraph_time * timing_scale, source)
	area.repeat_index = index
	area.top_level = true
	area.name = "AttackArea%d" % index
	area.active_started.connect(_on_area_active.bind(area))
	area.finished.connect(_on_area_finished)
	_prune()
	# top_level: local transform == global transform (set before _ready runs).
	area.position = placement[0]
	area.rotation = placement[1]
	_spawned.append(area)
	add_child(area)
	area_spawned.emit(area)
	telegraph_started.emit(pattern, index)


## Returns [global_origin: Vector2, angle: float] for repeat `index`.
func compute_placement(index: int) -> Array:
	if index > 0 and pattern.repeat_targeting != AttackPattern.RepeatTargeting.FOLLOW_TARGET:
		var angle0 := _first_angle
		if pattern.aim == AttackPattern.Aim.ROTATING:
			angle0 += deg_to_rad(pattern.aim_step_degrees * index)
		if pattern.repeat_targeting == AttackPattern.RepeatTargeting.STEP_LINE:
			return [_first_origin + Vector2.from_angle(_first_angle) * pattern.repeat_step_distance * index, angle0]
		return [_first_origin, angle0]
	var self_pos := global_position
	var tgt := get_target()
	var fwd := forward.rotated(global_rotation)
	var angle := fwd.angle()
	match pattern.aim:
		AttackPattern.Aim.TOWARD_TARGET:
			if tgt and tgt.global_position.distance_squared_to(self_pos) > 0.01:
				angle = (tgt.global_position - self_pos).angle()
		AttackPattern.Aim.FIXED_ANGLE:
			angle = deg_to_rad(pattern.fixed_angle_degrees)
		AttackPattern.Aim.ROTATING:
			angle = deg_to_rad(pattern.fixed_angle_degrees + pattern.aim_step_degrees * index)
	var origin := self_pos
	if pattern.origin == AttackPattern.Origin.TARGET and tgt:
		origin = tgt.global_position
	var offset := pattern.origin_offset.rotated(angle) if pattern.offset_follows_aim else pattern.origin_offset
	origin += offset
	if index == 0:
		_first_origin = origin
		_first_angle = angle
	return [origin, angle]


func _on_area_active(area: AttackArea) -> void:
	if not is_running:
		return
	if pattern.is_projectile_attack():
		_fire_projectiles(area.global_position, area.global_rotation)
	active_started.emit(pattern, area.repeat_index)

func _fire_projectiles(origin: Vector2, angle: float) -> void:
	var scene := pattern.projectile_scene if pattern.projectile_scene else projectile_scene
	for offset in AttackShape.projectile_angles(pattern):
		var a := angle + offset
		var p: Projectile = null
		if scene:
			p = scene.instantiate() as Projectile
		if p == null:
			p = Projectile.new()
		p.configure(Vector2.from_angle(a) * pattern.projectile_speed, pattern.damage, pattern.knockback,
			pattern.projectile_lifetime, pattern.projectile_radius, source)
		p.tags = pattern.tags.duplicate()
		p.color = pattern.active_color.lightened(0.5)
		p.top_level = true
		p.position = origin
		_spawned.append(p)
		add_child(p)
		projectile_spawned.emit(p)

func _on_area_finished() -> void:
	if not is_running:
		return
	_resolved_repeats += 1
	if _resolved_repeats >= pattern.repeat_count and _spawned_repeats >= pattern.repeat_count:
		is_recovering = true
		_recovery_left = _recovery_time
		attacks_resolved.emit(pattern)
		if _recovery_left <= 0.0:
			_finish()

func _finish() -> void:
	is_running = false
	is_recovering = false
	var finished_pattern := pattern
	pattern_finished.emit(finished_pattern)

func _prune() -> void:
	var keep: Array[Node] = []
	for n in _spawned:
		if is_instance_valid(n):
			keep.append(n)
	_spawned = keep
