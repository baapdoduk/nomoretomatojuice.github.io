class_name PuzzleSwitch
extends PuzzleDevice
## Interactable switch / lever. Operated through a child Interactable (assigned via
## `interactable`, else the first Interactable child, else one is created).
##
## Modes:
##  - TOGGLE: each use flips the state.
##  - MOMENTARY: each use activates it for `momentary_time` seconds (re-use restarts the timer).
##  - LATCH: first use turns it on for good (the Interactable is disabled) until reset().

enum Mode { TOGGLE, MOMENTARY, LATCH }

## Emitted on every successful use (before the state change propagates).
signal operated

@export var mode: Mode = Mode.TOGGLE
## MOMENTARY only: seconds the switch stays active after a use.
@export var momentary_time: float = 3.0
## Interactable that operates this switch (optional; auto-found/created).
@export var interactable: Interactable

var _momentary_left: float = 0.0


func _ready() -> void:
	super._ready()
	# A momentary switch never comes back "pressed" from a save.
	if mode == Mode.MOMENTARY and active:
		active = false
		_apply_state(false, true)
	interactable = PuzzlePhysics.ensure_interactable(self, interactable, "Use")
	interactable.interacted.connect(_on_interacted)
	_update_interactable()
	set_physics_process(false)


## What an interaction does. Callable directly (tests, scripted events).
func operate() -> void:
	operated.emit()
	match mode:
		Mode.TOGGLE:
			set_active(not active)
		Mode.MOMENTARY:
			_momentary_left = momentary_time
			set_physics_process(true)
			set_active(true)
		Mode.LATCH:
			set_active(true)


func reset() -> void:
	_momentary_left = 0.0
	set_physics_process(false)
	super.reset()


## Seconds left before a MOMENTARY switch turns off (0 otherwise).
func get_momentary_time_left() -> float:
	return _momentary_left


func _physics_process(delta: float) -> void:
	_momentary_left -= delta
	if _momentary_left <= 0.0:
		_momentary_left = 0.0
		set_physics_process(false)
		set_active(false)


func _apply_state(_value: bool, _instant: bool) -> void:
	_update_interactable()


func _update_interactable() -> void:
	if interactable:
		interactable.enabled = not (mode == Mode.LATCH and active)


func _on_interacted(_actor: Node) -> void:
	operate()
