class_name HitStop
extends RefCounted
## Global hit-stop ("freeze frame") via Engine.time_scale. Restored by a
## real-time SceneTreeTimer (ignores time scale and pause), so a freed caller
## can never leave the game slowed down. Overlapping calls extend the stop.
## Respects GameState setting `hit_stop` (default true); tests that need exact
## timing set it to false.

const SETTING := &"hit_stop"

static var _generation: int = 0
static var _active: bool = false


## True when the `hit_stop` setting allows freezes.
static func is_enabled() -> bool:
	return bool(GameState.get_setting(SETTING, true))


## Freezes the game to `time_scale` for `duration` real seconds. Returns false
## when disabled by the setting (or duration <= 0).
static func trigger(tree: SceneTree, duration: float, time_scale: float = 0.05) -> bool:
	if tree == null or duration <= 0.0 or not is_enabled():
		return false
	_generation += 1
	var gen := _generation
	_active = true
	Engine.time_scale = clampf(time_scale, 0.0, 1.0)
	var timer := tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func() -> void:
		if gen == _generation:
			stop())
	return true


## Ends any running hit-stop immediately.
static func stop() -> void:
	if _active:
		Engine.time_scale = 1.0
	_active = false


static func is_active() -> bool:
	return _active
