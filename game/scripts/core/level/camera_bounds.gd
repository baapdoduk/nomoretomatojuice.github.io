@tool
class_name CameraBounds
extends Node2D
## Camera limit rectangle for a level (group "camera_bounds"). The Player's
## Camera2D copies these limits on spawn. `bounds` is relative to this node.

@export var bounds: Rect2 = Rect2(0, 0, 640, 360):
	set(value):
		bounds = value
		queue_redraw()


func _init() -> void:
	add_to_group(&"camera_bounds")


func get_global_rect() -> Rect2:
	return Rect2(global_position + bounds.position, bounds.size)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(bounds, Color(1.0, 0.6, 0.1, 0.9), false, 2.0)
