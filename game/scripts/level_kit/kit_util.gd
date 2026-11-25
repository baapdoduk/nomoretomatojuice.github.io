class_name KitUtil
extends RefCounted
## Small shared helpers for level-kit components.

## True for a live player body (group "player", not dead). Works with stand-ins
## that only implement the methods a component needs.
static func is_live_player(body: Node) -> bool:
	if body == null or not body.is_in_group(Layers.GROUP_PLAYER):
		return false
	return not (body.has_method(&"is_dead") and bool(body.call(&"is_dead")))


## Ensures `area` has a rectangle CollisionShape2D of `size` centred at `center`
## (only when it has no shape child yet). Returns the shape node.
static func ensure_rect_shape(area: CollisionObject2D, size: Vector2, center: Vector2) -> CollisionShape2D:
	for child in area.get_children():
		if child is CollisionShape2D:
			return child
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	area.add_child(shape)
	return shape


## Draws a simple 4-point sparkle (cross with tapered arms).
static func draw_sparkle(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_line(pos + Vector2(-radius, 0), pos + Vector2(radius, 0), color, 1.0)
	ci.draw_line(pos + Vector2(0, -radius), pos + Vector2(0, radius), color, 1.0)
	ci.draw_rect(Rect2(pos - Vector2(1, 1), Vector2(2, 2)), color)
