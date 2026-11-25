extends LevelKitTestCase
## Cellar TileSet: loads, World physics layer, one-way shelves, no-collision spikes/deco;
## paint_ascii picks ground edges and shelf ends.


func test_tileset_loads_with_world_physics() -> void:
	var ts: TileSet = load(CellarTiles.TILESET_PATH)
	assert_not_null(ts, "tileset loads")
	assert_eq(ts.tile_size, Vector2i(16, 16))
	assert_eq(ts.get_physics_layer_collision_layer(0), Layers.WORLD, "World layer")
	var src := ts.get_source(CellarTiles.SOURCE_ID) as TileSetAtlasSource
	assert_not_null(src.texture, "atlas texture")
	for coords: Vector2i in CellarTiles.SHELF_TILES:
		var d := src.get_tile_data(coords, 0)
		assert_eq(d.get_collision_polygons_count(0), 1, "shelf has collision %s" % coords)
		assert_true(d.is_collision_polygon_one_way(0, 0), "shelf one-way %s" % coords)
	for coords: Vector2i in CellarTiles.GROUND_TILES + CellarTiles.SOLID_TILES:
		var d := src.get_tile_data(coords, 0)
		assert_eq(d.get_collision_polygons_count(0), 1, "solid %s" % coords)
		assert_false(d.is_collision_polygon_one_way(0, 0), "not one-way %s" % coords)
	for coords: Vector2i in CellarTiles.DECO_TILES:
		assert_eq(src.get_tile_data(coords, 0).get_collision_polygons_count(0), 0, "no collision %s" % coords)


func test_paint_ascii_and_one_way_shelf_physics() -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = load(CellarTiles.TILESET_PATH)
	add_test_node(layer)
	CellarTiles.paint_ascii(layer, PackedStringArray([
		"   ===  ",
		"        ",
		"        ",
		"#####   ",
		"#####   ",
	]), Vector2i(-2, -3))
	assert_eq(layer.get_cell_atlas_coords(Vector2i(-2, 0)), CellarTiles.GROUND_TL, "corner")
	assert_eq(layer.get_cell_atlas_coords(Vector2i(0, 0)), CellarTiles.GROUND_TOP, "top rim")
	assert_eq(layer.get_cell_atlas_coords(Vector2i(2, 0)), CellarTiles.GROUND_TR, "right corner")
	assert_eq(layer.get_cell_atlas_coords(Vector2i(0, 1)), CellarTiles.GROUND_BOTTOM, "bottom")
	assert_eq(layer.get_cell_atlas_coords(Vector2i(1, -3)), CellarTiles.SHELF_LEFT, "shelf left")
	assert_eq(layer.get_cell_atlas_coords(Vector2i(2, -3)), CellarTiles.SHELF_MID, "shelf mid")
	assert_eq(layer.get_cell_atlas_coords(Vector2i(3, -3)), CellarTiles.SHELF_RIGHT, "shelf right")
	# A body jumping up through the shelf passes; falling onto it lands.
	var body := make_stand_in(Vector2(40, -20))  # below the shelf (shelf top y = -48)
	body.collision_mask = Layers.WORLD
	await wait_physics_frames(2)
	body.velocity = Vector2(0, -300)
	for i in 20:
		body.move_and_slide()
		await wait_physics_frames(1)
	assert_true(body.position.y < -48.0, "passed up through one-way shelf: %s" % body.position.y)
	body.velocity = Vector2(0, 200)
	for i in 30:
		body.velocity.y = 200
		body.move_and_slide()
		await wait_physics_frames(1)
	assert_almost_eq(body.position.y, -48.0, 1.0, "landed on shelf top")
