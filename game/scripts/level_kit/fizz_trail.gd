@tool
class_name FizzTrail
extends Node2D
## Places `count` FizzPickups along a jump arc (or a straight line) from this
## node's origin to `end_point` (local). The pickups are created at runtime (not
## saved in the scene); the editor shows a dotted preview of the arc.
## arc_height > 0 bulges upward (screen up), like a jump.

enum Shape { ARC, LINE }

@export_range(1, 64) var count: int = 5:
	set(v):
		count = maxi(1, v)
		queue_redraw()
@export var end_point: Vector2 = Vector2(96, 0):
	set(v):
		end_point = v
		queue_redraw()
## Extra height (px) of the arc's midpoint above the straight line.
@export var arc_height: float = 40.0:
	set(v):
		arc_height = v
		queue_redraw()
@export var shape: Shape = Shape.ARC:
	set(v):
		shape = v
		queue_redraw()
@export var pickup_scene: PackedScene = preload("res://scenes/level_kit/fizz_pickup.tscn")

var _spawned: Array[Node] = []


func _ready() -> void:
	if not Engine.is_editor_hint():
		rebuild()


## Local positions of the pickups.
func get_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var p := end_point * t
		if shape == Shape.ARC:
			p.y -= 4.0 * arc_height * t * (1.0 - t)
		pts.append(p)
	return pts


## (Re)creates the pickups. Returns them.
func rebuild() -> Array[Node]:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	if pickup_scene == null:
		return _spawned
	for p in get_points():
		var fizz := pickup_scene.instantiate() as Node2D
		fizz.position = p
		add_child(fizz)
		_spawned.append(fizz)
	return _spawned


func get_pickups() -> Array[Node]:
	return _spawned.filter(func(n: Node) -> bool: return is_instance_valid(n))


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	for p in get_points():
		draw_circle(p, 5.0, Color(0.72, 0.95, 1.0, 0.5))
		draw_arc(p, 5.0, 0, TAU, 12, Color(0.35, 0.8, 0.85), 1.0)
