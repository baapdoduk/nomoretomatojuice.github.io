class_name PlatformerCamera
extends Camera2D
## Side-view camera rig (PLATFORMER_DESIGN.md A). A `top_level` Camera2D whose
## centre is computed every physics frame (never a jittery child):
##  - Horizontal: centre = target.x + lead. The lead follows the target's
##    *velocity* (not facing), clamped to move speed (a dash cannot yank it),
##    pans at most `lead_pan_speed` and holds inside a small speed dead zone
##    (turning on the spot does not swing the view).
##  - Vertical platform snap: while grounded the feet ease to the rest line
##    (`rest_line` of the screen height) over ~`ground_ease_time`; while
##    airborne the camera holds unless the head rises above `top_window` or the
##    feet drop below the rest line + `bottom_margin` (followed rigidly, i.e.
##    catch-up == fall speed).
##  - Bounds: rect of the first node in group "camera_bounds"; rooms smaller
##    than the view are centred. Zoom from the first node in group
##    "level_info" exposing `camera_zoom` (duck typed), else `default_zoom`.
##  - Hard snap via snap_to_target() (spawn / respawn / door) and automatically
##    when the target moves more than `teleport_distance` in one frame.
##  - Trauma shake: add_trauma(amount) -> offset = max_shake * trauma^2, decays
##    linearly; ignored while GameState setting "screen_shake" is false.
## All positions/sizes are world pixels.

const CAMERA_BOUNDS_GROUP := &"camera_bounds"
const LEVEL_INFO_GROUP := &"level_info"
const SHAKE_SETTING := &"screen_shake"

## Followed node (Player sets itself). Falls back to the parent Node2D.
@export var target: Node2D

@export_group("Framing")
## Zoom used when no LevelInfo overrides it (1.5 -> 427x240 px of the 640x360 view).
@export var default_zoom: float = 1.5
## Non-zero: view size in screen pixels instead of the viewport's (tests / tools).
@export var view_size_override: Vector2 = Vector2.ZERO

@export_group("Horizontal Lead")
## Lead distance at full move speed, px.
@export var lead_distance: float = 44.0
## Max change of the lead per second, px/s.
@export var lead_pan_speed: float = 80.0
## |velocity.x| below this keeps the current lead (dead zone), px/s.
@export var lead_dead_zone_speed: float = 30.0
## Fallback move speed when the target has no `config.move_speed`.
@export var fallback_move_speed: float = 180.0
## On a hard snap, start with the lead pointing toward the target's facing.
@export var snap_lead_from_facing: bool = true

@export_group("Vertical")
## Feet rest line as a fraction of the view height from the top.
@export_range(0.0, 1.0) var rest_line: float = 0.70
## Airborne: the camera moves up once the head is above this fraction from the top.
@export_range(0.0, 1.0) var top_window: float = 0.22
## Airborne: the camera follows down once the feet are this far below the rest line, px.
@export var bottom_margin: float = 16.0
## Grounded ease to the new floor height: ~95 % settled after this many seconds.
@export var ground_ease_time: float = 0.3
## Head height above the target origin (feet), px.
@export var head_height: float = 20.0

@export_group("Snap & Shake")
## A one-frame target jump larger than this triggers a hard snap, px.
@export var teleport_distance: float = 160.0
## Max shake offset at trauma 1, px (world).
@export var max_shake_offset: Vector2 = Vector2(6.0, 4.0)
## Max shake roll at trauma 1, radians (0 = none).
@export var max_shake_roll: float = 0.0
## Trauma lost per second.
@export var trauma_decay: float = 1.6

## Current horizontal lead, px.
var lead: float = 0.0
## Current trauma (0..1).
var trauma: float = 0.0

var _center: Vector2 = Vector2.ZERO  # unclamped rig centre
var _bounds: Rect2 = Rect2()
var _has_bounds: bool = false
var _snapped: bool = false
var _last_target_pos: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true
	position_smoothing_enabled = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	process_physics_priority = 100  # after the player moved this frame
	if target == null:
		target = get_parent() as Node2D
	refresh_level_settings()


## Re-reads CameraBounds and LevelInfo zoom (call after a level loads).
func refresh_level_settings() -> void:
	var z := default_zoom
	_has_bounds = false
	if is_inside_tree():
		var info := get_tree().get_first_node_in_group(LEVEL_INFO_GROUP)
		if info:
			var v: Variant = info.get(&"camera_zoom")
			if v is float or v is int:
				if float(v) > 0.0:
					z = float(v)
			elif v is Vector2 and (v as Vector2).x > 0.0:
				z = (v as Vector2).x
		var b := get_tree().get_first_node_in_group(CAMERA_BOUNDS_GROUP)
		if b and b.has_method(&"get_global_rect"):
			_bounds = b.call(&"get_global_rect")
			_has_bounds = true
	zoom = Vector2(z, z)
	# Own clamping/centring replaces Camera2D limits.
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000


## Visible world size at the current zoom.
func get_view_size() -> Vector2:
	var screen := view_size_override
	if screen == Vector2.ZERO:
		screen = get_viewport_rect().size if is_inside_tree() else Vector2(640, 360)
	return screen / zoom


## Instantly frames the target (no swoop): lead reset, vertical on the rest line.
func snap_to_target() -> void:
	if target == null:
		return
	var feet := target.global_position
	lead = 0.0
	if snap_lead_from_facing and target.has_method(&"get_facing"):
		var f: Vector2 = target.call(&"get_facing")
		lead = signf(f.x) * lead_distance
	_center = Vector2(feet.x + lead, feet.y - _rest_offset())
	_last_target_pos = feet
	_snapped = true
	_apply_position()
	reset_smoothing()
	force_update_scroll()


## Adds screen-shake trauma (clamped to 1). Ignored when the setting is off.
func add_trauma(amount: float) -> void:
	if not is_shake_enabled():
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)


func is_shake_enabled() -> bool:
	return bool(GameState.get_setting(SHAKE_SETTING, true))


## Rig centre after bounds (what the camera shows, without shake).
func get_rig_center() -> Vector2:
	return global_position


func _physics_process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var feet := target.global_position
	if not _snapped or feet.distance_to(_last_target_pos) > teleport_distance:
		snap_to_target()
	else:
		_update_lead(delta)
		_update_vertical(feet, delta)
		_center.x = feet.x + lead
		_last_target_pos = feet
		_apply_position()
	_update_shake(delta)


func _update_lead(delta: float) -> void:
	var vx := _target_velocity().x
	if absf(vx) < lead_dead_zone_speed:
		return
	var speed := _target_move_speed()
	var desired := clampf(vx / maxf(speed, 1.0), -1.0, 1.0) * lead_distance
	lead = move_toward(lead, desired, lead_pan_speed * delta)


func _update_vertical(feet: Vector2, delta: float) -> void:
	var h := get_view_size().y
	if _target_grounded():
		var desired := feet.y - _rest_offset()
		var k := 1.0 - exp(-delta * 3.0 / maxf(ground_ease_time, 0.001))
		_center.y = lerpf(_center.y, desired, k)
		if absf(_center.y - desired) < 0.05:
			_center.y = desired
	# Window limits (always; airborne this is the only vertical motion).
	var top := _center.y - h * 0.5
	var head_limit := top + top_window * h
	var head := feet.y - head_height
	if head < head_limit:
		_center.y -= head_limit - head
	var feet_limit := _center.y - h * 0.5 + rest_line * h + bottom_margin
	if feet.y > feet_limit:
		_center.y += feet.y - feet_limit


func _update_shake(delta: float) -> void:
	if trauma > 0.0 and not is_shake_enabled():
		trauma = 0.0
	if trauma <= 0.0:
		offset = Vector2.ZERO
		rotation = 0.0
		return
	var s := trauma * trauma
	offset = Vector2(max_shake_offset.x * s * _rng.randf_range(-1.0, 1.0),
			max_shake_offset.y * s * _rng.randf_range(-1.0, 1.0))
	rotation = max_shake_roll * s * _rng.randf_range(-1.0, 1.0)
	trauma = maxf(0.0, trauma - trauma_decay * delta)


## Clamps the rig centre to the bounds (centring small rooms) and applies it.
func _apply_position() -> void:
	var c := _center
	if _has_bounds:
		var view := get_view_size()
		c.x = _clamp_axis(c.x, _bounds.position.x, _bounds.end.x, view.x)
		c.y = _clamp_axis(c.y, _bounds.position.y, _bounds.end.y, view.y)
	global_position = c


static func _clamp_axis(value: float, lo: float, hi: float, view: float) -> float:
	if hi - lo <= view:
		return (lo + hi) * 0.5
	return clampf(value, lo + view * 0.5, hi - view * 0.5)


## Distance from the view centre down to the feet rest line.
func _rest_offset() -> float:
	return (rest_line - 0.5) * get_view_size().y


func _target_velocity() -> Vector2:
	if target is CharacterBody2D:
		return (target as CharacterBody2D).velocity
	return Vector2.ZERO


func _target_grounded() -> bool:
	if target is CharacterBody2D:
		return (target as CharacterBody2D).is_on_floor()
	return true


func _target_move_speed() -> float:
	var cfg: Variant = target.get(&"config")
	if cfg is Object:
		var ms: Variant = (cfg as Object).get(&"move_speed")
		if ms is float and ms > 0.0:
			return ms
	return fallback_move_speed
