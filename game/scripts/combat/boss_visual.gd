class_name BossVisual
extends Node2D
## Placeholder boss drawing (presentation only; swap for sprites freely).
## Vulnerability is shown by SHAPE, not only colour:
##   guarded     -> closed hexagonal shield ring with outward spikes
##   vulnerable  -> ring broken into 4 short arcs pushed outward + pulsing exposed core (diamond)
##   telegraph   -> "!" warning mark above the boss
##   defeated    -> greyed body with an X over the core
## Polls the Boss (`boss`, defaults to owner) every frame.

enum Style { ORB, BOTTLE }

@export var style: Style = Style.ORB
@export var body_radius: float = 22.0
@export var body_color: Color = Color(0.55, 0.3, 0.7)
@export var shield_color: Color = Color(0.6, 0.85, 1.0)
@export var core_color: Color = Color(1.0, 0.9, 0.3)
## BOTTLE style: the trapped cat colour (placeholder).
@export var cat_color: Color = Color(1.0, 0.85, 0.2)
@export var boss: Boss

var _time := 0.0


func _ready() -> void:
	if boss == null:
		boss = owner as Boss
	if boss == null:
		boss = get_parent() as Boss


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var defeated := boss != null and boss.is_defeated()
	var vulnerable := boss != null and boss.is_vulnerable()
	var telegraph := boss != null and boss.state == Boss.State.TELEGRAPH
	var body := body_color if not defeated else Color(0.35, 0.35, 0.35)
	if style == Style.BOTTLE:
		_draw_bottle(body, defeated)
	else:
		draw_colored_polygon(AttackShape.circle(body_radius, 24), body)
	var r := body_radius + 8.0
	if defeated:
		var s := 6.0
		draw_line(Vector2(-s, -s), Vector2(s, s), Color.WHITE, 2.0)
		draw_line(Vector2(-s, s), Vector2(s, -s), Color.WHITE, 2.0)
		return
	if vulnerable:
		var push := 4.0 + 2.0 * sin(_time * 8.0)
		for i in 4:
			var a := TAU * float(i) / 4.0 + PI / 4.0
			draw_arc(Vector2.ZERO, r + push, a - 0.35, a + 0.35, 6, shield_color, 2.0)
		var core := 5.0 + 1.5 * sin(_time * 10.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -core), Vector2(core, 0), Vector2(0, core), Vector2(-core, 0)]), core_color)
	else:
		var hexagon := AttackShape.circle(r, 6)
		var closed := hexagon.duplicate()
		closed.append(hexagon[0])
		draw_polyline(closed, shield_color, 3.0)
		for p in hexagon:
			draw_line(p, p * 1.25, shield_color, 2.0)
	if telegraph:
		var top := Vector2(0, -r - 18.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-4, -10), top + Vector2(4, -10), top + Vector2(1.5, 2), top + Vector2(-1.5, 2)]), Color.WHITE)
		draw_circle(top + Vector2(0, 6), 2.0, Color.WHITE)


## Placeholder: the bottle is the boss, a yellow cat sits trapped inside.
func _draw_bottle(body: Color, defeated: bool) -> void:
	var w := body_radius * 0.9
	var h := body_radius * 1.4
	var glass := Color(body, 0.55)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, -h * 0.4), Vector2(-w * 0.45, -h * 0.75), Vector2(-w * 0.45, -h),
		Vector2(w * 0.45, -h), Vector2(w * 0.45, -h * 0.75), Vector2(w, -h * 0.4),
		Vector2(w, h), Vector2(-w, h)]), glass)
	draw_rect(Rect2(-w * 0.55, -h - 6.0, w * 1.1, 6.0), Color(0.9, 0.3, 0.3))  # cap
	var cat := cat_color if not defeated else Color(0.6, 0.6, 0.6)
	var head := Vector2(0, h * 0.25)
	draw_circle(head, w * 0.55, cat)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-w * 0.5, -w * 0.2), head + Vector2(-w * 0.35, -w * 0.8), head + Vector2(-w * 0.1, -w * 0.45)]), cat)
	draw_colored_polygon(PackedVector2Array([head + Vector2(w * 0.5, -w * 0.2), head + Vector2(w * 0.35, -w * 0.8), head + Vector2(w * 0.1, -w * 0.45)]), cat)
	draw_circle(head + Vector2(-w * 0.2, -w * 0.05), 1.5, Color.BLACK)
	draw_circle(head + Vector2(w * 0.2, -w * 0.05), 1.5, Color.BLACK)
	# nata-de-coco cubes floating around (placeholder)
	for i in 3:
		var p := Vector2(-w * 0.6 + w * 0.6 * float(i), -h * 0.3 + 3.0 * sin(_time * 2.0 + float(i)))
		draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(1, 1, 1, 0.8))
