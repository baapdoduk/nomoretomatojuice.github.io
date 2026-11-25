class_name SideViewMotor
extends PlayerMotor
## Platformer movement: gravity, jump with coyote time + jump buffer, variable
## jump height (release to cut), horizontal dash (one air dash until landing),
## one-way platforms (down + jump drops through bodies in group
## "one_way_platform").

const ONE_WAY_GROUP := &"one_way_platform"

var _coyote_left: float = 0.0
var _buffer_left: float = 0.0
var _air_dashes_used: int = 0
var _jump_cut_pending: bool = false
var _was_on_floor: bool = false
var _was_dashing: bool = false
var _drop_left: float = 0.0
var _drop_body: PhysicsBody2D = null


func reset_state() -> void:
	super.reset_state()
	_coyote_left = 0.0
	_buffer_left = 0.0
	_air_dashes_used = 0
	_jump_cut_pending = false
	_was_on_floor = false
	_was_dashing = false
	_end_drop_through()


func physics_update(input: PlayerInputState, delta: float) -> void:
	_tick_dash_timers(delta)
	_tick_drop_through(delta)
	var v := player.velocity
	var on_floor := player.is_on_floor()
	var stunned := player.is_stunned()

	if on_floor:
		_coyote_left = config.coyote_time
		_air_dashes_used = 0
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
	_buffer_left = maxf(0.0, _buffer_left - delta)
	if input.jump_pressed and not stunned:
		_buffer_left = config.jump_buffer_time

	if is_dashing():
		v = Vector2(_dash_direction.x * config.dash_speed, 0.0)
	else:
		if _was_dashing:
			v.x = _dash_direction.x * config.move_speed
		# Horizontal control (none while stunned: knockback keeps its momentum).
		if not stunned:
			var target := input.move.x * config.move_speed
			var rate: float
			if absf(input.move.x) > 0.01:
				rate = config.ground_accel if on_floor else config.air_accel
			else:
				rate = config.ground_decel if on_floor else config.air_decel
			v.x = move_toward(v.x, target, rate * delta)
		# Jump / drop-through (buffered, coyote-aware).
		if _buffer_left > 0.0 and not stunned and (on_floor or _coyote_left > 0.0):
			var floor_body := _get_floor_body()
			if input.move.y > 0.5 and floor_body and floor_body.is_in_group(ONE_WAY_GROUP):
				_start_drop_through(floor_body)
			else:
				v.y = -config.jump_velocity
				_jump_cut_pending = true
				player._on_motor_jumped()
			_buffer_left = 0.0
			_coyote_left = 0.0
		# Variable jump height: releasing jump while rising cuts the ascent once.
		if _jump_cut_pending:
			if v.y >= 0.0:
				_jump_cut_pending = false
			elif not input.jump_held:
				v.y *= config.jump_cut_multiplier
				_jump_cut_pending = false
		# Gravity.
		var g := config.gravity * (config.fall_gravity_multiplier if v.y > 0.0 else 1.0)
		v.y = minf(v.y + g * delta, config.max_fall_speed)
		# Dash start.
		if input.dash_pressed and _can_start_dash() and (on_floor or _air_dashes_used < config.air_dash_count):
			var dir := signf(input.move.x)
			if dir == 0.0:
				dir = signf(player.get_facing().x)
			if dir == 0.0:
				dir = 1.0
			if not on_floor:
				_air_dashes_used += 1
			_jump_cut_pending = false
			_start_dash(Vector2(dir, 0.0))
			v = Vector2(dir * config.dash_speed, 0.0)

	_was_dashing = is_dashing()
	player.velocity = v
	player.move_and_slide()
	var now_on_floor := player.is_on_floor()
	if now_on_floor and not _was_on_floor:
		player._on_motor_landed()
	_was_on_floor = now_on_floor


func is_airborne() -> bool:
	return not player.is_on_floor()

func get_coyote_left() -> float:
	return _coyote_left

func get_buffer_left() -> float:
	return _buffer_left

func get_air_dashes_left() -> int:
	return maxi(0, config.air_dash_count - _air_dashes_used)

func get_debug_info() -> Dictionary:
	var info := super.get_debug_info()
	info["on_floor"] = player.is_on_floor()
	info["coyote"] = _coyote_left
	info["buffer"] = _buffer_left
	info["air_dashes_left"] = get_air_dashes_left()
	return info


# ------------------------------------------------------------------ one-way drop-through

func _get_floor_body() -> PhysicsBody2D:
	if not player.is_on_floor():
		return null
	for i in player.get_slide_collision_count():
		var c := player.get_slide_collision(i)
		if c.get_normal().dot(player.up_direction) > 0.7 and c.get_collider() is PhysicsBody2D:
			return c.get_collider()
	return null

func _start_drop_through(body: PhysicsBody2D) -> void:
	_end_drop_through()
	_drop_body = body
	_drop_left = config.drop_through_time
	player.add_collision_exception_with(body)
	player.position.y += 1.0

func _tick_drop_through(delta: float) -> void:
	if _drop_left <= 0.0:
		return
	_drop_left -= delta
	if _drop_left <= 0.0:
		_end_drop_through()

func _end_drop_through() -> void:
	if _drop_body and is_instance_valid(_drop_body) and player:
		player.remove_collision_exception_with(_drop_body)
	_drop_body = null
	_drop_left = 0.0
