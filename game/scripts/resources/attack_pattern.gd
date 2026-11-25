@tool
class_name AttackPattern
extends Resource
## Data for one enemy/boss attack: shape, placement, timing, damage and repeats.
##
## Executed by AttackRunner. The shape is built once by AttackShape and used for
## both the floor telegraph and the hit collision (identical by construction).
## Local shape space: the attack origin is (0, 0) and it is aimed along +X.
## Timeline per repeat: telegraph_time (warning, harmless) -> active_time (damage) -> removed.
## Repeat i starts at i * repeat_interval. After the last active window ends the
## attacker recovers for recovery_time. Telegraph and recovery are multiplied by
## GameState.get_combat_timing_scale() (assist option); active/repeat timings are not.

enum Shape { CIRCLE, CONE, LINE }
## SELF: attacker position. TARGET: target (player) position, or the attacker when absent.
enum Origin { SELF, TARGET }
## TOWARD_TARGET: from attacker to target (forward when absent). FIXED_ANGLE: fixed_angle_degrees.
## ROTATING: fixed_angle_degrees + aim_step_degrees * repeat_index.
enum Aim { TOWARD_TARGET, FIXED_ANGLE, ROTATING }
## How repeats 1..N-1 are placed. FOLLOW_TARGET: re-read the target's current position.
## LOCK_FIRST: reuse repeat 0's placement. STEP_LINE: advance repeat_step_distance along repeat 0's aim.
enum RepeatTargeting { FOLLOW_TARGET, LOCK_FIRST, STEP_LINE }

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Shape")
@export var shape: Shape = Shape.CIRCLE
## CIRCLE radius / CONE length (px).
@export_range(1.0, 2000.0, 1.0, "or_greater") var radius: float = 32.0
## Full opening angle of a CONE (degrees).
@export_range(1.0, 359.0, 1.0) var cone_angle_degrees: float = 60.0
## LINE length along the aim direction (px).
@export_range(1.0, 4000.0, 1.0, "or_greater") var line_length: float = 200.0
## LINE width (px).
@export_range(1.0, 1000.0, 1.0, "or_greater") var line_width: float = 24.0
## Polygon resolution for CIRCLE (full circle) and CONE (arc).
@export_range(6, 128, 1) var segments: int = 32

@export_group("Placement")
@export var origin: Origin = Origin.TARGET
## Added to the origin (px). Rotated by the aim angle when offset_follows_aim.
@export var origin_offset: Vector2 = Vector2.ZERO
@export var offset_follows_aim: bool = false
@export var aim: Aim = Aim.TOWARD_TARGET
@export_range(-360.0, 360.0, 0.5) var fixed_angle_degrees: float = 0.0
## Degrees added per repeat (Aim.ROTATING).
@export_range(-360.0, 360.0, 0.5) var aim_step_degrees: float = 0.0

@export_group("Timing")
## Warning duration (harmless). Spec: 1.5-2.0 s for bosses.
@export_range(0.0, 10.0, 0.05, "or_greater") var telegraph_time: float = 1.6
## Damage window duration (area attacks) / flash duration (projectile attacks).
@export_range(0.0, 10.0, 0.05, "or_greater") var active_time: float = 0.25
## Attacker recovery after the last active window. Spec: 3-4 s for bosses.
@export_range(0.0, 20.0, 0.05, "or_greater") var recovery_time: float = 3.5

@export_group("Damage")
@export_range(0, 99) var damage: int = 1
## Knockback speed (px/s) applied away from the attack centre / along projectile travel.
@export_range(0.0, 2000.0, 1.0) var knockback: float = 160.0
@export var tags: Array[StringName] = []

@export_group("Projectiles")
## 0 = area attack (the Shape group damages). > 0 = projectile attack: `projectile_count`
## projectiles are fired from the origin when it activates, and the telegraph shows one
## lane per projectile (speed x lifetime long, 2 x radius wide); the Shape group is unused.
@export_range(0.0, 4000.0, 1.0, "or_greater") var projectile_speed: float = 0.0
@export_range(1, 64) var projectile_count: int = 1
## Total fan angle (degrees) spread evenly around the aim direction.
@export_range(0.0, 360.0, 1.0) var projectile_spread_degrees: float = 0.0
@export_range(0.05, 30.0, 0.05) var projectile_lifetime: float = 2.0
@export_range(1.0, 200.0, 0.5) var projectile_radius: float = 6.0
## Optional custom projectile scene (root must be a Projectile). Null = built-in placeholder.
@export var projectile_scene: PackedScene

@export_group("Repeats")
@export_range(1, 64) var repeat_count: int = 1
## Seconds between repeat starts. Spec: 0.35 s.
@export_range(0.0, 10.0, 0.05) var repeat_interval: float = 0.35
@export var repeat_targeting: RepeatTargeting = RepeatTargeting.FOLLOW_TARGET
## STEP_LINE distance between consecutive repeats (px).
@export var repeat_step_distance: float = 48.0

@export_group("Telegraph Look")
@export var telegraph_color: Color = Color(1.0, 0.55, 0.1, 1.0)
@export var active_color: Color = Color(1.0, 0.15, 0.15, 1.0)
## Pulses per second of the telegraph outline (non-colour cue).
@export var pulse_speed: float = 3.0


func is_projectile_attack() -> bool:
	return projectile_speed > 0.0

## Seconds from pattern start until the last active window ends (unscaled timing scale = 1).
func get_attack_duration(timing_scale: float = 1.0) -> float:
	return float(repeat_count - 1) * repeat_interval + telegraph_time * timing_scale + active_time
