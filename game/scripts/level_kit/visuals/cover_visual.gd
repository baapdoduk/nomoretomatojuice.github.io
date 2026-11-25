class_name CoverVisual
extends Node2D
## Placeholder foreground cover for a SecretArea (parent): a flat rectangle of
## parent.size (top-left origin) with optional texture tiling. The SecretArea
## fades this node's modulate.a. Swap for a foreground TileMapLayer/sprites.

@export var color: Color = Color(0.2, 0.17, 0.22)
@export var texture: Texture2D


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var size: Vector2 = get_parent().get(&"size") if get_parent() else Vector2(96, 64)
	if texture:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, size), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), color)
