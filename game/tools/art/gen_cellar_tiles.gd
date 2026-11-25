extends SceneTree
## Generates the original, code-drawn "dusk cellar" tile atlas and its TileSet.
## Two passes (the TileSet must reference the *imported* PNG):
##   godot --headless --path game -s res://tools/art/gen_cellar_tiles.gd -- --png
##   godot --headless --path game --import
##   godot --headless --path game -s res://tools/art/gen_cellar_tiles.gd -- --tileset
## Layout constants live in scripts/level_kit/cellar_tiles.gd (CellarTiles).

const T := 16

# dusk cellar palette (amber / teal / plum)
const OUTLINE := Color("140c16")
const STONE := Color("3a2838")
const STONE_DARK := Color("2a1c2a")
const STONE_LIGHT := Color("4c3548")
const SPECK := Color("2f5a5c")
const RIM := Color("e8a84a")
const RIM_HI := Color("ffd98a")
const RIM_DARK := Color("a8692e")
const WOOD := Color("9a6232")
const WOOD_TOP := Color("d99c50")
const WOOD_DARK := Color("5c3418")
const TEAL := Color("2f6668")
const TEAL_HI := Color("5aa39b")
const TEAL_DARK := Color("1b3d40")
const SPIKE_RED := Color("d8343c")
const SPIKE_WHITE := Color("f4ece4")
const SPIKE_BASE := Color("4a1e26")
const DECO := Color("4a3a52")
const DECO_HI := Color("6a5670")
const DECO_DARK := Color("30243a")
const GLOW := Color("f2c46a")

var img: Image


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--png") or args.is_empty():
		_make_png()
	if args.has("--tileset"):
		_make_tileset()
	quit()


# ------------------------------------------------------------------ drawing helpers

func _px(cell: Vector2i, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= T or y >= T:
		return
	img.set_pixel(cell.x * T + x, cell.y * T + y, c)

func _rect(cell: Vector2i, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(cell, xx, yy, c)

func _hash(cell: Vector2i, x: int, y: int) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (x * 83492791) ^ (y * 2654435761)) % 97


# ------------------------------------------------------------------ tiles

func _make_png() -> void:
	img = Image.create(CellarTiles.ATLAS_SIZE.x * T, CellarTiles.ATLAS_SIZE.y * T, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for col in 3:
		for row in 3:
			_ground(Vector2i(col, row), row == 0, row == 2, col == 0, col == 2, false)
	_ground(CellarTiles.GROUND_FILL_ALT, false, false, false, false, true)
	_block(CellarTiles.BLOCK, false)
	_block(CellarTiles.BLOCK_ALT, true)
	_shelf(CellarTiles.SHELF_LEFT, true, false)
	_shelf(CellarTiles.SHELF_MID, false, false)
	_shelf(CellarTiles.SHELF_RIGHT, false, true)
	_spikes(CellarTiles.SPIKES)
	_bottles(CellarTiles.DECO_BOTTLES)
	_crate(CellarTiles.DECO_CRATE)
	_cobweb(CellarTiles.DECO_COBWEB)
	_bricks(CellarTiles.DECO_BRICKS)
	_window(CellarTiles.DECO_WINDOW)
	_barrel(CellarTiles.DECO_BARREL)
	_planks(CellarTiles.DECO_PLANKS)
	_jars(CellarTiles.DECO_JARS)
	var path := ProjectSettings.globalize_path(CellarTiles.TEXTURE_PATH)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := img.save_png(path)
	print("cellar_tiles.png -> %s (%s)" % [path, error_string(err)])


## Stone ground with a lit amber rim on the open top edge and outlines on open sides.
func _ground(c: Vector2i, top: bool, bottom: bool, left: bool, right: bool, alt: bool) -> void:
	_rect(c, 0, 0, T, T, STONE)
	# soft rounded cobbles: darker seams every 8 px, offset per row
	for y in T:
		for x in T:
			var row_off := 4 if (y / 6) % 2 == 1 else 0
			if y % 6 == 5 or (x + row_off) % 8 == 7:
				_px(c, x, y, STONE_DARK)
			elif (x + row_off) % 8 == 0 and y % 6 != 5:
				_px(c, x, y, STONE_LIGHT)
			elif _hash(c, x, y) < 3:
				_px(c, x, y, SPECK)
	if alt:
		_rect(c, 5, 6, 3, 2, TEAL_DARK)
		_px(c, 6, 6, TEAL)
		_rect(c, 10, 11, 2, 2, TEAL_DARK)
	if left:
		_rect(c, 0, 0, 1, T, OUTLINE)
		_rect(c, 1, 0, 1, T, STONE_DARK)
	if right:
		_rect(c, T - 1, 0, 1, T, OUTLINE)
		_rect(c, T - 2, 0, 1, T, STONE_DARK)
	if bottom:
		_rect(c, 0, T - 1, T, 1, OUTLINE)
		_rect(c, 0, T - 2, T, 1, STONE_DARK)
	if top:
		_rect(c, 0, 0, T, 1, OUTLINE)
		_rect(c, 0, 1, T, 1, RIM_HI)
		_rect(c, 0, 2, T, 2, RIM)
		_rect(c, 0, 4, T, 1, RIM_DARK)
		# dripping rim tufts (wax-like), irregular
		for x in T:
			if _hash(c, x, 0) % 5 == 0:
				_px(c, x, 5, RIM_DARK)
		if left:
			_rect(c, 0, 0, 1, 5, OUTLINE)
			_px(c, 1, 1, OUTLINE)
		if right:
			_rect(c, T - 1, 0, 1, 5, OUTLINE)
			_px(c, T - 2, 1, OUTLINE)


## Teal cut-stone block with bevel; alt has a crack.
func _block(c: Vector2i, alt: bool) -> void:
	_rect(c, 0, 0, T, T, OUTLINE)
	_rect(c, 1, 1, T - 2, T - 2, TEAL)
	_rect(c, 1, 1, T - 2, 1, TEAL_HI)
	_rect(c, 1, 1, 1, T - 2, TEAL_HI)
	_rect(c, 1, T - 2, T - 2, 1, TEAL_DARK)
	_rect(c, T - 2, 1, 1, T - 2, TEAL_DARK)
	_rect(c, 4, 4, 8, 8, TEAL_DARK)
	_rect(c, 5, 5, 6, 6, TEAL)
	if alt:
		for i in 6:
			_px(c, 3 + i, 9 + (i % 2), OUTLINE)
	_px(c, 1, 1, RIM)  # a warm glint so blocks read as lit from above


## Plank shelf: lit top strip (collision 5 px), bracket underneath.
func _shelf(c: Vector2i, left_end: bool, right_end: bool) -> void:
	_rect(c, 0, 0, T, 1, OUTLINE)
	_rect(c, 0, 1, T, 1, WOOD_TOP)
	_rect(c, 0, 2, T, 2, WOOD)
	_rect(c, 0, 4, T, 1, WOOD_DARK)
	_rect(c, 0, 5, T, 1, OUTLINE)
	for x in [5, 12]:
		_px(c, x, 3, WOOD_DARK)  # nail heads / grain
	if left_end:
		_rect(c, 0, 0, 1, 6, OUTLINE)
		# diagonal bracket
		for i in 6:
			_px(c, 3 + i / 2, 6 + i, WOOD_DARK)
		_rect(c, 2, 6, 1, 7, OUTLINE)
	if right_end:
		_rect(c, T - 1, 0, 1, 6, OUTLINE)
		for i in 6:
			_px(c, T - 4 - i / 2, 6 + i, WOOD_DARK)
		_rect(c, T - 3, 6, 1, 7, OUTLINE)


## Red/white jagged spikes on a dark base (bottom-aligned).
func _spikes(c: Vector2i) -> void:
	_rect(c, 0, T - 3, T, 3, SPIKE_BASE)
	_rect(c, 0, T - 1, T, 1, OUTLINE)
	var top := T - 13
	for s in 2:
		var cx := s * 8 + 4
		for r in 11:
			var hw := (r * 4) / 10
			var x0 := cx - 1 - hw
			var x1 := cx + hw
			for x in range(x0, x1 + 1):
				var col := SPIKE_WHITE if r < 4 else SPIKE_RED
				if x == x1 and r >= 4:
					col = SPIKE_RED.darkened(0.35)
				_px(c, x, top + r, col)
			_px(c, x0 - 1, top + r, OUTLINE)
			_px(c, x1 + 1, top + r, OUTLINE)


func _bottles(c: Vector2i) -> void:
	for b in [[2, 6, TEAL_DARK], [7, 4, DECO_HI], [11, 7, DECO]]:
		var x: int = b[0]
		var top: int = b[1]
		var col: Color = b[2]
		_rect(c, x, top + 4, 4, T - top - 4, col)
		_rect(c, x + 1, top, 2, 4, col)
		_px(c, x + 1, top + 5, DECO_HI.lightened(0.2))
	_rect(c, 0, T - 1, T, 1, DECO_DARK)


func _crate(c: Vector2i) -> void:
	_rect(c, 1, 2, 14, 14, DECO_DARK)
	_rect(c, 2, 3, 12, 12, DECO)
	_rect(c, 2, 8, 12, 1, DECO_DARK)
	for i in 12:
		_px(c, 2 + i, 3 + i, DECO_HI)


func _cobweb(c: Vector2i) -> void:
	var web := Color(0.75, 0.72, 0.8, 0.45)
	for i in T:
		_px(c, i, 0, web)
		_px(c, 0, i, web)
		_px(c, i, i, web)
	for r in [5, 10]:
		for i in r + 1:
			_px(c, i, r - i + (r / 5), web)


func _bricks(c: Vector2i) -> void:
	_rect(c, 0, 0, T, T, DECO_DARK)
	for y in [0, 4, 8, 12]:
		var off := 4 if (y / 4) % 2 == 1 else 0
		for x in range(-8, T, 8):
			_rect(c, x + off + 1, y + 1, 6, 2, DECO)


## Glowing arched window slit (warm amber) — the cellar's light source.
func _window(c: Vector2i) -> void:
	_rect(c, 3, 2, 10, 13, DECO_DARK)
	_rect(c, 4, 4, 8, 10, GLOW)
	_rect(c, 5, 3, 6, 1, GLOW)
	_rect(c, 7, 4, 2, 10, RIM_DARK)
	_rect(c, 4, 8, 8, 1, RIM_DARK)
	_rect(c, 4, 4, 8, 2, RIM_HI)


func _barrel(c: Vector2i) -> void:
	_rect(c, 3, 1, 10, 15, WOOD_DARK)
	_rect(c, 2, 4, 12, 9, WOOD_DARK)
	_rect(c, 4, 2, 8, 13, WOOD.darkened(0.35))
	_rect(c, 2, 4, 12, 1, DECO_HI)
	_rect(c, 2, 11, 12, 1, DECO_HI)


func _planks(c: Vector2i) -> void:
	_rect(c, 0, 0, T, T, DECO_DARK)
	for x in [0, 5, 10]:
		_rect(c, x + 1, 0, 4, T, DECO)
		_px(c, x + 2, 3, DECO_DARK)
		_px(c, x + 3, 11, DECO_DARK)


func _jars(c: Vector2i) -> void:
	for j in [[1, 8, DECO], [8, 6, TEAL_DARK]]:
		var x: int = j[0]
		var top: int = j[1]
		_rect(c, x, top, 7, T - top, j[2])
		_rect(c, x + 1, top - 2, 5, 2, DECO_HI)
		_px(c, x + 1, top + 2, DECO_HI)


# ------------------------------------------------------------------ tileset

func _make_tileset() -> void:
	var tex: Texture2D = load(CellarTiles.TEXTURE_PATH)
	if tex == null:
		push_error("run --png and --import first")
		return
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Layers.WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, CellarTiles.SOURCE_ID)
	for y in CellarTiles.ATLAS_SIZE.y:
		for x in CellarTiles.ATLAS_SIZE.x:
			src.create_tile(Vector2i(x, y))
	var h := T * 0.5
	var full := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	var strip := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h),
		Vector2(h, -h + CellarTiles.SHELF_THICKNESS), Vector2(-h, -h + CellarTiles.SHELF_THICKNESS)])
	for coords: Vector2i in CellarTiles.GROUND_TILES + CellarTiles.SOLID_TILES:
		var data := src.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, full)
	for coords: Vector2i in CellarTiles.SHELF_TILES:
		var data := src.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, strip)
		data.set_collision_polygon_one_way(0, 0, true)
	var err := ResourceSaver.save(ts, CellarTiles.TILESET_PATH)
	print("cellar_tileset.tres -> %s" % error_string(err))
