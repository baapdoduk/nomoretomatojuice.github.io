class_name TestCase
extends Node
## Minimal test base (no external deps). Put test files in res://tests/{unit,integration,smoke}/
## named test_*.gd, extend TestCase and write `func test_xxx()` methods (may await).
## Each test file instance is added under the runner (inside the SceneTree, autoloads available).
## Nodes created with add_test_node() are freed after every test.

var _failures: PackedStringArray = []
var _tracked: Array[Node] = []


## Override hooks (may await).
func before_each() -> void:
	pass

func after_each() -> void:
	pass


# ------------------------------------------------------------------ assertions

func fail(msg: String) -> void:
	_failures.append(msg)

func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)

func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		fail(msg)

func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_num(actual) and _is_num(expected)):
		fail("%s expected %s (%s) got %s (%s)" % [msg, str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual))])
	elif actual != expected:
		fail("%s expected %s got %s" % [msg, str(expected), str(actual)])

func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	if actual == unexpected:
		fail("%s did not expect %s" % [msg, str(unexpected)])

func assert_almost_eq(actual: float, expected: float, tolerance: float, msg: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("%s expected %.4f +/- %.4f got %.4f" % [msg, expected, tolerance, actual])

func assert_vec_almost_eq(actual: Vector2, expected: Vector2, tolerance: float, msg: String = "") -> void:
	if actual.distance_to(expected) > tolerance:
		fail("%s expected %s +/- %.3f got %s" % [msg, str(expected), tolerance, str(actual)])

func assert_not_null(value: Variant, msg: String = "expected non-null") -> void:
	if value == null:
		fail(msg)

func assert_null(value: Variant, msg: String = "expected null") -> void:
	if value != null:
		fail(msg)

func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


# ------------------------------------------------------------------ helpers

func add_test_node(node: Node, parent: Node = null) -> Node:
	(parent if parent else self).add_child(node)
	_tracked.append(node)
	return node

func instantiate_scene(path: String, parent: Node = null) -> Node:
	var packed: PackedScene = load(path)
	assert_not_null(packed, "scene loads: " + path)
	if packed == null:
		return null
	return add_test_node(packed.instantiate(), parent)

func wait_physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func wait_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, true).timeout

## Waits until `predicate` returns true or the timeout (seconds) elapses. Returns success.
func wait_until(predicate: Callable, timeout: float = 5.0) -> bool:
	var elapsed := 0.0
	while not predicate.call():
		if elapsed >= timeout:
			return false
		await get_tree().physics_frame
		elapsed += 1.0 / Engine.physics_ticks_per_second
	return true

## Simulates an action press for `frames` physics frames, then releases it.
func tap_action(action: StringName, frames: int = 2) -> void:
	Input.action_press(action)
	await wait_physics_frames(frames)
	Input.action_release(action)

func release_all_actions() -> void:
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			Input.action_release(action)

## Changes scene through SceneRouter and waits for the transition to end.
func change_scene_and_wait(path: String, spawn_id: StringName = &"") -> void:
	SceneRouter.change_scene(path, spawn_id, 0.0)
	await SceneRouter.transition_finished

func _cleanup_tracked() -> void:
	for node in _tracked:
		if is_instance_valid(node):
			node.queue_free()
	_tracked.clear()
	release_all_actions()
	if get_tree().paused:
		get_tree().paused = false
