extends Marker2D
## Test fixture: minimal spawn point (real one is module A's SpawnPoint).
@export var spawn_id: StringName = &""
@export var is_default: bool = false
func _ready() -> void:
	add_to_group(&"spawn_point")
