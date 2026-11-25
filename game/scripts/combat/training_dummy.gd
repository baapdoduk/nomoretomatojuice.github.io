class_name TrainingDummy
extends StaticBody2D
## Target for testing player attacks. Body + Hurtbox on layer ENEMY with a local Health.
## Shows hits / total damage (Label "Stats", visual-only) and resets itself
## `reset_delay` seconds after the last hit, or right after its health runs out.
## Expected children: Health, Hurtbox (+ shape), Visual, Stats (Label), HitFeedback (all optional
## except Health / Hurtbox).

signal hit_registered(amount: int, total_damage: int, hit_count: int)
signal reset_done

## Seconds without hits before auto reset (0 = never, except on "death").
@export_range(0.0, 30.0, 0.1) var reset_delay: float = 2.0
## Seconds after health reaches 0 before reset.
@export_range(0.0, 10.0, 0.05) var death_reset_delay: float = 0.5

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var stats_label: Label = get_node_or_null(^"Stats") as Label

var total_damage: int = 0
var hit_count: int = 0
var last_hit_amount: int = 0
var _idle := 0.0
var _pending_reset := -1.0


func _ready() -> void:
	collision_layer = Layers.ENEMY
	collision_mask = 0
	hurtbox.collision_layer = Layers.ENEMY
	hurtbox.collision_mask = 0
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_update_label()


func _physics_process(delta: float) -> void:
	if _pending_reset >= 0.0:
		_pending_reset -= delta
		if _pending_reset <= 0.0001:
			reset_dummy()
		return
	if hit_count > 0 and reset_delay > 0.0:
		_idle += delta
		if _idle >= reset_delay - 0.0001:
			reset_dummy()


## Clears counters and refills health.
func reset_dummy() -> void:
	_pending_reset = -1.0
	_idle = 0.0
	total_damage = 0
	hit_count = 0
	last_hit_amount = 0
	health.reset()
	_update_label()
	reset_done.emit()


func _on_damaged(event: DamageEvent) -> void:
	_idle = 0.0
	hit_count += 1
	last_hit_amount = event.amount
	total_damage += event.amount
	_update_label()
	hit_registered.emit(event.amount, total_damage, hit_count)

func _on_died() -> void:
	_pending_reset = death_reset_delay

func _update_label() -> void:
	if stats_label:
		stats_label.text = "hits %d  dmg %d\nlast %d  hp %d/%d" % [hit_count, total_damage, last_hit_amount, health.current, health.max_health]
