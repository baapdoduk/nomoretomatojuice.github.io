class_name Telegraph
extends Node2D
## Placeholder floor warning for an attack area (presentation only).
## Draws the exact polygon it is given. Cues are not colour-only:
## - telegraph: thin pulsing outline + inner fill that GROWS from the origin with progress
## - active: full solid fill + thick double outline + hatching
## Follows an AttackArea (`area`) if set, otherwise `progress` / `is_active` can be driven manually.

@export var polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		polygon = value
		queue_redraw()
@export var telegraph_color: Color = Color(1.0, 0.55, 0.1, 1.0)
@export var active_color: Color = Color(1.0, 0.15, 0.15, 1.0)
@export var pulse_speed: float = 3.0
@export var outline_width: float = 1.5
@export var active_outline_width: float = 3.0
## 0..1 telegraph progress (driven by `area` when set).
@export_range(0.0, 1.0) var progress: float = 0.0
@export var is_active: bool = false

## AttackArea to follow (set by AttackArea). Polls progress/phase every frame.
var area: Node = null
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	if area and is_instance_valid(area):
		progress = area.get_telegraph_progress()
		is_active = area.is_active()
	queue_redraw()


func _draw() -> void:
	if polygon.size() < 3:
		return
	if is_active:
		var c := active_color
		draw_colored_polygon(polygon, Color(c, 0.55))
		_draw_hatch(Color(c.lightened(0.4), 0.8))
		_outline(polygon, Color(c.lightened(0.5), 1.0), active_outline_width)
		var inner := _scaled(polygon, 0.85)
		_outline(inner, Color(1, 1, 1, 0.9), 1.0)
	else:
		var c := telegraph_color
		var pulse := 0.5 + 0.5 * sin(_time * TAU * pulse_speed)
		draw_colored_polygon(polygon, Color(c, 0.12))
		if progress > 0.001:
			draw_colored_polygon(_scaled(polygon, clampf(progress, 0.0, 1.0)), Color(c, 0.35 + 0.15 * pulse))
		_outline(polygon, Color(c, 0.6 + 0.4 * pulse), outline_width + pulse)


func _outline(pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, color, width, true)

## Scales around the local origin (circle centre / cone & line apex).
func _scaled(pts: PackedVector2Array, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * f)
	return out

func _draw_hatch(color: Color) -> void:
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for p in polygon:
		rect = rect.expand(p)
	var step := 10.0
	var x := rect.position.x - rect.size.y
	while x < rect.end.x:
		var a := Vector2(x, rect.position.y)
		var b := Vector2(x + rect.size.y, rect.end.y)
		var clipped := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), polygon)
		for seg in clipped:
			draw_polyline(seg, color, 1.0)
		x += step
