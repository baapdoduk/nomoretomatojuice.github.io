class_name PuzzleConfig
extends Resource
## Tuning data for module C (puzzles & light). One shared instance lives at
## res://resources/puzzles/default_puzzle_config.tres; components fall back to
## script defaults (PuzzleConfig.resolve(null)) when no config is assigned.

@export_group("Light")
## Maximum number of mirror reflections per beam (the beam stops after this).
@export_range(0, 64) var max_bounces: int = 12
## Total beam length cap in pixels (sum of all segments).
@export var max_distance: float = 4000.0
## Offset (px) along the hit normal applied at every reflection point so the
## next segment never starts inside / re-hits the mirror it just left.
@export var epsilon: float = 0.5
## Physics layers a beam can hit (default: World).
@export_flags_2d_physics var light_collision_mask: int = 1
@export var beam_width: float = 2.0
@export var beam_color: Color = Color(1.0, 0.95, 0.55)

@export_group("Mirror")
## Default rotation per interaction (degrees). Mirrors may override (e.g. 45).
@export var mirror_step_degrees: float = 90.0

@export_group("Hints")
## Seconds a puzzle must stay unsolved with the player nearby before its hint shows.
@export var hint_delay: float = 60.0
## Player distance (px) from the PuzzleController that counts as "nearby" (<= 0: anywhere).
@export var hint_radius: float = 192.0
@export var hint_duration: float = 4.0

@export_group("Push box")
## Distance of one push (px).
@export var push_grid_size: float = 16.0
## Seconds a push takes.
@export var push_time: float = 0.15

static var _fallback: PuzzleConfig


## Returns `config` or a shared default instance (never null).
static func resolve(config: PuzzleConfig) -> PuzzleConfig:
	if config:
		return config
	if _fallback == null:
		_fallback = PuzzleConfig.new()
	return _fallback
