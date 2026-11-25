@tool
class_name OneWayPlatform
extends StaticBody2D
## Jump-through platform (side view). Layer World, one-way collision upward.
## Down + jump drops through (SideViewMotor, group "one_way_platform").
## Resize with `width`; the collision shape and placeholder visual follow.

@export var width: float = 64.0:
	set(value):
		width = maxf(4.0, value)
		_apply()
@export var thickness: float = 6.0:
	set(value):
		thickness = maxf(2.0, value)
		_apply()
@export var color: Color = Color(0.55, 0.45, 0.3):
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	add_to_group(&"one_way_platform")
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
	shape.one_way_collision = true
	(shape.shape as RectangleShape2D).size = Vector2(width, thickness)
	shape.position = Vector2(0, thickness * 0.5)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-width * 0.5, 0, width, thickness), color)
	draw_line(Vector2(-width * 0.5, 0), Vector2(width * 0.5, 0), color.lightened(0.3), 1.0)
