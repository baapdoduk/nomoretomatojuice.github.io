class_name PlayerVisual
extends Node2D
## Placeholder player visual (procedural _draw): a rounded cat-like body with
## outline, ears, eyes looking toward the facing, and a tail on the trailing
## side. Juice: squash & stretch on jump / land, run bob, dust puffs (jump,
## land, skid, occasional run), dash after-images.
## Listens to Player signals only; replace this node with a Sprite2D /
## AnimatedSprite2D setup without touching gameplay code.

@export_group("Look")
@export var body_size: Vector2 = Vector2(14, 18)
@export var corner_radius: float = 5.0
@export var body_color: Color = Color(0.93, 0.62, 0.32)  # amber
@export var outline_color: Color = Color(0.22, 0.12, 0.16)  # dark plum
@export var outline_width: float = 1.0
@export var eye_color: Color = Color(0.98, 0.97, 0.9)
@export var pupil_color: Color = Color(0.12, 0.2, 0.22)
@export var dash_color: Color = Color(0.85, 0.95, 1.0)
@export var hurt_color: Color = Color(1.0, 0.35, 0.35)
@export var blink_interval: float = 0.08

@export_group("Squash & Stretch")
## Scale applied on take-off (x, y).
@export var jump_stretch: Vector2 = Vector2(0.78, 1.25)
## Scale applied on a full-speed landing (scaled down for soft landings).
@export var land_squash: Vector2 = Vector2(1.3, 0.72)
## Higher = faster return to (1, 1).
@export var squash_recover_speed: float = 14.0
## Run bob amplitude (px) and steps per second.
@export var run_bob_height: float = 1.2
@export var run_bob_rate: float = 9.0

@export_group("Effects")
@export var dust_enabled: bool = true
@export var dust_color: Color = Color(0.85, 0.78, 0.68, 0.85)
## Seconds between run puffs (0 disables).
@export var run_puff_interval: float = 0.35
@export var after_images_enabled: bool = true
## Seconds between dash after-images.
@export var after_image_interval: float = 0.03
@export var after_image_color: Color = Color(0.55, 0.85, 1.0, 0.5)
@export var after_image_lifetime: float = 0.2

var _player: Player
var _state: StringName = &"idle"
var _facing: Vector2 = Vector2.RIGHT
var _blinking: bool = false
var _blink_t: float = 0.0
var _slash_t: float = 0.0
var _slash_dir: Vector2 = Vector2.RIGHT
var _squash: Vector2 = Vector2.ONE
var _bob_t: float = 0.0
var _run_puff_t: float = 0.0
var _ghost_t: float = 0.0
var _air_vy: float = 0.0


func _ready() -> void:
	_player = owner as Player
	if _player == null:
		_player = get_parent() as Player
	if _player == null:
		return
	_player.state_changed.connect(_on_state_changed)
	_player.facing_changed.connect(_on_facing_changed)
	_player.attacked.connect(_on_attacked)
	_player.jumped.connect(_on_jumped)
	_player.landed.connect(_on_landed)
	_player.skidded.connect(_on_skidded)
	_player.dashed.connect(_on_dashed)
	_player.ready.connect(_connect_health, CONNECT_ONE_SHOT)


## Current squash/stretch scale (for tests / debug).
func get_squash() -> Vector2:
	return _squash


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


func _on_jumped() -> void:
	_squash = jump_stretch
	_puff(DustPuff.Kind.JUMP, 1.0)


func _on_landed() -> void:
	var max_fall := _player.config.max_fall_speed if _player.config else 320.0
	var strength := clampf(_air_vy / maxf(max_fall, 1.0), 0.25, 1.0)
	_squash = Vector2.ONE.lerp(land_squash, strength)
	_puff(DustPuff.Kind.LAND, strength)
	_air_vy = 0.0


func _on_skidded() -> void:
	_puff(DustPuff.Kind.SKID, 1.0)


func _on_dashed(_dir: Vector2) -> void:
	_ghost_t = 0.0


func _puff(kind: DustPuff.Kind, strength: float) -> void:
	if dust_enabled and _player:
		var dir := signf(_player.velocity.x) if _player.velocity.x != 0.0 else _facing.x
		DustPuff.spawn(self, _player.global_position, kind, dir, strength, dust_color)


func _physics_process(_delta: float) -> void:
	if _player and _player.velocity.y > 0.0:
		_air_vy = _player.velocity.y


func _process(delta: float) -> void:
	if _player == null:
		return
	if _blinking:
		_blink_t += delta
		visible = int(_blink_t / blink_interval) % 2 == 0
	if _slash_t > 0.0:
		_slash_t -= delta
	_squash = _squash.lerp(Vector2.ONE, 1.0 - exp(-squash_recover_speed * delta))
	var bob := 0.0
	if _state == &"run":
		_bob_t += delta * run_bob_rate
		bob = -absf(sin(_bob_t * PI)) * run_bob_height
		_run_puff_t += delta
		if run_puff_interval > 0.0 and _run_puff_t >= run_puff_interval \
				and _player.movement_mode == Player.MovementMode.SIDE_VIEW:
			_run_puff_t = 0.0
			_puff(DustPuff.Kind.RUN, 0.6)
	else:
		_bob_t = 0.0
		_run_puff_t = 0.0
	if _state == &"dash" and after_images_enabled:
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = after_image_interval
			AfterImage.spawn(self, global_position, body_size, after_image_color,
					after_image_lifetime, _facing.x < 0.0)
	var motor := _player.get_motor()
	var hop := (motor as TopDownMotor).get_hop_height() if motor is TopDownMotor else 0.0
	position.y = -hop + bob
	queue_redraw()


func _draw() -> void:
	var col := body_color
	match _state:
		&"dash":
			col = dash_color
		&"hurt", &"dead":
			col = hurt_color
	var sq := Vector2(1.2, 0.7) if _state == &"dead" else _squash
	var flip := -1.0 if _facing.x < 0.0 else 1.0
	# Scale around the feet; mirror for facing so details stay readable.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sq.x * flip, sq.y))
	var s := body_size
	var body := Rect2(Vector2(-s.x * 0.5, -s.y), s)
	# Tail (trailing side), ears, body.
	var tail := PackedVector2Array([Vector2(-s.x * 0.45, -s.y * 0.3), Vector2(-s.x * 0.85, -s.y * 0.55),
			Vector2(-s.x * 0.8, -s.y * 0.85)])
	draw_polyline(tail, outline_color, 3.0)
	draw_polyline(tail, col, 1.5)
	for ex: float in [-0.3, 0.25]:
		var ear := PackedVector2Array([Vector2(s.x * (ex - 0.15), -s.y + 2), Vector2(s.x * ex, -s.y - 4),
				Vector2(s.x * (ex + 0.15), -s.y + 2)])
		draw_colored_polygon(ear, col)
		draw_polyline(ear, outline_color, outline_width)
	var pts := rounded_rect_points(body, corner_radius)
	draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, outline_color, outline_width)
	# Eyes: looking toward facing (+x after mirroring); vertical look in top-down.
	var look := Vector2(1.0, _facing.y)
	for ex2: float in [0.0, 0.32]:
		var c := Vector2(s.x * ex2, -s.y * 0.68)
		draw_circle(c, 2.2, eye_color)
		draw_circle(c + look * 0.9, 1.1, pupil_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _slash_t > 0.0:
		var sc := Vector2(0, -s.y * 0.5)
		var a := _slash_dir.angle()
		draw_arc(sc, 18.0, a - 0.9, a + 0.9, 10, Color(1, 1, 1, 0.8), 2.0)


## Polygon points of a rounded rectangle (shared with AfterImage).
static func rounded_rect_points(rect: Rect2, radius: float, segments: int = 4) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5],
		[Vector2(rect.position.x + r, rect.position.y + r), PI],
	]
	for c: Array in corners:
		var center: Vector2 = c[0]
		var start: float = c[1]
		for i in segments + 1:
			var ang := start + PI * 0.5 * float(i) / float(segments)
			pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	return pts
