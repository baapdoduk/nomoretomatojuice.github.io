extends SceneTree
## Repaints the tile layers of the side-view levels from their ASCII layouts.
## The painted cells are written into the .tscn as the TileMapLayers'
## `tile_map_data`, so the levels stay fully editable in the editor. Only the
## tile_map_data lines of the layers named World / Deco / Foreground are
## replaced (text edit); every other line of the scene is left untouched, so
## nodes placed or tuned in the editor survive a rebuild.
##   godot --headless --path game --script res://scripts/levels/level_builder.gd
## A layout script provides consts MAP_TOP, WORLD_MAP, DECO_MAP and optionally
## FOREGROUND_MAP + FOREGROUND_ORIGIN (see cellar_shelf_layout.gd).

const LEVELS: Array[Dictionary] = [
	{"scene": "res://scenes/levels/cellar_shelf.tscn", "layout": "res://scripts/levels/cellar_shelf_layout.gd"},
	{"scene": "res://scenes/levels/_template_side_view.tscn", "layout": "res://scripts/levels/template_side_view_layout.gd"},
]


func _initialize() -> void:
	var failed := false
	for entry in LEVELS:
		if not build(entry.scene, entry.layout):
			failed = true
	quit(1 if failed else 0)


static func build(scene_path: String, layout_path: String) -> bool:
	var layout := load(layout_path) as Script
	var text := FileAccess.get_file_as_string(scene_path)
	if layout == null or text == "":
		push_error("level_builder: cannot read %s / %s" % [scene_path, layout_path])
		return false
	var c := layout.get_script_constant_map()
	var top := Vector2i(0, int(c.get("MAP_TOP", 0)))
	var layers := {
		"World": [c.get("WORLD_MAP", PackedStringArray()), top],
		"Deco": [c.get("DECO_MAP", PackedStringArray()), top],
	}
	if c.has("FOREGROUND_MAP"):
		layers["Foreground"] = [c.FOREGROUND_MAP, c.get("FOREGROUND_ORIGIN", Vector2i.ZERO)]
	var lines := text.split("\n")
	# PackedByteArray as base64 needs scene format 4.
	if lines.size() > 0 and lines[0].begins_with("[gd_scene"):
		lines[0] = lines[0].replace("format=3", "format=4")
	for layer_name: String in layers:
		var layer := TileMapLayer.new()
		layer.tile_set = load(CellarTiles.TILESET_PATH)
		CellarTiles.paint_ascii(layer, layers[layer_name][0], layers[layer_name][1])
		var data := 'tile_map_data = PackedByteArray("%s")' % Marshalls.raw_to_base64(layer.tile_map_data)
		layer.free()
		if not _set_node_property_line(lines, layer_name, "tile_map_data = ", data):
			push_error("level_builder: no TileMapLayer node '%s' in %s" % [layer_name, scene_path])
			return false
	var f := FileAccess.open(scene_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("\n".join(lines))
	f.close()
	print("level_builder: painted ", scene_path)
	return true


## Replaces (or inserts) the `prefix...` line of the root-level node `node_name`.
static func _set_node_property_line(lines: PackedStringArray, node_name: String, prefix: String, new_line: String) -> bool:
	var header := '[node name="%s" type="TileMapLayer" parent="."' % node_name
	for i in lines.size():
		if not lines[i].begins_with(header):
			continue
		var j := i + 1
		while j < lines.size() and lines[j] != "" and not lines[j].begins_with("["):
			if lines[j].begins_with(prefix):
				lines[j] = new_line
				return true
			j += 1
		lines.insert(i + 1, new_line)
		return true
	return false
