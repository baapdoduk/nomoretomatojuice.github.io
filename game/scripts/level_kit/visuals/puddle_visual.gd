class_name PuddleVisual
extends Node2D
## Placeholder look of a StickyPuddle (parent): flat half-ellipse of
## parent.width scaled by parent.amount, with a moving gloss line. Swap freely.

@export var color: Color = Color(0.85, 0.55, 0.2, 0.9)
@export var gloss_color: Color = Color(1.0, 0.9, 0.65, 0.9)
@export var height: float = 4.0

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var p := get_parent()
	var amount: float = p.get(&"amount") if p else 1.0
	var width: float = p.get(&"width") if p else 48.0
	if amount <= 0.01:
		return
	var w := width * amount
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(Vector2(cos(a) * w * 0.5, sin(a) * height * amount))
	pts.append(Vector2(w * 0.5, 1))
	pts.append(Vector2(-w * 0.5, 1))
	draw_colored_polygon(pts, color)
	var gx := fmod(_t * 10.0, w) - w * 0.5
	draw_line(Vector2(gx - 3, -height * amount * 0.5), Vector2(gx + 2, -height * amount * 0.5), gloss_color, 1.0)
