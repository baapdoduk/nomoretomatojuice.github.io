extends Control
## Controller Lab widget: draws one analog stick - outer range, dead-zone circle,
## raw position (grey) and processed position (yellow).

var title: String = "Stick"
## Raw device axes (-1..1).
var raw := Vector2.ZERO:
	set(v):
		raw = v
		queue_redraw()
## Processed vector (e.g. Input.get_vector result).
var processed := Vector2.ZERO:
	set(v):
		processed = v
		queue_redraw()
var deadzone: float = 0.2:
	set(v):
		deadzone = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(64, 64)


## Same radial dead-zone math as Input.get_vector (used for the right stick,
## which has no Input Map actions).
static func apply_radial_deadzone(v: Vector2, dz: float) -> Vector2:
	var length := v.length()
	if length <= dz:
		return Vector2.ZERO
	var scaled := inverse_lerp(dz, 1.0, minf(length, 1.0))
	return v / length * scaled


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(c, r, Color(0.12, 0.12, 0.18))
	draw_arc(c, r, 0.0, TAU, 32, Color(0.5, 0.5, 0.6), 1.0)
	draw_circle(c, r * deadzone, Color(0.6, 0.2, 0.2, 0.35))
	draw_arc(c, r * deadzone, 0.0, TAU, 24, Color(0.9, 0.3, 0.3), 1.0)
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(1, 1, 1, 0.15))
	draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(1, 1, 1, 0.15))
	draw_circle(c + raw.limit_length(1.0) * r, 3.0, Color(0.7, 0.7, 0.7))
	draw_circle(c + processed.limit_length(1.0) * r, 2.5, Color(1.0, 0.85, 0.2))
