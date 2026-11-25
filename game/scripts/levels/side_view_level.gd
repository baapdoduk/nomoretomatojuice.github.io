class_name SideViewLevel
extends Node2D
## Root script of a side-view platformer level (scenes/levels/*.tscn).
## Holds no gameplay logic: the level is plain kit nodes + painted tile layers.
## It only exposes the level's *beat markers* - Marker2D children of the `Beats`
## node, one per beat start (name = beat id). Tests, the screenshot capture
## (scripts/levels/level_capture.gd) and designers use them to jump straight to
## a beat. Marker position = the player's feet.
## Template: scenes/levels/_template_side_view.tscn (docs/LEVEL_DESIGN_GUIDE.md).

## Node holding the beat markers.
@export var beats_root: Node2D


## Beat ids in scene order.
func get_beat_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if beats_root:
		for c in beats_root.get_children():
			if c is Marker2D:
				ids.append(String(c.name))
	return ids


## Global feet position of beat `id` (Vector2.INF when missing).
func get_beat_position(id: StringName) -> Vector2:
	var m := beats_root.get_node_or_null(NodePath(String(id))) as Node2D if beats_root else null
	return m.global_position if m else Vector2.INF
