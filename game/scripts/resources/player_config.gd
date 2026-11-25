class_name PlayerConfig
extends Resource
## Tuning data for the Player (movement, dash, melee, hurt, death).
## The shared instance lives at res://resources/player/default_player_config.tres;
## duplicate it per level/character when a different feel is needed.
## Max health is owned by GameState (GameState.new_game / set_max_health).

@export_group("Movement")
## Max horizontal (side view) / planar (top down) walking speed, px/s.
@export var move_speed: float = 180.0
@export var ground_accel: float = 1800.0
@export var ground_decel: float = 2200.0
@export var air_accel: float = 1200.0
@export var air_decel: float = 900.0

@export_group("Side View")
@export var gravity: float = 1200.0
## Extra gravity multiplier while falling (1.0 = symmetric arc).
@export var fall_gravity_multiplier: float = 1.0
@export var max_fall_speed: float = 600.0
## Initial upward velocity of a full jump. Apex height = v^2 / (2 * gravity).
@export var jump_velocity: float = 420.0
## Upward velocity is multiplied by this when jump is released early (variable height).
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.4
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
