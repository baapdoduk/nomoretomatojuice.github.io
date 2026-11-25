class_name HeartsDisplay
extends Control
## Procedurally drawn health hearts (no textures). Set `current` / `maximum`
## (the HUD does this from GameState.health_changed). Swap for textures later via
## `full_texture` / `empty_texture`.

@export var current: int = 3:
	set(value):
		current = value
		queue_redraw()
@export var maximum: int = 3:
	set(value):
		maximum = maxi(0, value)
		_update_min_size()
		queue_redraw()
@export var heart_size: float = 12.0:
	set(value):
		heart_size = value
		_update_min_size()
		queue_redraw()
@export var spacing: float = 3.0
@export var full_color: Color = Color("#ff4d5e")
@export var empty_color: Color = Color(0.2, 0.18, 0.24, 0.9)
@export var outline_color: Color = Color(0.05, 0.03, 0.08)
@export var full_texture: Texture2D
@export var empty_texture: Texture2D


func _ready() -> void:
	_update_min_size()


func set_health(value: int, max_value: int) -> void:
	maximum = max_value
	current = value


func _update_min_size() -> void:
	custom_minimum_size = Vector2(maximum * (heart_size + spacing), heart_size)


func _draw() -> void:
	for i in maximum:
		var origin := Vector2(i * (heart_size + spacing), 0.0)
		var filled := i < current
		var tex := full_texture if filled else empty_texture
		if tex:
			draw_texture_rect(tex, Rect2(origin, Vector2(heart_size, heart_size)), false)
		else:
			_draw_heart(origin, heart_size, full_color if filled else empty_color)


func _draw_heart(origin: Vector2, s: float, color: Color) -> void:
	var r := s * 0.27
	var left := origin + Vector2(s * 0.29, s * 0.32)
	var right := origin + Vector2(s * 0.71, s * 0.32)
	var tip := origin + Vector2(s * 0.5, s * 0.95)
	var poly := PackedVector2Array([
		origin + Vector2(s * 0.04, s * 0.42), origin + Vector2(s * 0.96, s * 0.42), tip,
	])
	# Outline (slightly larger shapes behind).
	draw_circle(left, r + 1.0, outline_color)
	draw_circle(right, r + 1.0, outline_color)
	draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(-1, 0), poly[1] + Vector2(1, 0), tip + Vector2(0, 1.5)]), outline_color)
	draw_circle(left, r, color)
	draw_circle(right, r, color)
	draw_colored_polygon(poly, color)
