class_name LightReceiver
extends PuzzleDevice
## Puzzle device that is active while lit by at least one LightEmitter beam.
## Absorbs beams: its collider (a child StaticBody2D on World, auto-created as a
## circle of `receiver_radius` when missing) delegates classification to this node.
## `latch`: stays active after the first hit until reset().
## Several receivers are combined (AND/OR) by a PuzzleController.

signal lit_changed(is_lit: bool)

@export var latch: bool = false
@export var receiver_radius: float = 8.0

var _sources: Array[Node] = []


func _ready() -> void:
	super._ready()
	# Non-latching: the state is derived from the world (beam / bodies), so a
	# persisted "on" is not trusted on load; the first physics frames re-derive it.
	if not latch and active:
		active = false
		if persist_flag != &"":
			GameState.set_flag(persist_flag, false)
		_apply_state(false, true)
	if PuzzlePhysics.find_child_of_type(self, CollisionObject2D) == null:
		var body := StaticBody2D.new()
		body.name = "Body"
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = receiver_radius
		cs.shape = circle
		body.add_child(cs)
		add_child(body)
		LightTracer.notify_changed(get_tree())


func is_lit() -> bool:
	_prune()
	return not _sources.is_empty()

## Light classification hook (see LightTracer).
func get_light_response(_hit: Dictionary, _direction: Vector2) -> int:
	return LightTracer.Response.ABSORB

## Called by emitters whose beam now ends here.
func add_light_source(source: Node) -> void:
	if _sources.has(source):
		return
	var was_lit := is_lit()
	_sources.append(source)
	if not was_lit:
		lit_changed.emit(true)
	set_active(true)

## Called by emitters whose beam no longer ends here.
func remove_light_source(source: Node) -> void:
	if not _sources.has(source):
		return
	_sources.erase(source)
	if not is_lit():
		lit_changed.emit(false)
		if not latch:
			set_active(false)

## Clears the latch (state follows the current light).
func reset() -> void:
	if persist_flag != &"":
		GameState.clear_flag(persist_flag)
	set_active(is_lit())


func _prune() -> void:
	_sources = _sources.filter(func(s: Node) -> bool: return is_instance_valid(s))
