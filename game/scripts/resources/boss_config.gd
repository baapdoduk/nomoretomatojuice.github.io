@tool
class_name BossConfig
extends Resource
## Tuning for a Boss: health, phases, vulnerability rules, defeat persistence.

## What a Boss does when its defeated_flag is already set when the scene loads.
enum AlreadyDefeated { START_DEFEATED, REMOVE }
## What a Boss does after being defeated during play.
enum DefeatBehavior { KEEP, HIDE, FREE }

@export var id: StringName = &"boss"
@export var display_name: String = "Boss"
@export_range(1, 9999) var max_health: int = 20
## Seconds of invulnerability after each accepted hit (0 = none).
@export_range(0.0, 5.0, 0.01) var hit_invulnerability_time: float = 0.0
## Ordered by descending health_threshold. At least one phase is required.
@export var phases: Array[BossPhase] = []

@export_group("Fight Flow")
## Start the fight automatically on _ready (otherwise call Boss.start_fight()).
@export var auto_start: bool = true
## Delay before the first IDLE after start_fight().
@export_range(0.0, 10.0, 0.05) var start_delay: float = 0.5
## Seed for RANDOM phase order (0 = randomize).
@export var random_seed: int = 0

@export_group("Vulnerability")
## RECOVERY is always damageable. These flags make the other states invulnerable.
@export var invulnerable_while_inactive: bool = true
@export var invulnerable_during_idle: bool = false
@export var invulnerable_during_telegraph: bool = true
@export var invulnerable_during_attack: bool = true

@export_group("Contact Damage")
## Damage when the player touches the boss body (0 = off).
@export_range(0, 99) var contact_damage: int = 0
@export var contact_knockback: float = 200.0
## Seconds between contact re-hits (the player's own i-frames also apply).
@export_range(0.1, 10.0, 0.05) var contact_interval: float = 1.0

@export_group("Defeat")
## GameState flag set on defeat, e.g. &"boss.test_boss.defeated". Empty = not persisted.
@export var defeated_flag: StringName = &""
@export var already_defeated: AlreadyDefeated = AlreadyDefeated.REMOVE
@export var defeat_behavior: DefeatBehavior = DefeatBehavior.KEEP
## Delay before HIDE / FREE after defeat (lets the defeat effect play).
@export_range(0.0, 10.0, 0.05) var defeat_remove_delay: float = 1.5


func get_phase(index: int) -> BossPhase:
	if index < 0 or index >= phases.size():
		return null
	return phases[index]

## Highest phase index whose threshold the given health ratio has reached.
func get_phase_index_for_ratio(ratio: float) -> int:
	var result := 0
	for i in phases.size():
		if phases[i] != null and ratio <= phases[i].health_threshold + 0.00001:
			result = i
	return result
