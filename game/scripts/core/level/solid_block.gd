@tool
class_name SolidBlock
extends StaticBody2D
## Placeholder solid geometry (floor / wall / ceiling) on the World layer.
## `size` drives the collision rectangle and the drawn rectangle; the origin is
## the top-left corner so blocks snap easily to a grid.

@export var size: Vector2 = Vector2(64, 16):
	set(value):
		size = value.max(Vector2(1, 1))
		_apply()
@export var color: Color = Color(0.32, 0.34, 0.42):
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_inside_tree():
		return
	var shape := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		add_child(shape)
	if not shape.shape is RectangleShape2D:
		shape.shape = RectangleShape2D.new()
	(shape.shape as RectangleShape2D).size = size
	shape.position = size * 0.5
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_line(Vector2.ZERO, Vector2(size.x, 0), color.lightened(0.25), 1.0)
