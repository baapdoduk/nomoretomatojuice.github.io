@tool
class_name InteractableVisual
extends Node2D
## Generic placeholder visual for interaction nodes (child named "Visual").
## Listens to whatever signals its parent offers (focus_changed, opened,
## activated_changed, active_changed, collected) and redraws; gameplay never
## reads it. Swap for real art by replacing this node.

enum Style { BOX, DOOR, ORB, FLAG, SIGN }

@export var style: Style = Style.BOX:
	set(v):
		style = v
		queue_redraw()
@export var size: Vector2 = Vector2(16, 16):
	set(v):
		size = v
		queue_redraw()
@export var color: Color = Color(0.8, 0.7, 0.4):
	set(v):
		color = v
		queue_redraw()
@export var active_color: Color = Color(0.4, 1.0, 0.5):
	set(v):
		active_color = v
		queue_redraw()
## Small caption drawn under the shape (editor + game).
@export var caption: String = "":
	set(v):
		caption = v
		queue_redraw()
## Draw an arrow toward this local direction (e.g. OneWayDoor open side).
@export var arrow: Vector2 = Vector2.ZERO:
	set(v):
		arrow = v
		queue_redraw()

var focused: bool = false
var active: bool = false
var _t: float = 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var p := get_parent()
	if p.has_signal(&"focus_changed"):
		p.focus_changed.connect(_on_focus)
	for sig: StringName in [&"opened", &"collected"]:
		if p.has_signal(sig):
			var n := _signal_arg_count(p, sig)
			p.connect(sig, _on_activated.unbind(n) if n > 0 else _on_activated)
	for sig: StringName in [&"activated_changed", &"active_changed"]:
		if p.has_signal(sig):
			p.connect(sig, _on_active)
	if p.has_method(&"is_active"):
		active = bool(p.call(&"is_active"))
	elif p.get(&"is_active_checkpoint") != null:
		active = bool(p.get(&"is_active_checkpoint"))


func _signal_arg_count(obj: Object, sig: StringName) -> int:
	for s in obj.get_signal_list():
		if s.name == sig:
			return (s.args as Array).size()
	return 0


func _on_focus(value: bool) -> void:
	focused = value
	queue_redraw()

func _on_activated() -> void:
	active = true
	queue_redraw()

func _on_active(value: bool) -> void:
	active = value
	queue_redraw()


func _process(delta: float) -> void:
	if focused or style == Style.ORB:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var col := active_color if active else color
	var r := Rect2(-size * 0.5, size)
	match style:
		Style.BOX:
			draw_rect(r, col)
		Style.DOOR:
			if active:
				draw_rect(r, col, false, 1.0)
			else:
				draw_rect(r, col)
				draw_circle(Vector2(size.x * 0.25, 0), 1.5, Color(0.1, 0.1, 0.1))
		Style.ORB:
			var bob := sin(_t * 3.0) * 2.0
			draw_circle(Vector2(0, bob), size.x * 0.5, col)
			draw_circle(Vector2(-size.x * 0.15, bob - size.y * 0.15), size.x * 0.15, Color(1, 1, 1, 0.7))
		Style.FLAG:
			draw_line(Vector2(0, size.y * 0.5), Vector2(0, -size.y * 0.5), Color(0.8, 0.8, 0.8), 2.0)
			var pts := PackedVector2Array([Vector2(1, -size.y * 0.5), Vector2(size.x, -size.y * 0.3), Vector2(1, -size.y * 0.1)])
			draw_colored_polygon(pts, col)
		Style.SIGN:
			draw_line(Vector2(0, size.y * 0.5), Vector2(0, 0), Color(0.5, 0.35, 0.2), 2.0)
			draw_rect(Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y * 0.6), col)
	if arrow != Vector2.ZERO and not active:
		var a := arrow.normalized() * (maxf(size.x, size.y) * 0.5 + 6.0)
		draw_line(Vector2.ZERO, a, Color.WHITE, 1.5)
		draw_line(a, a - arrow.normalized().rotated(0.5) * 4.0, Color.WHITE, 1.5)
		draw_line(a, a - arrow.normalized().rotated(-0.5) * 4.0, Color.WHITE, 1.5)
	if focused:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_rect(r.grow(2.0 + pulse), Color(1, 1, 1, 0.8), false, 1.0)
	if caption != "":
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_string(font, Vector2(-w * 0.5, size.y * 0.5 + 9.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.85))
