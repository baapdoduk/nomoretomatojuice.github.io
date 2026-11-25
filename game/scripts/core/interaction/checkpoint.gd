class_name Checkpoint
extends Area2D
## Touch trigger that saves a checkpoint:
## GameState.save_checkpoint(current scene, "cp_<checkpoint_id>").
## Owns a child SpawnPoint whose spawn_id is set to "cp_<checkpoint_id>".
## Re-touching re-saves (latest progress); the toast only shows on activation.
## Layer: none, mask: Player.

signal activated
## Visual hook: true when this is the active (last saved) checkpoint.
signal active_changed(active: bool)

@export var checkpoint_id: StringName = &"checkpoint"
## Refill player health when saving.
@export var refill_health: bool = true
@export var toast_text: String = "Checkpoint"
## Child SpawnPoint (auto-found when empty).
@export var spawn_point: SpawnPoint

var is_active_checkpoint: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	if spawn_point == null:
		for child in get_children():
			if child is SpawnPoint:
				spawn_point = child
				break
	if spawn_point:
		spawn_point.spawn_id = get_spawn_id()
	body_entered.connect(_on_body_entered)
	GameState.checkpoint_saved.connect(_on_checkpoint_saved)
	_set_active(_is_saved_checkpoint(GameState.checkpoint))


func get_spawn_id() -> StringName:
	return StringName("cp_%s" % checkpoint_id)


## Saves this checkpoint (also callable from scripts).
func activate() -> void:
	var was_active := is_active_checkpoint
	GameState.save_checkpoint(SceneRouter.get_current_scene_path(), get_spawn_id(), refill_health)
	if not was_active:
		if toast_text != "":
			GameState.notify(toast_text)
		activated.emit()


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not (body as Player).is_dead():
		activate()


func _on_checkpoint_saved(snapshot: Dictionary) -> void:
	_set_active(_is_saved_checkpoint(snapshot))


func _is_saved_checkpoint(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	return String(snapshot.get("spawn_id", "")) == String(get_spawn_id()) \
		and String(snapshot.get("scene_path", "")) == SceneRouter.get_current_scene_path()


func _set_active(value: bool) -> void:
	if value == is_active_checkpoint:
		return
	is_active_checkpoint = value
	active_changed.emit(value)
