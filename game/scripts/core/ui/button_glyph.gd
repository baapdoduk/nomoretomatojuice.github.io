@tool
class_name ButtonGlyph
extends Control
## Draws the button for an input action without any font/texture dependency:
## DS4 face buttons as coloured symbols (triangle/circle/cross/square),
## other pad buttons / triggers as labelled pills, keyboard keys as key caps.
## Follows InputFeedback.last_input_kind automatically. Replace with textures
## later through joypad_textures / keyboard_texture (keyed by label, e.g. "Triangle").

@export var action: StringName = &"interact":
	set(value):
		action = value
		queue_redraw()
## Force &"joypad" or &"keyboard"; empty = follow the last used device.
@export var force_kind: StringName = &"":
	set(value):
		force_kind = value
		queue_redraw()
## Optional art overrides: { "Triangle": Texture2D, "Cross": Texture2D, ... }
@export var joypad_textures: Dictionary = {}
@export var keyboard_texture: Texture2D

const FACE_COLORS := {
	"Triangle": Color("#3ccf91"), "Circle": Color("#ff5a5f"),
	"Cross": Color("#6ea8ff"), "Square": Color("#ff8ad8"),
}


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(18, 18)
	if not Engine.is_editor_hint():
		InputFeedback.input_kind_changed.connect(func(_k: StringName) -> void: queue_redraw())


func get_glyph() -> Dictionary:
	if Engine.is_editor_hint():
		return {"kind": &"joypad", "label": "Triangle"}
	return InputFeedback.get_action_glyph(action, force_kind)


func _draw() -> void:
	var glyph := get_glyph()
	var label: String = glyph.get("label", "?")
	var r := Rect2(Vector2.ZERO, size)
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	if glyph.get("kind") == &"joypad":
		var tex: Texture2D = joypad_textures.get(label, null)
		if tex:
			draw_texture_rect(tex, r, false)
			return
		if FACE_COLORS.has(label):
			_draw_face_button(label, center, radius)
			return
		_draw_pill(r, label, Color(0.15, 0.15, 0.2), Color.WHITE)
		return
	if keyboard_texture:
		draw_texture_rect(keyboard_texture, r, false)
	_draw_pill(r, label, Color(0.92, 0.92, 0.95), Color(0.1, 0.1, 0.12))


func _draw_face_button(label: String, c: Vector2, radius: float) -> void:
	var col: Color = FACE_COLORS[label]
	draw_circle(c, radius, Color(0.12, 0.12, 0.16))
	draw_arc(c, radius - 0.5, 0.0, TAU, 24, col.darkened(0.3), 1.0, true)
	var s := radius * 0.5
	var w := maxf(1.5, radius * 0.16)
	match label:
		"Triangle":
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.95, s * 0.7), c + Vector2(-s * 0.95, s * 0.7), c + Vector2(0, -s)])
			draw_polyline(pts, col, w, true)
		"Circle":
			draw_arc(c, s * 0.85, 0.0, TAU, 20, col, w, true)
		"Cross":
			draw_line(c + Vector2(-s, -s) * 0.8, c + Vector2(s, s) * 0.8, col, w, true)
			draw_line(c + Vector2(s, -s) * 0.8, c + Vector2(-s, s) * 0.8, col, w, true)
		"Square":
			draw_rect(Rect2(c - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), col, false, w)


func _draw_pill(r: Rect2, text: String, bg: Color, fg: Color) -> void:
	var font := get_theme_default_font()
	var font_size := int(clampf(r.size.y * 0.55, 6.0, 32.0))
	var text_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var box := r
	if text_w + 6.0 > r.size.x:
		box.size.x = text_w + 6.0
		box.position.x = r.position.x + (r.size.x - box.size.x) * 0.5
	draw_rect(box, bg, true)
	draw_rect(box, fg.lerp(bg, 0.5), false, 1.0)
	var baseline := Vector2(box.position.x + (box.size.x - text_w) * 0.5, box.position.y + (box.size.y + font_size * 0.7) * 0.5)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
