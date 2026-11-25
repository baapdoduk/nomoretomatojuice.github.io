@tool
class_name Landmark
extends Node2D
## Large, readable destination marker ("show the goal early"): a tall beacon
## with a pulsing light and an optional caption. Pure presentation; place it
## where the player should head and keep it visible from the start area.
## Origin = base of the beacon.

@export var caption: String = "GOAL":
	set(v):
		caption = v
		queue_redraw()
@export var height: float = 96.0:
	set(v):
		height = v
		queue_redraw()
@export var width: float = 20.0:
	set(v):
		width = v
		queue_redraw()
@export var color: Color = Color(1.0, 0.8, 0.3):
	set(v):
		color = v
		queue_redraw()
@export var pulse_speed: float = 2.0

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-width * 0.5, -height, width, height), color.darkened(0.45))
	draw_rect(Rect2(-width * 0.5, -height, width, height), color, false, 2.0)
	var glow := 0.5 + 0.5 * sin(_t * pulse_speed)
	var top := Vector2(0, -height - width * 0.6)
	draw_circle(top, width * (1.2 + glow * 0.4), Color(color.r, color.g, color.b, 0.25))
	draw_circle(top, width * 0.6, color)
	if caption != "":
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, top + Vector2(-w * 0.5, -width * 1.6), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
