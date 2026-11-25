@tool
class_name CellarShelf
extends OneWayPlatform
## OneWayPlatform drawn with the cellar shelf tiles (plank + brackets). Use it
## instead of painted shelf tiles where drop-through (down + jump) must work:
## SideViewMotor only drops through PhysicsBody2D colliders in group
## "one_way_platform", and a TileMapLayer is not one. Keep `width` a multiple of 16.

var _tex: Texture2D


func _init() -> void:
	super._init()
	thickness = CellarTiles.SHELF_THICKNESS


func _draw() -> void:
	if _tex == null:
		_tex = load(CellarTiles.TEXTURE_PATH) as Texture2D
	if _tex == null:
		super._draw()
		return
	var t := CellarTiles.TILE
	var n := maxi(1, roundi(width / t))
	var x0 := -n * t * 0.5
	for i in n:
		var coords := CellarTiles.SHELF_MID
		if n > 1 and i == 0:
			coords = CellarTiles.SHELF_LEFT
		elif n > 1 and i == n - 1:
			coords = CellarTiles.SHELF_RIGHT
		draw_texture_rect_region(_tex, Rect2(x0 + i * t, 0, t, t), Rect2(Vector2(coords * t), Vector2(t, t)))
