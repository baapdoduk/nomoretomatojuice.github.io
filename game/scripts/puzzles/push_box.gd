class_name PushBox
extends AnimatableBody2D
## Physics-free grid push box (group `pushable`, World layer, also blocks light).
##
## Approach: interaction-driven grid push. Using the child Interactable moves the
## box one `grid_size` cell away from the actor along the dominant axis (vertical
## pushes only when `allow_vertical`, i.e. top-down maps). A push is refused when
## the destination overlaps any solid body (walls, other boxes, the player...).
## There is no gravity: in side-view maps place boxes on floors and keep their
## push lanes level. reset() returns the box to its start position (deferred while
## a player / pushable stands there), so a box can never be lost or soft-lock a room.
## (AnimatableBody2D = kinematic, so Area2D-based PressurePlates detect it; a
## StaticBody2D would not be reported by areas.)

signal pushed(direction: Vector2)
signal push_blocked(direction: Vector2)
signal reset_done

## Cell size of one push (<= 0: use config.push_grid_size).
@export var grid_size: float = 0.0
## Allow up/down pushes (top-down). Side-view maps keep this off.
@export var allow_vertical: bool = true
## Collision size of the auto-created shape.
@export var box_size: Vector2 = Vector2(16, 16)
@export var config: PuzzleConfig
## Interactable that pushes the box (optional; auto-found/created).
@export var interactable: Interactable

var start_position: Vector2
var is_moving: bool = false

var _pending_reset := false
var _tween: Tween


func _ready() -> void:
	add_to_group(Layers.GROUP_PUSHABLE)
	collision_layer = Layers.WORLD
	sync_to_physics = false
	start_position = global_position
	PuzzlePhysics.ensure_rect_shape(self, box_size)
	interactable = PuzzlePhysics.ensure_interactable(self, interactable, "Push", maxf(box_size.x, box_size.y) * 0.75)
	interactable.interacted.connect(_on_interacted)
	set_physics_process(false)


## Cell size actually used.
func get_grid_size() -> float:
	return grid_size if grid_size > 0.0 else PuzzleConfig.resolve(config).push_grid_size


## Push direction for an actor at `actor_pos` (dominant axis, away from the actor).
func direction_from(actor_pos: Vector2) -> Vector2:
	var d := global_position - actor_pos
	if not allow_vertical or absf(d.x) >= absf(d.y):
		return Vector2(signf(d.x) if d.x != 0.0 else 1.0, 0.0)
	return Vector2(0.0, signf(d.y))


## True when the cell in `direction` is free. Needs the space state (physics frame).
func can_push(direction: Vector2) -> bool:
	if is_moving or direction == Vector2.ZERO:
		return false
	if direction.y != 0.0 and not allow_vertical:
		return false
	return _is_free_at(global_position + direction.normalized() * get_grid_size(), false)


## Pushes one cell. Returns false (and emits push_blocked) when blocked. Physics frame only.
func push(direction: Vector2) -> bool:
	direction = direction.normalized()
	if not can_push(direction):
		push_blocked.emit(direction)
		return false
	var target := global_position + direction * get_grid_size()
	is_moving = true
	var t := PuzzleConfig.resolve(config).push_time
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.tween_property(self, "global_position", target, t)
	_tween.tween_callback(_on_move_finished)
	pushed.emit(direction)
	return true


## Returns to the start position (deferred until no player / pushable is in the way).
func reset() -> void:
	if _tween:
		_tween.kill()
	is_moving = false
	_pending_reset = true
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not _pending_reset:
		set_physics_process(false)
		return
	if global_position.is_equal_approx(start_position) or _is_free_at(start_position, true):
		global_position = start_position
		_pending_reset = false
		set_physics_process(false)
		LightTracer.notify_changed(get_tree())
		reset_done.emit()


func _is_free_at(pos: Vector2, protected_only: bool) -> bool:
	var space := PuzzlePhysics.space_of(self)
	if space == null:
		return false
	var xform := Transform2D(global_rotation, pos)
	for node in PuzzlePhysics.collect_solid_shapes(self):
		for pair: Array in PuzzlePhysics.shapes_of(node):
			var local_xform: Transform2D = global_transform.affine_inverse() * (pair[1] as Transform2D)
			var shape_xform: Transform2D = xform * local_xform
			if protected_only:
				if not PuzzlePhysics.find_protected_bodies(space, pair[0], shape_xform, [get_rid()]).is_empty():
					return false
			elif _overlaps_solid(space, pair[0], shape_xform):
				return false
	return true


func _overlaps_solid(space: PhysicsDirectSpaceState2D, shape: Shape2D, xform: Transform2D) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	# Shrink slightly so boxes resting flush against walls can still slide along them.
	params.transform = xform.scaled_local(Vector2(0.9, 0.9))
	params.collision_mask = Layers.WORLD | Layers.PLAYER | Layers.ENEMY
	params.exclude = [get_rid()]
	return not space.intersect_shape(params, 1).is_empty()


func _on_move_finished() -> void:
	is_moving = false
	LightTracer.notify_changed(get_tree())


func _on_interacted(actor: Node) -> void:
	var actor_pos: Vector2 = actor.global_position if actor is Node2D else global_position - Vector2.RIGHT
	await get_tree().physics_frame
	if is_instance_valid(self):
		push(direction_from(actor_pos))
