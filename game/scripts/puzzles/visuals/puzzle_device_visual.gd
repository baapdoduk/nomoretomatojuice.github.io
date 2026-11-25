class_name PuzzleDeviceVisual
extends Node2D
## Placeholder visual for any puzzle input (switch, plate, receiver, controller,
## sensor, gate). Presentation only: subscribes to `device.activated_changed`
## (default device: the parent). State is shown by SHAPE, not colour alone:
## OFF = hollow outline, ON = filled shape + inner check mark.
## Swap this node for sprites without touching logic.

enum Shape { CIRCLE, RECT, PLATE, LEVER, DIAMOND }

@export var device: Node
@export var shape: Shape = Shape.CIRCLE
@export var size: Vector2 = Vector2(16, 16)
@export var color: Color = Color(0.85, 0.85, 0.95)
@export var outline_width: float = 2.0

var _on := false


func _ready() -> void:
	if device == null:
		device = get_parent()
	if PuzzleInputs.is_input(device):
		device.connect(&"activated_changed", _on_changed)
	# The parent device finishes _ready after its children: read its state later.
	_sync.call_deferred()


func _sync() -> void:
	if PuzzleInputs.is_input(device):
		_on = device.call(&"is_active")
	queue_redraw()


func _on_changed(value: bool) -> void:
	_on = value
	queue_redraw()


func _draw() -> void:
	var half := size * 0.5
	match shape:
		Shape.CIRCLE:
			if _on:
				draw_circle(Vector2.ZERO, half.x, color)
			else:
				draw_arc(Vector2.ZERO, half.x, 0.0, TAU, 24, color, outline_width)
		Shape.RECT, Shape.PLATE:
			var h := half if shape == Shape.RECT else Vector2(half.x, half.y * (0.4 if _on else 1.0))
			var r := Rect2(-h, h * 2.0)
			if shape == Shape.PLATE:
				r.position.y = half.y - r.size.y # pressed plate sinks
			if _on:
				draw_rect(r, color, true)
			else:
				draw_rect(r, color, false, outline_width)
		Shape.LEVER:
			draw_rect(Rect2(Vector2(-half.x, half.y - 4), Vector2(size.x, 4)), color, true)
			var tip := Vector2(half.x * 0.8 if _on else -half.x * 0.8, -half.y)
			draw_line(Vector2(0, half.y - 4), tip, color, outline_width)
			draw_circle(tip, 3.0, color)
		Shape.DIAMOND:
			var pts := PackedVector2Array([Vector2(0, -half.y), Vector2(half.x, 0), Vector2(0, half.y), Vector2(-half.x, 0), Vector2(0, -half.y)])
			if _on:
				draw_colored_polygon(pts.slice(0, 4), color)
			else:
				draw_polyline(pts, color, outline_width)
	if _on and shape != Shape.LEVER:
		var c := Color(0.1, 0.1, 0.15)
		var s := minf(half.x, half.y) * 0.5
		draw_polyline(PackedVector2Array([Vector2(-s, 0), Vector2(-s * 0.2, s * 0.7), Vector2(s, -s * 0.6)]), c, 2.0)
