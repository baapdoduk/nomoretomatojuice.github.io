class_name LevelInfo
extends Node
## Per-level metadata (one per platformer level, group "level_info").
## Read by the HUD (shard slots), MemoryShard / MemoryDoor (flag names) and the
## camera rig (zoom override).
##   shard flags:    "shard.<level_id>.<index>"  (index 0 .. shard_count-1)
##   clear milestone "level.<level_id>.clear"

const GROUP := &"level_info"

@export var level_id: StringName = &"level"
@export var display_name: String = ""
@export_range(0, 8) var shard_count: int = 3
## Side-view camera zoom for this level (camera rig reads it).
@export_range(0.5, 4.0, 0.05) var camera_zoom: float = 1.5


func _enter_tree() -> void:
	add_to_group(GROUP)


## First LevelInfo in the tree (null when the scene has none).
static func find_in(tree: SceneTree) -> LevelInfo:
	return tree.get_first_node_in_group(GROUP) as LevelInfo if tree else null


static func make_shard_flag(p_level_id: StringName, index: int) -> StringName:
	return StringName("shard.%s.%d" % [p_level_id, index])


static func make_clear_flag(p_level_id: StringName) -> StringName:
	return StringName("level.%s.clear" % p_level_id)


func get_shard_flag(index: int) -> StringName:
	return make_shard_flag(level_id, index)


func get_clear_flag() -> StringName:
	return make_clear_flag(level_id)


## One bool per shard slot: collected?
func get_shard_states() -> Array[bool]:
	var out: Array[bool] = []
	for i in shard_count:
		out.append(GameState.has_flag(get_shard_flag(i)))
	return out


func is_cleared() -> bool:
	return GameState.has_flag(get_clear_flag())
