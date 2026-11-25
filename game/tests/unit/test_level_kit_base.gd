class_name LevelKitTestCase
extends PlayerTestCase
## Shared helpers for level-kit tests (no test_ methods: the runner skips it).

const KIT := "res://scenes/level_kit/"


## Minimal player stand-in: body on layer PLAYER in group "player" that records
## surface-modifier calls (the real Player API is added by another module).
class StandIn extends CharacterBody2D:
	var calls: Array = []
	var modifiers: Dictionary = {}
	var locks: Array[StringName] = []

	func _init() -> void:
		collision_layer = Layers.PLAYER
		collision_mask = 0
		add_to_group(Layers.GROUP_PLAYER)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(10, 16)
		shape.shape = rect
		shape.position = Vector2(0, -8)
		add_child(shape)

	func is_dead() -> bool:
		return false

	func set_surface_modifier(source: Object, speed: float, jump: float, accel: float) -> void:
		calls.append(["set", source, speed, jump, accel])
		modifiers[source] = [speed, jump, accel]

	func clear_surface_modifier(source: Object) -> void:
		calls.append(["clear", source])
		modifiers.erase(source)


func make_stand_in(pos: Vector2) -> StandIn:
	var s := StandIn.new()
	s.position = pos
	add_test_node(s)
	return s


func kit(scene: String, pos: Vector2 = Vector2.ZERO, setup: Callable = Callable()) -> Node:
	var packed: PackedScene = load(KIT + scene + ".tscn")
	var node: Node = packed.instantiate()
	if node is Node2D:
		(node as Node2D).position = pos
	if setup.is_valid():
		setup.call(node)
	add_test_node(node)
	return node


## Hurtbox + local Health on layer PLAYER (target for enemy Hitboxes).
func make_target(pos: Vector2, hp: int = 5) -> Hurtbox:
	var root := Node2D.new()
	root.position = pos
	var health := Health.new()
	health.max_health = hp
	root.add_child(health)
	var hb := Hurtbox.new()
	hb.collision_layer = Layers.PLAYER
	hb.collision_mask = 0
	hb.health = health
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 16)
	shape.shape = rect
	shape.position = Vector2(0, -8)
	hb.add_child(shape)
	root.add_child(hb)
	add_test_node(root)
	return hb
