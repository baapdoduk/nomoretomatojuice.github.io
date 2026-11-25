class_name ShardVisual
extends Node2D
## Placeholder look of a MemoryShard (parent): small tilted photo frame that
## floats; rises and fades while parent.collect_progress runs. Swap freely.

@export var texture: Texture2D
@export var frame_color: Color = Color(0.96, 0.94, 0.88)
@export var photo_color: Color = Color(0.45, 0.45, 0.55)
@export var line_color: Color = Color(0.1, 0.08, 0.1)

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var p: float = get_parent().get(&"collect_progress") if get_parent() else -1.0
	var lift := sin(_t * 2.2) * 1.5
	var a := 1.0
	if p >= 0.0:
		lift -= p * 14.0
		a = 1.0 - p
	draw_set_transform(Vector2(0, lift), sin(_t * 1.3) * 0.12 - 0.08)
	if texture:
		draw_texture(texture, -texture.get_size() * 0.5, Color(1, 1, 1, a))
	else:
		draw_rect(Rect2(-6, -7, 12, 14), Color(line_color, a))
		draw_rect(Rect2(-5, -6, 10, 12), Color(frame_color, a))
		draw_rect(Rect2(-4, -5, 8, 7), Color(photo_color, a))
	draw_set_transform(Vector2.ZERO)
