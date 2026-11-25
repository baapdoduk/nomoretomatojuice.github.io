@tool
class_name SpawnPoint
extends Marker2D
## Where SceneRouter places the player (group "spawn_point").
## Ids: &"start" (default), &"from_<scene_name>" for door arrivals,
## &"cp_<name>" for checkpoints (Checkpoint sets its own child's id).

@export var spawn_id: StringName = &"start":
	set(value):
		spawn_id = value
		queue_redraw()
## Used when no spawn id is requested (or the requested one is missing).
@export var is_default: bool = false
## Facing applied to the player on spawn (Player.on_spawned).
@export var facing: Vector2 = Vector2.RIGHT:
	set(value):
		facing = value
		queue_redraw()


func _init() -> void:
	add_to_group(Layers.GROUP_SPAWN_POINT)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_line(Vector2.ZERO, facing.normalized() * 14.0, Color(0.4, 1.0, 0.5), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(4, -4), String(spawn_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.4, 1.0, 0.5))
