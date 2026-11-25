extends Node2D
## Test fixture: minimal player stand-in.
var spawned_at: StringName = &""
func _ready() -> void:
	add_to_group(&"player")
func on_spawned(spawn: Node2D) -> void:
	spawned_at = spawn.get(&"spawn_id")
