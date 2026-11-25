class_name FizzVisual
extends Node2D
## Placeholder look of a FizzPickup (parent): bobbing bubble, ring pop.
## Swap this child for a Sprite/AnimatedSprite scene; read parent.pop_progress.

@export var radius: float = 5.0
@export var bob_height: float = 2.0
@export var bob_speed: float = 3.0
@export var fill_color: Color = Color(0.75, 0.93, 1.0, 0.85)
@export var line_color: Color = Color(0.3, 0.6, 0.75)
@export var shine_color: Color = Color(1, 1, 1, 0.95)

var _t: float = 0.0


func _ready() -> void:
	_t = fmod(global_position.x * 0.05, TAU)  # neighbours bob out of phase


func _process(delta: float) -> void:
	_t += delta * bob_speed
	queue_redraw()


func _draw() -> void:
	var pop: float = get_parent().get(&"pop_progress") if get_parent() else -1.0
	var c := Vector2(0, sin(_t) * bob_height)
	if pop >= 0.0:
		draw_arc(c, radius * (1.0 + pop), 0.0, TAU, 16, Color(line_color, 1.0 - pop), 1.0)
		return
	draw_circle(c, radius, fill_color)
	draw_arc(c, radius, 0.0, TAU, 16, line_color, 1.0)
	draw_circle(c + Vector2(-radius, -radius) * 0.35, radius * 0.28, shine_color)
