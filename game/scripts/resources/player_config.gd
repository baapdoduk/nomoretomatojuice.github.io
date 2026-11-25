class_name PlayerConfig
extends Resource
## Tuning data for the Player (movement, dash, melee, hurt, death).
## The shared instance lives at res://resources/player/default_player_config.tres;
## duplicate it per level/character when a different feel is needed.
## Max health is owned by GameState (GameState.new_game / set_max_health).

@export_group("Movement")
## Max horizontal (side view) / planar (top down) walking speed, px/s.
## (Spec default 180; documented alternative 160 for tighter levels.)
@export var move_speed: float = 180.0
## Side view: ground acceleration toward the input direction, px/s^2.
@export var ground_accel: float = 900.0
## Side view: ground deceleration with no input, px/s^2.
@export var ground_decel: float = 1200.0
## Side view: ground deceleration while the input opposes the velocity (turning), px/s^2.
@export var ground_turn_decel: float = 2200.0
@export var air_accel: float = 1200.0
@export var air_decel: float = 900.0

@export_group("Side View")
## Rising gravity, px/s^2. Tuned with jump_velocity for apex ~4.75 tiles / airtime ~0.8 s.
@export var gravity: float = 900.0
## Extra gravity multiplier while falling (1.0 = symmetric arc).
@export var fall_gravity_multiplier: float = 1.4
@export var max_fall_speed: float = 320.0
## Initial upward velocity of a full jump. Apex height ~= v^2 / (2 * gravity)
## (the apex hang adds < 1 px).
@export var jump_velocity: float = 370.0
## Upward velocity is multiplied by this when jump is released early (variable height).
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.5
## Gravity multiplier near the apex (|vy| < apex_hang_speed) while jump is held.
@export_range(0.0, 1.0) var apex_hang_multiplier: float = 0.6
## Vertical speed below which the apex hang applies, px/s.
@export var apex_hang_speed: float = 40.0
## Max horizontal nudge (px) that lets a rising jump slip past a ceiling corner.
@export var corner_correction: float = 4.0
## Max height (px) of a lip the player walks up without jumping.
@export var step_up_height: float = 3.0
## Min |velocity.x| at which reversing on the ground emits Player.skidded.
@export var skid_min_speed: float = 100.0
## Seconds after leaving a ledge during which a jump is still accepted.
@export var coyote_time: float = 0.12
## Seconds a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.12
## Number of dashes allowed in the air before touching the floor again.
@export var air_dash_count: int = 1
## Seconds collision with a one-way platform is ignored after down + jump.
@export var drop_through_time: float = 0.25

@export_group("Top Down")
@export var top_down_accel: float = 2000.0
@export var top_down_decel: float = 2400.0
## Snap the move direction to 8 directions (45 degree steps), keeping the analog
## magnitude (clamped to 1). Diagonal speed equals cardinal speed either way.
@export var top_down_eight_way: bool = true
## Top-down jump is a cosmetic hop (no collision change). Disabled by default.
@export var top_down_jump_enabled: bool = false
@export var top_down_jump_duration: float = 0.35

@export_group("Dash")
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 0.7
@export var dash_speed: float = 420.0
## Invulnerability granted when a dash starts (0 = none).
@export var dash_iframe_time: float = 0.12

@export_group("Melee")
@export var attack_startup: float = 0.05
@export var attack_active: float = 0.10
@export var attack_recovery: float = 0.15
## Distance from the player centre to the hitbox centre.
@export var attack_range: float = 16.0
@export var attack_size: Vector2 = Vector2(22, 18)
@export var attack_damage: int = 1
@export var attack_knockback: float = 200.0

@export_group("Feel")
## Hit-stop length on confirmed melee hits (real seconds). Setting "hit_stop" toggles it.
@export var hit_stop_duration: float = 0.05
## Engine.time_scale during hit-stop.
@export_range(0.0, 1.0) var hit_stop_time_scale: float = 0.05
## Camera trauma added on confirmed melee hits (setting "screen_shake" toggles it).
@export_range(0.0, 1.0) var hit_trauma: float = 0.25
## Camera trauma added when the player takes damage.
@export_range(0.0, 1.0) var hurt_trauma: float = 0.4

@export_group("Hurt")
## Seconds of invulnerability after taking damage (Health.invulnerability_time).
@export var invulnerability_time: float = 1.0
## Seconds without control after a hit.
@export var hurt_stun_time: float = 0.2
## Knockback speed applied when the DamageEvent carries no knockback.
@export var hurt_knockback_speed: float = 200.0
## Side view: upward component added to hurt knockback.
@export var hurt_knockback_lift: float = 160.0

@export_group("Death")
@export var death_respawn_delay: float = 1.0


## Total melee duration (startup + active + recovery).
func get_attack_total_time() -> float:
	return attack_startup + attack_active + attack_recovery
