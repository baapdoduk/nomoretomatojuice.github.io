extends Node2D
## Placeholder visual + progress UI for ContextActionInteractable (child "Visual").
## Shows the device, and while running a progress ring with the right
## ButtonGlyph (child "Glyph") or a stick arrow, plus a trigger-depth bar.

@export var size: Vector2 = Vector2(14, 18)
@export var color: Color = Color(0.75, 0.55, 0.95)
@export var done_color: Color = Color(0.4, 1.0, 0.5)
## Child ButtonGlyph used for the action prompt (auto-found "Glyph").
@export var glyph: ButtonGlyph

var _ctx: ContextActionInteractable
var _focused := false


func _ready() -> void:
	_ctx = get_parent() as ContextActionInteractable
	if glyph == null:
		glyph = get_node_or_null(^"Glyph") as ButtonGlyph
	if _ctx == null:
		return
	_ctx.focus_changed.connect(_on_focus)
	_ctx.started.connect(_refresh)
	_ctx.progress_changed.connect(_on_progress)
	_ctx.completed.connect(_refresh)
	_ctx.cancelled.connect(_refresh)
	_ctx.failed.connect(_refresh)
	_refresh()


func _on_focus(v: bool) -> void:
	_focused = v
	queue_redraw()

func _on_progress(_p: float) -> void:
	queue_redraw()


func _refresh() -> void:
	if glyph:
		glyph.action = _ctx.action
		glyph.visible = _ctx.is_running and _ctx.action_type != ContextActionInteractable.ActionType.STICK_DIRECTION
	queue_redraw()


func _process(_delta: float) -> void:
	if _ctx and _ctx.is_running:
		queue_redraw()


func _draw() -> void:
	if _ctx == null:
		return
	var col := done_color if _ctx.is_completed else color
	draw_rect(Rect2(-size * 0.5, size), col)
	if _focused:
		draw_rect(Rect2(-size * 0.5, size).grow(2.0), Color.WHITE, false, 1.0)
	if not _ctx.is_running:
		return
	var center := Vector2(0, -size.y * 0.5 - 18.0)
	draw_circle(center, 11.0, Color(0, 0, 0, 0.6))
	draw_arc(center, 10.0, -PI / 2.0, -PI / 2.0 + TAU * _ctx.progress, 24, done_color, 2.0)
	if _ctx.action_type == ContextActionInteractable.ActionType.STICK_DIRECTION:
		var d := _ctx.stick_direction.normalized() * 6.0
		draw_line(center - d, center + d, Color.WHITE, 2.0)
		draw_line(center + d, center + d - d.normalized().rotated(0.6) * 4.0, Color.WHITE, 2.0)
		draw_line(center + d, center + d - d.normalized().rotated(-0.6) * 4.0, Color.WHITE, 2.0)
	if _ctx.action_type == ContextActionInteractable.ActionType.TRIGGER_DEPTH:
		var bar := Rect2(center + Vector2(14, -8), Vector2(4, 16))
		draw_rect(bar, Color(0.2, 0.2, 0.2))
		var h := bar.size.y * _ctx.current_depth
		draw_rect(Rect2(bar.position.x, bar.end.y - h, bar.size.x, h), Color(1, 0.8, 0.3))
		if not _ctx.is_assisted():
			var ty := bar.end.y - bar.size.y * _ctx.trigger_threshold
			draw_line(Vector2(bar.position.x - 1, ty), Vector2(bar.end.x + 1, ty), Color.WHITE, 1.0)
