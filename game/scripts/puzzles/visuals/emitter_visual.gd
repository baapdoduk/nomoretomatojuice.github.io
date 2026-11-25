class_name EmitterVisual
extends Node2D
## Placeholder LightEmitter visual (presentation only; default emitter: parent).
## A housing box with a nozzle pointing along +X; powered = filled lens,
## unpowered = hollow lens.

@export var emitter: LightEmitter
@export var color: Color = Color(0.95, 0.85, 0.4)


func _ready() -> void:
	if emitter == null:
		emitter = get_parent() as LightEmitter
	if emitter:
		emitter.power_changed.connect(func(_p: bool) -> void: queue_redraw())
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-10, -7), Vector2(14, 14)), color.darkened(0.4), true)
	draw_rect(Rect2(Vector2(4, -4), Vector2(6, 8)), color.darkened(0.2), true)
	if emitter and emitter.powered:
		draw_circle(Vector2(-3, 0), 4.0, color)
	else:
		draw_arc(Vector2(-3, 0), 4.0, 0.0, TAU, 16, color, 1.5)
