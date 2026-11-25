class_name PuzzleInputs
extends RefCounted
## Static helpers for the puzzle input contract (see PuzzleDevice):
##   signal activated_changed(active: bool) + func is_active() -> bool
## Used by Gate, PuzzleController, LightEmitter... to wire exported Array[Node] inputs.

enum Logic {
	ALL, ## AND: every input active.
	ANY, ## OR: at least one input active.
}


## True when `node` satisfies the input contract.
static func is_input(node: Object) -> bool:
	return node != null and is_instance_valid(node) \
		and node.has_signal(&"activated_changed") and node.has_method(&"is_active")

## Connects `callable` (signature `(active: bool)`) to every valid input. Warns about invalid entries.
static func connect_inputs(nodes: Array[Node], callable: Callable, owner_name: String = "") -> void:
	for node in nodes:
		if not is_input(node):
			if node != null:
				push_warning("%s: input %s does not implement activated_changed/is_active" % [owner_name, node])
			continue
		if not node.is_connected(&"activated_changed", callable):
			node.connect(&"activated_changed", callable)

## Disconnects `callable` from every valid input.
static func disconnect_inputs(nodes: Array[Node], callable: Callable) -> void:
	for node in nodes:
		if is_input(node) and node.is_connected(&"activated_changed", callable):
			node.disconnect(&"activated_changed", callable)

## Number of valid inputs in `nodes`.
static func count_valid(nodes: Array[Node]) -> int:
	var n := 0
	for node in nodes:
		if is_input(node):
			n += 1
	return n

## Combines the inputs with `logic`. Returns `empty_value` when there is no valid input.
static func evaluate(nodes: Array[Node], logic: Logic, empty_value: bool = false) -> bool:
	var any_valid := false
	for node in nodes:
		if not is_input(node):
			continue
		any_valid = true
		var on: bool = node.call(&"is_active")
		if logic == Logic.ANY and on:
			return true
		if logic == Logic.ALL and not on:
			return false
	if not any_valid:
		return empty_value
	return logic == Logic.ALL

## Calls reset() on every node that has it (devices, controllers, mirrors, boxes...).
static func reset_nodes(nodes: Array[Node]) -> void:
	for node in nodes:
		if node != null and is_instance_valid(node) and node.has_method(&"reset"):
			node.call(&"reset")
