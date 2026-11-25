class_name AfterImage
extends Node2D
## Fading silhouette left behind while dashing. World-space (top_level), draws
## a rounded body shape and frees itself after `lifetime`.

## Seconds until fully transparent.
@export var lifetime: float = 0.22
@export var color: Color = Color(0.6, 0.9, 1.0, 0.55)
@export var size: Vector2 = Vector2(14, 18)
@export var corner_radius: float = 5.0

var _t: float = 0.0


## Spawns an after-image at `global_pos` under `parent` (scale.x < 0 flips).
static func spawn(parent: Node, global_pos: Vector2, p_size: Vector2, p_color: Color,
		p_lifetime: float = 0.22, flip: bool = false) -> AfterImage:
	if parent == null or not parent.is_inside_tree():
		return null
	var a := AfterImage.new()
	a.top_level = true
	a.size = p_size
	a.color = p_color
	a.lifetime = p_lifetime
	a.scale.x = -1.0 if flip else 1.0
	parent.add_child(a)
	a.global_position = global_pos
	return a


func _process(delta: float) -> void:
	_t += delta
	if _t >= lifetime:
		queue_free()
		return
	modulate.a = 1.0 - _t / lifetime
	queue_redraw()


func _draw() -> void:
	var pts := PlayerVisual.rounded_rect_points(Rect2(Vector2(-size.x * 0.5, -size.y), size), corner_radius)
	draw_colored_polygon(pts, color)
