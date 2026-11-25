class_name CushionVisual
extends Node2D
## Placeholder look of a CatnapCushion (parent): cushion + a curled cat that sits
## up with open eyes when parent.awake_amount >= 0.5. Swap for sprites freely.

@export var cushion_color: Color = Color(0.55, 0.5, 0.6)
@export var cat_color: Color = Color(0.95, 0.8, 0.3)
@export var line_color: Color = Color(0.1, 0.06, 0.08)

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var awake: float = get_parent().get(&"awake_amount") if get_parent() else 0.0
	draw_rect(Rect2(-15, -8, 30, 9), line_color)
	draw_rect(Rect2(-14, -7, 28, 7), cushion_color)
	if awake < 0.5:
		var b := sin(_t * 2.0) * 0.3
		draw_circle(Vector2(0, -10), 7.0 + b, line_color)
		draw_circle(Vector2(0, -10), 6.0 + b, cat_color)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -13), Vector2(-7, -17), Vector2(-5, -13)]), cat_color)
		draw_line(Vector2(-7, -11), Vector2(-5, -11), line_color, 1.0)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-5, -7), Vector2(5, -7), Vector2(3, -17), Vector2(-3, -17)]), cat_color)
		draw_circle(Vector2(0, -20), 4.5, cat_color)
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -23), Vector2(-3, -28), Vector2(-1, -24)]), cat_color)
		draw_colored_polygon(PackedVector2Array([Vector2(4, -23), Vector2(3, -28), Vector2(1, -24)]), cat_color)
		draw_rect(Rect2(-3, -21, 1, 2), line_color)
		draw_rect(Rect2(2, -21, 1, 2), line_color)
		draw_line(Vector2(5, -8), Vector2(9 + sin(_t * 3.0) * 2.0, -16), cat_color.darkened(0.3), 1.5)
