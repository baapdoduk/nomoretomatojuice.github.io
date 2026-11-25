class_name InteractionUtils
extends RefCounted
## Small helpers shared by module-A interaction nodes.


## Deterministic fallback GameState flag for a node that must persist but was
## authored without a flag: "auto.<scene file basename>.<node path in scene>".
## Warns (debug builds) so the designer can set an explicit flag.
static func derive_flag(node: Node, what: String) -> StringName:
	var scene := node.get_tree().current_scene if node.is_inside_tree() else null
	var base := ""
	var rel := String(node.name)
	if scene:
		base = scene.scene_file_path.get_file().get_basename()
		if scene.is_ancestor_of(node):
			rel = String(scene.get_path_to(node))
	var flag := StringName("auto.%s.%s" % [base, rel])
	if OS.is_debug_build():
		push_warning("%s has no %s; using derived flag '%s'" % [node.get_path(), what, flag])
	return flag
