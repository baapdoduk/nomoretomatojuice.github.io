class_name Boss
extends CharacterBody2D
## Data-driven boss: INACTIVE -> (IDLE -> TELEGRAPH -> ATTACK -> RECOVERY) loop, DEFEATED.
##
## - IDLE: waits the current phase's idle_time, then picks the next AttackPattern.
## - TELEGRAPH: the AttackRunner shows the warning (harmless) - entered when an attack starts.
## - ATTACK: from the first active window until every active window has ended.
## - RECOVERY: pattern recovery_time (scaled by assist timing) - ALWAYS damageable.
## Invulnerability per state comes from BossConfig.invulnerable_* (Health named flags).
## Phases switch when the health ratio drops to a BossPhase.health_threshold (any count).
## On defeat: attacks cancelled, GameState defeated_flag set, `defeated` emitted.
## Required children: Health, Hurtbox, AttackRunner. Optional: ContactHitbox (Hitbox).
## Presentation (Visual, HealthBar, HitFeedback) only listens to the signals below.

signal state_changed(state: State)
signal phase_changed(index: int)
signal attack_started(pattern: AttackPattern)
signal fight_started
signal defeated

enum State { INACTIVE, IDLE, TELEGRAPH, ATTACK, RECOVERY, DEFEATED }

const FLAG_INACTIVE := &"boss_inactive"
const FLAG_IDLE := &"boss_idle"
const FLAG_TELEGRAPH := &"boss_telegraph"
const FLAG_ATTACK := &"boss_attack"

@export var config: BossConfig
## Per-instance override: ignore config.auto_start and wait for start_fight()
## (e.g. from a BossFightTrigger in the arena).
@export var wait_for_trigger: bool = false

var state: State = State.INACTIVE
var phase_index: int = -1
var current_pattern: AttackPattern
## Seconds spent in the current state.
var state_time: float = 0.0
## True when the boss was created already defeated (flag set on load).
var was_defeated_on_load: bool = false

var health: Health
var hurtbox: Hurtbox
var runner: AttackRunner
var contact_hitbox: Hitbox

var _fight_requested := false
var _start_left := 0.0
var _idle_left := 0.0
var _contact_left := 0.0
var _remove_left := -1.0
var _cursor := 0
var _last_pick := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(Layers.GROUP_BOSS)
	health = $Health
	hurtbox = $Hurtbox
	runner = $AttackRunner
	contact_hitbox = get_node_or_null(^"ContactHitbox") as Hitbox
	if config == null or config.phases.is_empty():
		push_warning("Boss %s: missing BossConfig / phases" % name)
		set_physics_process(false)
		return
	health.max_health = config.max_health
	health.invulnerability_time = config.hit_invulnerability_time
	health.reset()
	health.health_changed.connect(_on_health_changed)
	health.died.connect(_on_died)
	runner.source = self
	runner.active_started.connect(_on_runner_active)
	runner.attacks_resolved.connect(_on_runner_resolved)
	runner.pattern_finished.connect(_on_runner_finished)
	if config.random_seed != 0:
		_rng.seed = config.random_seed
	else:
		_rng.randomize()
	if contact_hitbox:
		contact_hitbox.source = self
		contact_hitbox.damage = config.contact_damage
		contact_hitbox.knockback_strength = config.contact_knockback
		contact_hitbox.deactivate()
	if config.defeated_flag != &"" and GameState.has_flag(config.defeated_flag):
		_apply_already_defeated()
		return
	_set_phase(0)
	_enter(State.INACTIVE)
	if config.auto_start and not wait_for_trigger:
		start_fight()


## Starts the fight (after config.start_delay). No-op unless INACTIVE.
func start_fight() -> void:
	if state != State.INACTIVE or _fight_requested or config == null:
		return
	_fight_requested = true
	_start_left = config.start_delay
	fight_started.emit()
	if _start_left <= 0.0:
		_enter_idle()


func get_phase() -> BossPhase:
	return config.get_phase(phase_index) if config else null

func is_vulnerable() -> bool:
	return state != State.DEFEATED and health != null and not health.is_invulnerable()

func is_defeated() -> bool:
	return state == State.DEFEATED

func is_fight_active() -> bool:
	return _fight_requested and state != State.DEFEATED

static func state_name(s: State) -> String:
	return State.keys()[s]


func _physics_process(delta: float) -> void:
	state_time += delta
	match state:
		State.INACTIVE:
			if _fight_requested:
				_start_left -= delta
				if _start_left <= 0.0001:
					_enter_idle()
		State.IDLE:
			_idle_left -= delta
			if _idle_left <= 0.0001:
				_start_next_attack()
		State.DEFEATED:
			if _remove_left >= 0.0:
				_remove_left -= delta
				if _remove_left <= 0.0001:
					_remove_left = -1.0
					_apply_defeat_behavior()
			return
	_update_contact(delta)


func _enter(s: State) -> void:
	state = s
	state_time = 0.0
	_apply_vulnerability()
	state_changed.emit(s)

func _enter_idle() -> void:
	var phase := get_phase()
	_idle_left = phase.idle_time if phase else 1.0
	_enter(State.IDLE)

func _apply_vulnerability() -> void:
	health.set_invulnerable_flag(FLAG_INACTIVE, state == State.INACTIVE and config.invulnerable_while_inactive)
	health.set_invulnerable_flag(FLAG_IDLE, state == State.IDLE and config.invulnerable_during_idle)
	health.set_invulnerable_flag(FLAG_TELEGRAPH, state == State.TELEGRAPH and config.invulnerable_during_telegraph)
	health.set_invulnerable_flag(FLAG_ATTACK, state == State.ATTACK and config.invulnerable_during_attack)

func _start_next_attack() -> void:
	var pattern := _pick_pattern()
	if pattern == null:
		_enter_idle()
		return
	current_pattern = pattern
	_enter(State.TELEGRAPH)
	attack_started.emit(pattern)
	var phase := get_phase()
	runner.run(pattern, phase.recovery_time_override if phase else -1.0)

func _pick_pattern() -> AttackPattern:
	var phase := get_phase()
	if phase == null or phase.patterns.is_empty():
		return null
	var n := phase.patterns.size()
	var index := 0
	if phase.order == BossPhase.Order.RANDOM:
		index = _rng.randi_range(0, n - 1)
		if phase.avoid_immediate_repeat and n > 1 and index == _last_pick:
			index = (index + 1 + _rng.randi_range(0, n - 2)) % n
	else:
		index = _cursor % n
		_cursor += 1
	_last_pick = index
	return phase.patterns[index]

func _set_phase(index: int) -> void:
	if index == phase_index:
		return
	phase_index = index
	_cursor = 0
	_last_pick = -1
	phase_changed.emit(index)
	var phase := get_phase()
	if phase and phase.interrupt_current_attack and state in [State.TELEGRAPH, State.ATTACK, State.RECOVERY]:
		runner.cancel()
		_enter_idle()


func _on_runner_active(_pattern: AttackPattern, _repeat: int) -> void:
	if state == State.TELEGRAPH:
		_enter(State.ATTACK)

func _on_runner_resolved(_pattern: AttackPattern) -> void:
	if state in [State.TELEGRAPH, State.ATTACK]:
		_enter(State.RECOVERY)

func _on_runner_finished(_pattern: AttackPattern) -> void:
	if state == State.RECOVERY:
		current_pattern = null
		_enter_idle()

func _on_health_changed(_current: int, _max: int) -> void:
	if state == State.DEFEATED or health.is_dead:
		return
	var index := config.get_phase_index_for_ratio(health.get_ratio())
	if index > phase_index:
		_set_phase(index)

func _on_died() -> void:
	if state == State.DEFEATED:
		return
	runner.cancel()
	current_pattern = null
	_disable_combat()
	_enter(State.DEFEATED)
	if config.defeated_flag != &"":
		GameState.set_flag(config.defeated_flag, true)
	defeated.emit()
	if config.defeat_behavior != BossConfig.DefeatBehavior.KEEP:
		_remove_left = config.defeat_remove_delay
		if _remove_left <= 0.0:
			_remove_left = -1.0
			_apply_defeat_behavior()

func _apply_already_defeated() -> void:
	was_defeated_on_load = true
	runner.cancel()
	_disable_combat()
	_enter(State.DEFEATED)
	phase_index = maxi(0, config.phases.size() - 1)
	if config.already_defeated == BossConfig.AlreadyDefeated.REMOVE:
		_hide_and_disable()
		queue_free()

func _apply_defeat_behavior() -> void:
	match config.defeat_behavior:
		BossConfig.DefeatBehavior.HIDE:
			_hide_and_disable()
		BossConfig.DefeatBehavior.FREE:
			_hide_and_disable()
			queue_free()

func _disable_combat() -> void:
	hurtbox.enabled = false
	if contact_hitbox:
		contact_hitbox.deactivate()

func _hide_and_disable() -> void:
	visible = false
	set_deferred(&"collision_layer", 0)
	hurtbox.set_deferred(&"monitorable", false)
	for child in get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false

func _update_contact(delta: float) -> void:
	if contact_hitbox == null or config.contact_damage <= 0 or not _fight_requested:
		return
	_contact_left -= delta
	if _contact_left <= 0.0:
		_contact_left = config.contact_interval
		contact_hitbox.activate()
