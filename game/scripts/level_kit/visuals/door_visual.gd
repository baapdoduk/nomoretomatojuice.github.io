class_name DoorVisual
extends Node2D
## Placeholder look of a MemoryDoor (parent): arched frame whose leaf narrows
## and lets light out as parent.open_amount goes 0 -> 1. Swap freely.

@export var frame_color: Color = Color(0.35, 0.3, 0.4)
@export var door_color: Color = Color(0.55, 0.45, 0.6)
@export var light_color: Color = Color(1.0, 0.88, 0.55)
@export var line_color: Color = Color(0.1, 0.06, 0.08)
@export var width: float = 18.0
@export var height: float = 30.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var open: float = get_parent().get(&"open_amount") if get_parent() else 0.0
	var w := width
	var h := height
	draw_rect(Rect2(-w * 0.5 - 3, -h, w + 6, h), line_color)
	draw_circle(Vector2(0, -h), w * 0.5 + 3, line_color)
	draw_rect(Rect2(-w * 0.5 - 2, -h, w + 4, h), frame_color)
	draw_circle(Vector2(0, -h), w * 0.5 + 2, frame_color)
	var glow := 0.3 + open * 0.7
	draw_rect(Rect2(-w * 0.5, -h, w, h), Color(light_color, glow))
	draw_circle(Vector2(0, -h), w * 0.5, Color(light_color, glow))
	var leaf := w * (1.0 - open * 0.85)
	draw_rect(Rect2(-w * 0.5, -h + 1, leaf, h - 1), door_color)
	if leaf > 4.0:
		draw_rect(Rect2(-w * 0.5 + leaf * 0.5 - 3.5, -h * 0.6 - 4, 7, 8), Color(0.96, 0.94, 0.88))
