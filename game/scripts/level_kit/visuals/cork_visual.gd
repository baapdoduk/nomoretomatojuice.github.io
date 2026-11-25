class_name CorkVisual
extends Node2D
## Placeholder look of a Cork (parent): wobbling rounded blob with eyes that
## look along parent.direction; flashes while parent.hurt_flash > 0. Swap freely.

@export var body_color: Color = Color(0.8, 0.62, 0.4)
@export var band_color: Color = Color(0.35, 0.35, 0.4)
@export var line_color: Color = Color(0.1, 0.06, 0.08)

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var p := get_parent()
	var dir: int = p.get(&"direction") if p else -1
	var flash: float = p.get(&"hurt_flash") if p else 0.0
	draw_set_transform(Vector2.ZERO, sin(_t * 9.0) * 0.12)
	var col := body_color.lerp(Color.WHITE, 0.7) if flash > 0.0 else body_color
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(8, -13), Vector2(-8, -13)]), col)
	draw_circle(Vector2(0, -13), 8.0, col)
	draw_polyline(PackedVector2Array([Vector2(-8, -13), Vector2(-6, 0), Vector2(6, 0), Vector2(8, -13)]), line_color, 1.0)
	draw_arc(Vector2(0, -13), 8.0, PI, TAU, 12, line_color, 1.0)
	draw_rect(Rect2(-7, -9, 14, 2), band_color)
	draw_rect(Rect2(Vector2(dir * 2 - 3, -14), Vector2(2, 3)), line_color)
	draw_rect(Rect2(Vector2(dir * 2 + 1, -14), Vector2(2, 3)), line_color)
	draw_set_transform(Vector2.ZERO)
