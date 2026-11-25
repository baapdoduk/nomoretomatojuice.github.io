class_name BossHealthBar
extends Control
## Self-contained boss health bar (lives in a CanvasLayer inside the boss scene).
## Shows name, health fill, phase threshold ticks and a text/shape guard state
## ("GUARD" with a closed box vs "OPEN" with a broken box) - not colour-only.
## Hidden until the fight starts and after defeat.

@export var boss: Boss
@export var fill_color: Color = Color(0.85, 0.2, 0.25)
@export var back_color: Color = Color(0, 0, 0, 0.6)
@export var bar_height: float = 8.0
@export var hide_on_defeat: bool = true

## Ratio currently displayed (0..1).
var displayed_ratio: float = 1.0
var _name_label: Label


func _ready() -> void:
	if boss == null:
		boss = owner as Boss
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = get_node_or_null(^"Name") as Label
	visible = false
	if boss:
		boss.fight_started.connect(_on_fight_started)
		boss.state_changed.connect(_on_state_changed)
		boss.phase_changed.connect(func(_i: int) -> void: queue_redraw())
		boss.ready.connect(_on_boss_ready, CONNECT_ONE_SHOT)


func _on_boss_ready() -> void:
	if boss.health:
		boss.health.health_changed.connect(_on_health_changed)
		displayed_ratio = boss.health.get_ratio()
	if _name_label and boss.config:
		_name_label.text = boss.config.display_name
	visible = boss.is_fight_active()

func _on_fight_started() -> void:
	visible = true
	queue_redraw()

func _on_state_changed(state: Boss.State) -> void:
	if state == Boss.State.DEFEATED and hide_on_defeat:
		visible = false
	queue_redraw()

func _on_health_changed(current: int, max_value: int) -> void:
	displayed_ratio = clampf(float(current) / float(maxi(1, max_value)), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2(0, size.y - bar_height), Vector2(size.x, bar_height))
	draw_rect(rect, back_color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * displayed_ratio, rect.size.y)), fill_color)
	draw_rect(rect, Color.WHITE, false, 1.0)
	if boss and boss.config:
		for i in range(1, boss.config.phases.size()):
			var x := rect.size.x * boss.config.phases[i].health_threshold
			draw_line(Vector2(x, rect.position.y - 2), Vector2(x, rect.end.y + 2), Color.WHITE, 1.0)
	var font := get_theme_default_font()
	var open := boss != null and boss.is_vulnerable()
	var label := "OPEN" if open else "GUARD"
	var box := Rect2(Vector2(size.x - 52, rect.position.y - 16), Vector2(10, 10))
	if open:
		draw_line(box.position, box.position + Vector2(4, 0), Color.WHITE, 1.0)
		draw_line(box.end, box.end - Vector2(4, 0), Color.WHITE, 1.0)
	else:
		draw_rect(box, Color.WHITE, false, 1.0)
	draw_string(font, Vector2(size.x - 38, rect.position.y - 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()
