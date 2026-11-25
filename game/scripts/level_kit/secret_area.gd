class_name SecretArea
extends Area2D
## Foreground cover that fades out while the player is inside (hidden rooms).
## Fades `overlay` (default: the `Visual` child; placeholder CoverVisual draws a
## `size` rect — or point overlay at a foreground TileMapLayer) via modulate.a.
## The trigger shape defaults to the cover rect. Layer: none, mask: Player.
## Origin = top-left of the cover.

signal revealed
signal concealed

@export var size: Vector2 = Vector2(96, 64)
## Alpha of the cover while the player is inside.
@export_range(0.0, 1.0) var inside_alpha: float = 0.15
## Alpha change per second.
@export var fade_speed: float = 4.0
## Node faded with the cover alpha; empty = the `Visual` child (if any).
@export var overlay: CanvasItem

var cover_alpha: float = 1.0
var _inside: int = 0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	z_index = 40  # foreground
	if overlay == null:
		overlay = get_node_or_null(^"Visual") as CanvasItem
	KitUtil.ensure_rect_shape(self, size, size * 0.5)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_player_inside() -> bool:
	return _inside > 0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(Layers.GROUP_PLAYER):
		_inside += 1
		if _inside == 1:
			revealed.emit()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(Layers.GROUP_PLAYER):
		_inside = maxi(0, _inside - 1)
		if _inside == 0:
			concealed.emit()


func _process(delta: float) -> void:
	var target := inside_alpha if _inside > 0 else 1.0
	if not is_equal_approx(cover_alpha, target):
		cover_alpha = move_toward(cover_alpha, target, fade_speed * delta)
		if overlay:
			overlay.modulate.a = cover_alpha

