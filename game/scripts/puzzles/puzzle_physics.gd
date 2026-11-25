class_name PuzzlePhysics
extends RefCounted
## Static physics helpers shared by puzzle outputs: "would enabling this collider
## trap a player / pushable?" checks (Gate anti-trap, StateDriven/StateLever
## validation, PushBox destination checks) plus small child-building helpers.
## Queries need the space state: call them from _physics_process (or a coroutine
## resumed from SceneTree.physics_frame), never from inside physics callbacks.

## Groups whose bodies must never end up inside a newly enabled collider.
const PROTECTED_GROUPS: Array[StringName] = [&"player", &"pushable"]


## Every CollisionShape2D / CollisionPolygon2D below `root` (inclusive) whose
## direct parent is a PhysicsBody2D (Area2D shapes are not solid and are skipped).
static func collect_solid_shapes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	_collect(root, out)
	return out

static func _collect(node: Node, out: Array[Node]) -> void:
	if (node is CollisionShape2D or node is CollisionPolygon2D) and node.get_parent() is PhysicsBody2D:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)

## Every CollisionShape2D / CollisionPolygon2D below `root` (solid or Area2D).
static func collect_all_shapes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in root.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			out.append(child)
		out.append_array(collect_all_shapes(child))
	return out

## Enables/disables the given shape nodes (deferred: safe inside physics callbacks).
static func set_shapes_enabled(shapes: Array[Node], enabled: bool) -> void:
	for s in shapes:
		if is_instance_valid(s):
			s.set_deferred(&"disabled", not enabled)

## Shape2D resources + global transforms of a CollisionShape2D / CollisionPolygon2D,
## as an Array of [Shape2D, Transform2D] pairs.
static func shapes_of(node: Node) -> Array:
	var out := []
	if node is CollisionShape2D:
		var cs := node as CollisionShape2D
		if cs.shape:
			out.append([cs.shape, cs.global_transform])
	elif node is CollisionPolygon2D:
		var cp := node as CollisionPolygon2D
		if cp.polygon.size() >= 3:
			for convex in Geometry2D.decompose_polygon_in_convex(cp.polygon):
				var shape := ConvexPolygonShape2D.new()
				shape.points = convex
				out.append([shape, cp.global_transform])
	return out

## Bodies in PROTECTED_GROUPS overlapping `shape` at `xform`. `exclude` = RIDs to ignore.
static func find_protected_bodies(space: PhysicsDirectSpaceState2D, shape: Shape2D, xform: Transform2D,
		exclude: Array[RID] = []) -> Array[Node]:
	var out: Array[Node] = []
	if space == null or shape == null:
		return out
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = xform
	params.collision_mask = 0xFFFFFFFF
	params.collide_with_bodies = true
	params.collide_with_areas = false
	params.exclude = exclude
	for hit in space.intersect_shape(params, 32):
		var body: Object = hit.get("collider")
		if body is Node and is_protected(body) and not out.has(body):
			out.append(body)
	return out

## Protected bodies that would overlap any of `shape_nodes` if they were enabled.
## The shapes' own bodies are excluded from the query.
static func find_blockers_for_shapes(space: PhysicsDirectSpaceState2D, shape_nodes: Array[Node],
		exclude: Array[RID] = []) -> Array[Node]:
	var out: Array[Node] = []
	for node in shape_nodes:
		if not is_instance_valid(node):
			continue
		var ex: Array[RID] = exclude.duplicate()
		var body := node.get_parent() as CollisionObject2D
		if body:
			ex.append(body.get_rid())
		for pair: Array in shapes_of(node):
			for b in find_protected_bodies(space, pair[0], pair[1], ex):
				if not out.has(b):
					out.append(b)
	return out

## True for nodes in one of PROTECTED_GROUPS.
static func is_protected(node: Node) -> bool:
	for g in PROTECTED_GROUPS:
		if node.is_in_group(g):
			return true
	return false

## Space state of the world `node` lives in (null outside the tree).
static func space_of(node: Node2D) -> PhysicsDirectSpaceState2D:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_world_2d().direct_space_state

## First child of `parent` that is an instance of `type` (a class / script), or null.
static func find_child_of_type(parent: Node, type: Variant) -> Node:
	for child in parent.get_children():
		if is_instance_of(child, type):
			return child
	return null

## Returns `preferred` if set, else the first Interactable child of `owner_node`,
## else creates one (circle shape of `radius`) so code-built devices just work.
static func ensure_interactable(owner_node: Node2D, preferred: Interactable, prompt: String,
		radius: float = 20.0) -> Interactable:
	if preferred:
		return preferred
	var found := find_child_of_type(owner_node, Interactable) as Interactable
	if found:
		return found
	var it := Interactable.new()
	it.name = "Interactable"
	it.prompt_text = prompt
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	it.add_child(cs)
	owner_node.add_child(it)
	return it

## Adds a rectangular CollisionShape2D to `body` if it has no collision shape child yet.
static func ensure_rect_shape(body: CollisionObject2D, size: Vector2) -> void:
	for child in body.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			return
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
