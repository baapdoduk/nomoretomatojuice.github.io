class_name StickyPuddle
extends Area2D
## Sticky juice puddle (level gimmick). While a player body is inside (and the puddle is
## `active`) it calls player.set_surface_modifier(self, speed_mult, jump_mult,
## accel_mult); on exit / deactivation player.clear_surface_modifier(self).
## Bodies without that API are ignored (has_method guard).
## Origin = centre of the puddle on the floor surface (y = 0 is the floor top).
## Layer: none, mask: Player.
## Visuals: swappable `Visual` child (placeholder: PuddleVisual) reading `width`
## and `amount` (0..1 size, eased toward `active`).

signal activated_changed(active: bool)

@export var width: float = 48.0:
	set(v):
		width = maxf(8.0, v)
@export var speed_mult: float = 0.55
@export var jump_mult: float = 0.75
@export var accel_mult: float = 0.6
@export var active: bool = true:
	set = set_active
## Seconds for the grow / shrink animation.
@export var grow_time: float = 0.3

## 0..1 visual size (animated toward active).
var amount: float = 1.0
var _bodies: Array[Node2D] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	KitUtil.ensure_rect_shape(self, Vector2(width - 4.0, 8.0), Vector2(0, -3.0))
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	amount = 1.0 if active else 0.0


func set_active(value: bool) -> void:
	if value == active:
		return
	active = value
	if not is_inside_tree():
		return
	for b in _bodies:
		if is_instance_valid(b):
			if active:
				_apply(b)
			else:
				_clear(b)
	activated_changed.emit(active)


## Bodies currently standing in the puddle.
func get_bodies() -> Array[Node2D]:
	return _bodies.duplicate()


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method(&"set_surface_modifier") or _bodies.has(body):
		return
	_bodies.append(body)
	if active:
		_apply(body)


func _on_body_exited(body: Node2D) -> void:
	if not _bodies.has(body):
		return
	_bodies.erase(body)
	_clear(body)


func _exit_tree() -> void:
	for b in _bodies:
		if is_instance_valid(b):
			_clear(b)
	_bodies.clear()


func _apply(body: Node) -> void:
	body.call(&"set_surface_modifier", self, speed_mult, jump_mult, accel_mult)


func _clear(body: Node) -> void:
	if body.has_method(&"clear_surface_modifier"):
		body.call(&"clear_surface_modifier", self)


func _process(delta: float) -> void:
	amount = move_toward(amount, 1.0 if active else 0.0, delta / maxf(grow_time, 0.01))

