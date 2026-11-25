class_name DripVisual
extends Node2D
## Placeholder look of a DripEmitter (parent): a bottle lying on its side (mouth
## at the origin), a drop that forms and falls during the telegraph, and a thin
## trickle while the puddles are on. Swap freely (optional `bottle_texture`).

@export var bottle_texture: Texture2D
@export var glass_color: Color = Color(0.4, 0.6, 0.6)
@export var juice_color: Color = Color(0.9, 0.58, 0.2)
@export var line_color: Color = Color(0.1, 0.06, 0.08)

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var p := get_parent() as DripEmitter
	if p == null:
		return
	if bottle_texture:
		draw_texture(bottle_texture, Vector2(0, -bottle_texture.get_height()))
	else:
		draw_set_transform(Vector2(6, -4), -0.35)
		draw_rect(Rect2(-1, -6, 22, 12), line_color)
		draw_rect(Rect2(0, -5, 20, 10), glass_color)
		draw_rect(Rect2(0, 1, 20, 4), juice_color)
		draw_rect(Rect2(-7, -3, 8, 6), line_color)
		draw_rect(Rect2(-6, -2, 7, 4), glass_color)
		draw_set_transform(Vector2.ZERO)
	var fall := p.get_drip_distance()
	var tp := p.get_telegraph_progress()
	if tp > 0.0:
		if tp < 0.5:
			draw_circle(Vector2(0, 1 + tp * 4.0), 1.0 + tp * 2.0, juice_color)
		else:
			var k := (tp - 0.5) / 0.5
			draw_circle(Vector2(0, 3 + k * k * (fall - 3)), 1.8, juice_color)
	elif p.is_on:
		draw_line(Vector2(0, 2), Vector2(0, fall), Color(juice_color, 0.45), 1.0)
		draw_circle(Vector2(0, fmod(_t * 90.0, maxf(fall, 1.0))), 1.2, juice_color)
