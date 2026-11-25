class_name MemoryShard
extends Area2D
## Memory shard: per-level collectible. Touch -> GameState.set_milestone(
## "shard.<level_id>.<index>") (a milestone: survives a later death) + toast.
## Hidden on load when its flag is already set. level_id comes from the export
## or, when empty, from the scene's LevelInfo. Layer: none, mask: Player.
## Visuals: swappable `Visual` child (placeholder: ShardVisual) reading
## `collect_progress` (-1 idle, 0..1 collecting; node hides at 1).

signal collected(index: int)

## 0-based slot index (0 .. LevelInfo.shard_count-1).
@export_range(0, 7) var index: int = 0
## Optional override; empty = LevelInfo.level_id.
@export var level_id: StringName = &""
## Toast; "%d/%d" = collected / total. Empty = no toast.
@export var toast_format: String = "Memory shard %d/%d"
@export var collect_time: float = 0.4

var is_collected: bool = false
var collect_progress: float = -1.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	KitUtil.ensure_rect_shape(self, Vector2(14, 16), Vector2.ZERO)
	body_entered.connect(_on_body_entered)
	if GameState.has_flag(get_flag()):
		_hide_collected()


func get_level_id() -> StringName:
	if level_id != &"":
		return level_id
	var info := LevelInfo.find_in(get_tree()) if is_inside_tree() else null
	return info.level_id if info else &"level"


func get_flag() -> StringName:
	return LevelInfo.make_shard_flag(get_level_id(), index)


func _on_body_entered(body: Node2D) -> void:
	if KitUtil.is_live_player(body):
		collect()


## Sets the milestone flag (commits progress). Returns false if already collected.
func collect() -> bool:
	if is_collected:
		return false
	is_collected = true
	set_deferred(&"monitoring", false)
	GameState.set_milestone(get_flag(), true)
	if toast_format != "":
		var info := LevelInfo.find_in(get_tree())
		var total := info.shard_count if info else 3
		var got := 0
		for i in total:
			if GameState.has_flag(LevelInfo.make_shard_flag(get_level_id(), i)):
				got += 1
		GameState.notify(toast_format % [got, total] if toast_format.count("%d") == 2 else toast_format)
	collected.emit(index)
	collect_progress = 0.0
	return true


func _hide_collected() -> void:
	is_collected = true
	visible = false
	set_deferred(&"monitoring", false)


func _process(delta: float) -> void:
	if collect_progress >= 0.0:
		collect_progress += delta / maxf(collect_time, 0.01)
		if collect_progress >= 1.0:
			collect_progress = -1.0
			visible = false
