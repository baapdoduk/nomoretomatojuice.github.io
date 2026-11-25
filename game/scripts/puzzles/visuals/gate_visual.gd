class_name GateVisual
extends Node2D
## Placeholder Gate visual (presentation only; default gate: the parent).
## Closed = solid block with bars; open = dashed outline frame; a pending close
## (anti-trap deferral) blinks the outline.

@export var gate: Gate
@export var size: Vector2 = Vector2(16, 48)
@export var color: Color = Color(0.7, 0.55, 0.4)

var _blink := 0.0


func _ready() -> void:
	if gate == null:
		gate = get_parent() as Gate
	if gate:
		gate.state_changed.connect(func(_o: bool) -> void: queue_redraw())
		gate.closing_deferred.connect(func(_b: Array[Node]) -> void: queue_redraw())


func _process(delta: float) -> void:
	if gate and gate.is_close_pending:
		_blink += delta
		queue_redraw()


func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	if gate == null or not gate.is_open:
		draw_rect(r, color, true)
		var bars := maxi(1, int(size.x / 6.0))
		for i in bars:
			var x := r.position.x + (i + 0.5) * size.x / bars
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), color.darkened(0.5), 1.0)
		return
	if gate.is_close_pending and fmod(_blink, 0.4) < 0.2:
		return
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var segs := 6
		for s in segs:
			if s % 2 == 0:
				draw_line(a.lerp(b, float(s) / segs), a.lerp(b, float(s + 1) / segs), color, 1.0)
