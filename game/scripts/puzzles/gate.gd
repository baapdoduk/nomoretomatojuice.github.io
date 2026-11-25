class_name Gate
extends StaticBody2D
## Output: a World-layer blocker that opens when its conditions hold.
##
## Open condition = inputs part AND GameState part:
##  - inputs part: `inputs` (puzzle input contract) combined with `logic`, then
##    `invert`ed. Without valid inputs this part is true.
##  - GameState part: every `required_items` id owned and every `required_flags`
##    flag set (items are only checked, never consumed) -> "conditional gate".
## A gate with neither inputs nor conditions stays closed until force_open().
##
## Latching: `latch_open` keeps it open once opened. `open_flag` (optional) is
## written when the gate opens and makes the gate persistent: a gate whose flag is
## set loads open and stays open (typical for shortcuts / solved-puzzle doors).
##
## Anti-trap: closing never happens while a body in group player/pushable overlaps
## the gate's shapes; the close is deferred (closing_deferred) and retried every
## physics frame until clear.
##
## Also satisfies the puzzle input contract (active = open), so a gate can drive
## other outputs. Opening/closing notifies light emitters (gates block beams).

signal opened
signal closed
signal state_changed(is_open: bool)
## Emitted once when a close had to wait because something stands in the gateway.
signal closing_deferred(blockers: Array[Node])
signal activated_changed(active: bool)

@export var inputs: Array[Node] = []
@export var logic: PuzzleInputs.Logic = PuzzleInputs.Logic.ALL
## Invert the inputs part (open while the inputs are OFF).
@export var invert: bool = false
## Stay open once opened (until reset()).
@export var latch_open: bool = false
@export var start_open: bool = false
@export_group("Conditions")
@export var required_items: Array[StringName] = []
@export var required_flags: Array[StringName] = []
@export_group("Persistence")
## Written (true) when the gate opens; a set flag loads the gate open & latched.
@export var open_flag: StringName = &""
@export_group("Shape")
## Size of the auto-created collision shape (when the gate has no shape child).
@export var gate_size: Vector2 = Vector2(16, 48)

var is_open: bool = false
## True while a close is waiting for the gateway to clear.
var is_close_pending: bool = false

var _latched := false
var _forced := false
var _shapes: Array[Node] = []
var _deferred_reported := false


func _ready() -> void:
	collision_layer = Layers.WORLD
	PuzzlePhysics.ensure_rect_shape(self, gate_size)
	_shapes = PuzzlePhysics.collect_solid_shapes(self)
	PuzzleInputs.connect_inputs(inputs, _on_input_changed, name)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.inventory_changed.connect(_refresh)
	GameState.state_restored.connect(_refresh)
	if open_flag != &"" and GameState.has_flag(open_flag):
		_latched = true
	is_open = start_open or _latched
	_set_collision(not is_open)
	set_physics_process(false)
	# Inputs may not be ready yet (siblings later in the tree): evaluate after.
	_refresh.call_deferred()


func is_active() -> bool:
	return is_open

## The open condition from inputs + GameState (ignoring latch / anti-trap).
func evaluate_condition() -> bool:
	if _forced:
		return true
	var has_inputs := PuzzleInputs.count_valid(inputs) > 0
	var has_conditions := not required_items.is_empty() or not required_flags.is_empty()
	if not has_inputs and not has_conditions:
		return start_open
	var input_ok := true
	if has_inputs:
		input_ok = PuzzleInputs.evaluate(inputs, logic) != invert
	return input_ok and _conditions_met()

## Opens the gate regardless of conditions and keeps it open (until reset()).
func force_open() -> void:
	_forced = true
	_refresh()

## Re-evaluates now (called automatically on input / GameState changes).
func refresh() -> void:
	_refresh()

## Clears latch / force / open_flag and re-evaluates (closing obeys anti-trap).
func reset() -> void:
	_latched = false
	_forced = false
	if open_flag != &"":
		GameState.clear_flag(open_flag)
	_refresh()


func _conditions_met() -> bool:
	for id in required_items:
		if not GameState.has_item(id):
			return false
	for flag in required_flags:
		if not GameState.has_flag(flag):
			return false
	return true


func _refresh() -> void:
	if not is_inside_tree():
		return
	var want_open := evaluate_condition() or _latched
	if want_open:
		is_close_pending = false
		set_physics_process(false)
		if not is_open:
			_open()
	elif is_open:
		# Close on the next physics frame after the anti-trap check.
		is_close_pending = true
		_deferred_reported = false
		set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not is_close_pending:
		set_physics_process(false)
		return
	var blockers := PuzzlePhysics.find_blockers_for_shapes(PuzzlePhysics.space_of(self), _shapes)
	if not blockers.is_empty():
		if not _deferred_reported:
			_deferred_reported = true
			closing_deferred.emit(blockers)
		return
	is_close_pending = false
	set_physics_process(false)
	_close()


func _open() -> void:
	is_open = true
	if latch_open:
		_latched = true
	if open_flag != &"":
		_latched = true
		GameState.set_flag(open_flag, true)
		GameState.commit_progress()  # milestone: opened gates survive a later death
	_set_collision(false)
	opened.emit()
	_emit_changed()


func _close() -> void:
	is_open = false
	_set_collision(true)
	closed.emit()
	_emit_changed()


func _emit_changed() -> void:
	state_changed.emit(is_open)
	activated_changed.emit(is_open)
	LightTracer.notify_changed(get_tree())


func _set_collision(solid: bool) -> void:
	PuzzlePhysics.set_shapes_enabled(_shapes, solid)


func _on_input_changed(_active: bool) -> void:
	_refresh()


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if required_flags.has(flag) or flag == open_flag:
		if flag == open_flag and GameState.has_flag(open_flag):
			_latched = true
		_refresh()
