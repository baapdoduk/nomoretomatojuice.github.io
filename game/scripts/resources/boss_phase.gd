@tool
class_name BossPhase
extends Resource
## One boss phase: when it starts (health ratio) and which attacks it uses.
## Any number of phases is supported; they are listed in BossConfig.phases in
## descending threshold order (phase 0 normally has threshold 1.0).

enum Order { SEQUENTIAL, RANDOM }

@export var phase_name: String = ""
## The phase becomes active once health ratio <= this value (1.0 = from the start).
@export_range(0.0, 1.0, 0.01) var health_threshold: float = 1.0
@export var patterns: Array[AttackPattern] = []
@export var order: Order = Order.SEQUENTIAL
## RANDOM: avoid picking the same pattern twice in a row (when > 1 pattern).
@export var avoid_immediate_repeat: bool = true
## Seconds spent in IDLE before each attack.
@export_range(0.0, 10.0, 0.05) var idle_time: float = 1.0
## Cancel the running attack and return to IDLE when this phase starts.
@export var interrupt_current_attack: bool = false
## Optional recovery override (seconds) for every attack in this phase; < 0 = use the pattern's.
@export var recovery_time_override: float = -1.0
