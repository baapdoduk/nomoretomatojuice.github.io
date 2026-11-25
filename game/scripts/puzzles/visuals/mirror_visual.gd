class_name MirrorVisual
extends Node2D
## Placeholder Mirror visual (child of the Mirror, rotates with it).
## Reflective face = bright line; a single-sided mirror draws back hatching.

@export var mirror: Mirror
@export var color: Color = Color(0.75, 0.9, 1.0)


func _ready() -> void:
	if mirror == null:
		mirror = get_parent() as Mirror
	queue_redraw()


func _draw() -> void:
	var length := mirror.mirror_length if mirror else 24.0
	var t := mirror.mirror_thickness if mirror else 4.0
	var h := length * 0.5
	draw_line(Vector2(-h, 0), Vector2(h, 0), color, t)
	if mirror and not mirror.double_sided:
		var n := 5
		for i in n + 1:
			var x := -h + length * i / n
			draw_line(Vector2(x, t * 0.5), Vector2(x - 3, t * 0.5 + 4), color.darkened(0.5), 1.0)
	draw_circle(Vector2.ZERO, 2.0, color.darkened(0.4))
