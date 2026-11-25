class_name TopDownMotor
extends PlayerMotor
## Top-down movement: 8-direction (diagonals normalized, analog magnitude kept),
## dash in the move direction (or facing when idle). Jump is disabled unless
## PlayerConfig.top_down_jump_enabled, in which case it is a cosmetic hop
## (get_hop_height() for visuals; collision unchanged).

const HOP_HEIGHT := 10.0

var _was_dashing: bool = false
var _hop_left: float = 0.0


func reset_state() -> void:
	super.reset_state()
	_was_dashing = false
	_hop_left = 0.0


func physics_update(input: PlayerInputState, delta: float) -> void:
	_tick_dash_timers(delta)
	var v := player.velocity
	var stunned := player.is_stunned()
	var move := Vector2.ZERO if stunned else input.move.limit_length(1.0)

	if is_dashing():
		v = _dash_direction * config.dash_speed
	else:
		if _was_dashing:
			v = _dash_direction * config.move_speed
		var target := move * config.move_speed
		var rate := config.top_down_accel if move != Vector2.ZERO else config.top_down_decel
		v = v.move_toward(target, rate * delta)
		if input.dash_pressed and _can_start_dash():
			var dir := move.normalized() if move != Vector2.ZERO else player.get_facing()
			if dir == Vector2.ZERO:
				dir = Vector2.DOWN
			_start_dash(dir)
			v = _dash_direction * config.dash_speed

	if _hop_left > 0.0:
		_hop_left = maxf(0.0, _hop_left - delta)
		if _hop_left == 0.0:
			player._on_motor_landed()
	elif input.jump_pressed and config.top_down_jump_enabled and not stunned:
		_hop_left = config.top_down_jump_duration
		player._on_motor_jumped()

	_was_dashing = is_dashing()
	player.velocity = v
	player.move_and_slide()


func is_airborne() -> bool:
	return _hop_left > 0.0

## Visual-only hop offset in pixels (0 when grounded).
func get_hop_height() -> float:
	if _hop_left <= 0.0 or config.top_down_jump_duration <= 0.0:
		return 0.0
	var t := 1.0 - _hop_left / config.top_down_jump_duration
	return sin(t * PI) * HOP_HEIGHT

func get_debug_info() -> Dictionary:
	var info := super.get_debug_info()
	info["hop"] = _hop_left
	return info
