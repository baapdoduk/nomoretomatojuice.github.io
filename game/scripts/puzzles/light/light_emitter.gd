class_name LightEmitter
extends Node2D
## Emits a beam along its local +X axis (rotate the node to aim it).
##
## Power: `start_powered`, or - when `power_inputs` are assigned - the inputs
## combined with `power_logic` (switches, plates, controllers, StateSensors...).
## The beam is recomputed only after request_update() (sent through
## LightTracer.notify_changed) or every physics frame with `continuous_update`.
## Lit targets get add_light_source(self) / remove_light_source(self) calls
## (see LightReceiver). Emits beam_changed(global points) for the visuals
## (LightBeam Line2D child; one is created when none exists).
## Also satisfies the puzzle input contract (active = powered).

signal beam_changed(points: PackedVector2Array)
signal power_changed(powered: bool)
signal activated_changed(active: bool)

@export var start_powered: bool = true
## Optional inputs that power the emitter (overrides start_powered when non-empty).
@export var power_inputs: Array[Node] = []
@export var power_logic: PuzzleInputs.Logic = PuzzleInputs.Logic.ALL
## Recompute every physics frame (moving obstacles / emitters).
@export var continuous_update: bool = false
## Beam starts this many px in front of the emitter.
@export var start_offset: float = 0.0
@export var config: PuzzleConfig
## Create a LightBeam child for the visuals when none exists.
@export var auto_beam_visual: bool = true

var powered: bool = false
## Result of the last trace (null while unpowered / before the first trace).
var last_result: LightTracer.Result

var _dirty_frames := 0
var _lit: Array[Node] = []
var _points := PackedVector2Array()


func _ready() -> void:
	add_to_group(LightTracer.EMITTER_GROUP)
	PuzzleInputs.connect_inputs(power_inputs, _on_power_input_changed, name)
	powered = start_powered
	if auto_beam_visual and PuzzlePhysics.find_child_of_type(self, LightBeam) == null:
		var beam := LightBeam.new()
		beam.name = "Beam"
		add_child(beam)
	_sync_power_from_inputs.call_deferred()
	request_update()


func _exit_tree() -> void:
	_set_lit([])


func is_active() -> bool:
	return powered

func get_config() -> PuzzleConfig:
	return PuzzleConfig.resolve(config)

## Global emission direction.
func get_direction() -> Vector2:
	return Vector2.RIGHT.rotated(global_rotation)

func set_powered(value: bool) -> void:
	if value == powered:
		return
	powered = value
	power_changed.emit(value)
	activated_changed.emit(value)
	request_update()

func toggle_power() -> void:
	set_powered(not powered)

## Schedules a recompute. Runs on the next two physics frames so deferred
## collision changes (gates, state-driven nodes) are already applied.
func request_update() -> void:
	_dirty_frames = 2
	set_physics_process(true)

## Recomputes immediately. Needs the space state (call from a physics frame).
func update_beam() -> void:
	if not powered or not is_inside_tree():
		last_result = null
		_set_lit([])
		_set_points(PackedVector2Array())
		return
	var origin := global_position + get_direction() * start_offset
	last_result = LightTracer.trace(PuzzlePhysics.space_of(self), origin, get_direction(), get_config())
	_set_lit(last_result.targets)
	_set_points(last_result.points)

## Global beam polyline (empty while unpowered).
func get_beam_points() -> PackedVector2Array:
	return _points

## Nodes currently lit by this emitter.
func get_lit_targets() -> Array[Node]:
	return _lit.duplicate()

## Reset hook: power returns to its configured state.
func reset() -> void:
	if PuzzleInputs.count_valid(power_inputs) == 0:
		set_powered(start_powered)
	request_update()


func _physics_process(_delta: float) -> void:
	if continuous_update:
		update_beam()
		return
	if _dirty_frames <= 0:
		set_physics_process(false)
		return
	_dirty_frames -= 1
	update_beam()


func _set_lit(targets: Array[Node]) -> void:
	for old in _lit:
		if is_instance_valid(old) and not targets.has(old) and old.has_method(&"remove_light_source"):
			old.call(&"remove_light_source", self)
	for t in targets:
		if is_instance_valid(t) and not _lit.has(t) and t.has_method(&"add_light_source"):
			t.call(&"add_light_source", self)
	_lit = targets.duplicate()


func _set_points(points: PackedVector2Array) -> void:
	if points == _points:
		return
	_points = points
	beam_changed.emit(points)


func _sync_power_from_inputs() -> void:
	if PuzzleInputs.count_valid(power_inputs) > 0:
		set_powered(PuzzleInputs.evaluate(power_inputs, power_logic))


func _on_power_input_changed(_active: bool) -> void:
	_sync_power_from_inputs()
