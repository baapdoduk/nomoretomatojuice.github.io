class_name CellarTiles
extends RefCounted
## Atlas layout of the "dusk cellar" tile set (16 px grid) shared by the art
## generator (tools/art/gen_cellar_tiles.gd), the TileSet resource and levels.
## Also offers paint_ascii() to paint a TileMapLayer from a text map.
##
## Physics (TileSet physics layer 0 = Layers.WORLD): ground + block tiles are full
## squares; SHELF_* are a thin one-way top strip; spikes and deco have no collision
## (spike damage comes from the Spikes component).

const TILE := 16
const TEXTURE_PATH := "res://assets/placeholder/tiles/cellar_tiles.png"
const TILESET_PATH := "res://resources/level/cellar_tileset.tres"
const SOURCE_ID := 0
const ATLAS_SIZE := Vector2i(8, 3)
## Height of the one-way strip on shelf tiles (px, from the tile top).
const SHELF_THICKNESS := 5

const GROUND_TL := Vector2i(0, 0)
const GROUND_TOP := Vector2i(1, 0)
const GROUND_TR := Vector2i(2, 0)
const GROUND_LEFT := Vector2i(0, 1)
const GROUND_FILL := Vector2i(1, 1)
const GROUND_RIGHT := Vector2i(2, 1)
const GROUND_BL := Vector2i(0, 2)
const GROUND_BOTTOM := Vector2i(1, 2)
const GROUND_BR := Vector2i(2, 2)
const BLOCK := Vector2i(3, 0)
const BLOCK_ALT := Vector2i(3, 1)
const GROUND_FILL_ALT := Vector2i(3, 2)
const SHELF_LEFT := Vector2i(4, 0)
const SHELF_MID := Vector2i(5, 0)
const SHELF_RIGHT := Vector2i(6, 0)
const SPIKES := Vector2i(7, 0)
const DECO_BOTTLES := Vector2i(4, 1)
const DECO_CRATE := Vector2i(5, 1)
const DECO_COBWEB := Vector2i(6, 1)
const DECO_BRICKS := Vector2i(7, 1)
const DECO_WINDOW := Vector2i(4, 2)
const DECO_BARREL := Vector2i(5, 2)
const DECO_PLANKS := Vector2i(6, 2)
const DECO_JARS := Vector2i(7, 2)

const GROUND_TILES: Array[Vector2i] = [GROUND_TL, GROUND_TOP, GROUND_TR, GROUND_LEFT, GROUND_FILL,
	GROUND_RIGHT, GROUND_BL, GROUND_BOTTOM, GROUND_BR, GROUND_FILL_ALT]
const SOLID_TILES: Array[Vector2i] = [BLOCK, BLOCK_ALT]
const SHELF_TILES: Array[Vector2i] = [SHELF_LEFT, SHELF_MID, SHELF_RIGHT]
const DECO_TILES: Array[Vector2i] = [SPIKES, DECO_BOTTLES, DECO_CRATE, DECO_COBWEB, DECO_BRICKS,
	DECO_WINDOW, DECO_BARREL, DECO_PLANKS, DECO_JARS]


## Paints `rows` into `layer` (cell (0,0) = first char of first row, offset by `origin`).
## Legend: '#' ground (edges/corners picked from neighbours), 'B' block,
## '=' shelf (ends picked automatically), '^' spikes (visual only), '.'/' ' empty,
## 'w' window, 'k' bottles, 'c' crate, 'r' barrel, 'j' jars, 'p' planks, 'x' bricks, 'o' cobweb.
static func paint_ascii(layer: TileMapLayer, rows: PackedStringArray, origin: Vector2i = Vector2i.ZERO) -> void:
	var is_ground := func(x: int, y: int) -> bool:
		return y >= 0 and y < rows.size() and x >= 0 and x < rows[y].length() and rows[y][x] == "#"
	var is_shelf := func(x: int, y: int) -> bool:
		return y >= 0 and y < rows.size() and x >= 0 and x < rows[y].length() and rows[y][x] == "="
	var deco := {"B": BLOCK, "^": SPIKES, "w": DECO_WINDOW, "k": DECO_BOTTLES, "c": DECO_CRATE,
		"r": DECO_BARREL, "j": DECO_JARS, "p": DECO_PLANKS, "x": DECO_BRICKS, "o": DECO_COBWEB}
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var ch := row[x]
			var coords := Vector2i(-1, -1)
			if ch == "#":
				coords = ground_tile_for(not is_ground.call(x, y - 1), not is_ground.call(x, y + 1),
					not is_ground.call(x - 1, y), not is_ground.call(x + 1, y))
				if coords == GROUND_FILL and (x * 7 + y * 3) % 5 == 0:
					coords = GROUND_FILL_ALT
			elif ch == "=":
				var l: bool = is_shelf.call(x - 1, y)
				var r: bool = is_shelf.call(x + 1, y)
				coords = SHELF_MID if l and r else (SHELF_RIGHT if l else (SHELF_LEFT if r else SHELF_MID))
			elif deco.has(ch):
				coords = deco[ch]
			if coords.x >= 0:
				layer.set_cell(origin + Vector2i(x, y), SOURCE_ID, coords)


## Ground atlas coordinates for a cell whose top/bottom/left/right neighbour is open.
static func ground_tile_for(open_top: bool, open_bottom: bool, open_left: bool, open_right: bool) -> Vector2i:
	var col := 0 if open_left and not open_right else (2 if open_right and not open_left else 1)
	var row := 0 if open_top else (2 if open_bottom else 1)
	return Vector2i(col, row)
