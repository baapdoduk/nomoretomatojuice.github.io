class_name PressurePlate
extends PuzzleDevice
## Active while at least one body in group `player` or `pushable` overlaps it.
## Detection uses an Area2D (`detector`, else the first Area2D child, else one is
## created with a `plate_size` rectangle). The area masks Player + World (pushables
## live on World) and filters bodies by group.

## Bodies in these groups press the plate.
@export var trigger_groups: Array[StringName] = [&"player", &"pushable"]
## Stay active after the first press until reset().
@export var latch: bool = false
## Size of the auto-created detector.
@export var plate_size: Vector2 = Vector2(24, 8)
## Detector area (optional; auto-found/created).
@export var detector: Area2D

var _bodies: Array[Node] = []


func _ready() -> void:
	super._ready()
	if detector == null:
		detector = PuzzlePhysics.find_child_of_type(self, Area2D) as Area2D
	if detector == null:
		detector = Area2D.new()
		detector.name = "Detector"
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = plate_size
		cs.shape = rect
		detector.add_child(cs)
		add_child(detector)
	detector.collision_layer = 0
	detector.collision_mask = Layers.PLAYER | Layers.WORLD
	detector.monitoring = true
	detector.monitorable = false
	detector.body_entered.connect(_on_body_entered)
	detector.body_exited.connect(_on_body_exited)


## Bodies currently pressing the plate.
func get_pressing_bodies() -> Array[Node]:
	_prune()
	return _bodies.duplicate()


func reset() -> void:
	if persist_flag != &"":
		GameState.clear_flag(persist_flag)
	_prune()
	set_active(not _bodies.is_empty() or start_active)


func _on_body_entered(body: Node) -> void:
	if not _is_trigger(body) or _bodies.has(body):
		return
	_bodies.append(body)
	set_active(true)


func _on_body_exited(body: Node) -> void:
	_bodies.erase(body)
	_prune()
	if _bodies.is_empty() and not latch:
		set_active(false)


func _prune() -> void:
	_bodies = _bodies.filter(func(b: Node) -> bool: return is_instance_valid(b))


func _is_trigger(body: Node) -> bool:
	for g in trigger_groups:
		if body.is_in_group(g):
			return true
	return false
