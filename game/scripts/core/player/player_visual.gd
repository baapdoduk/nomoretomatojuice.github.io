extends Node2D
## Placeholder player visual (procedural _draw). Listens to Player signals only;
## replace this node with a Sprite2D / AnimatedSprite2D setup without touching
## gameplay code.

@export var body_size: Vector2 = Vector2(12, 20)
@export var body_color: Color = Color(0.35, 0.75, 1.0)
@export var dash_color: Color = Color(0.85, 0.95, 1.0)
@export var hurt_color: Color = Color(1.0, 0.35, 0.35)
@export var blink_interval: float = 0.08

var _player: Player
var _state: StringName = &"idle"
var _facing: Vector2 = Vector2.RIGHT
var _blinking: bool = false
var _blink_t: float = 0.0
var _slash_t: float = 0.0
var _slash_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_player = owner as Player
	if _player == null:
		_player = get_parent() as Player
	if _player == null:
		return
	_player.state_changed.connect(_on_state_changed)
	_player.facing_changed.connect(_on_facing_changed)
	_player.attacked.connect(_on_attacked)
	_player.ready.connect(_connect_health, CONNECT_ONE_SHOT)


func _on_state_changed(s: StringName) -> void:
	_state = s
	queue_redraw()


func _on_facing_changed(f: Vector2) -> void:
	_facing = f
	queue_redraw()


func _connect_health() -> void:
	_facing = _player.get_facing()
	_player.health.invulnerability_changed.connect(_on_invulnerability_changed)


func _on_invulnerability_changed(on: bool) -> void:
	# Dash i-frames don't blink; post-hit invulnerability does.
	_blinking = on and not _player.is_dashing()
	_blink_t = 0.0
	if not _blinking:
		visible = true


func _on_attacked(dir: Vector2) -> void:
	_slash_dir = dir
	_slash_t = _player.config.get_attack_total_time() if _player.config else 0.25
	queue_redraw()


func _process(delta: float) -> void:
	if _blinking:
		_blink_t += delta
		visible = int(_blink_t / blink_interval) % 2 == 0
	if _slash_t > 0.0:
		_slash_t -= delta
		queue_redraw()
	var motor := _player.get_motor() if _player else null
	position.y = -(motor as TopDownMotor).get_hop_height() if motor is TopDownMotor else 0.0


func _draw() -> void:
	var col := body_color
	match _state:
		&"dash":
			col = dash_color
		&"hurt", &"dead":
			col = hurt_color
		&"jump":
			col = body_color.lightened(0.15)
		&"fall":
			col = body_color.darkened(0.15)
	var squash := Vector2(1.15, 0.85) if _state == &"dead" else Vector2.ONE
	var size := body_size * squash
	draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y), size), col)
	# Facing "eye".
	var eye := Vector2(_facing.x * size.x * 0.25, -size.y * 0.7 + _facing.y * 3.0)
	draw_circle(eye, 1.8, Color.WHITE)
	if _slash_t > 0.0:
		var c := Vector2(0, -size.y * 0.5)
		var a := _slash_dir.angle()
		draw_arc(c, 18.0, a - 0.9, a + 0.9, 10, Color(1, 1, 1, 0.8), 2.0)
