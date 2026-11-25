class_name SpikesVisual
extends Node2D
## Placeholder look of Spikes (parent): red/white triangles across parent.width.

@export var spike_color: Color = Color(0.85, 0.2, 0.24)
@export var tip_color: Color = Color(0.96, 0.93, 0.9)
@export var line_color: Color = Color(0.1, 0.06, 0.08)


func _draw() -> void:
	var width: float = get_parent().get(&"width") if get_parent() else 32.0
	var height: float = get_parent().get(&"height") if get_parent() else 10.0
	var n := maxi(1, roundi(width / 8.0))
	var w := width / n
	for i in n:
		var l := -width * 0.5 + i * w
		var tri := PackedVector2Array([Vector2(l, 0), Vector2(l + w * 0.5, -height), Vector2(l + w, 0)])
		draw_colored_polygon(tri, spike_color)
		draw_colored_polygon(PackedVector2Array([Vector2(l + w * 0.33, -height * 0.66),
			Vector2(l + w * 0.5, -height), Vector2(l + w * 0.67, -height * 0.66)]), tip_color)
		draw_polyline(tri, line_color, 1.0)
