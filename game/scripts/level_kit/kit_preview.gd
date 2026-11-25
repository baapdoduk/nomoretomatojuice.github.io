extends Node2D
## Kit preview (scenes/level_kit/kit_preview.tscn): paints the cellar tiles from
## ASCII maps and shows one of each level-kit component. Not a lab (nothing
## loads it automatically).
## Screenshots: godot --path game --rendering-driver opengl3 --resolution 1280x720 \
##   res://scenes/level_kit/kit_preview.tscn -- --kit-shot=/abs/dir

const WORLD_MAP: PackedStringArray = [
	"#                                                          #",
	"#                                                          #",
	"#                                                          #",
	"#                                                          #",
	"#                                                          #",
	"#                                                          #",
	"#                                                          #",
	"#                                                          #",
	"#                        ======                            #",
	"#                                                          #",
	"#                                            ########      #",
	"#                                                   #      #",
	"#             BB                         B          #      #",
	"#             BB                         B          #      #",
	"###################^^^########  ############################",
	"############################################################",
	"############################################################",
]
const DECO_MAP: PackedStringArray = [
	" o",
	"",
	"",
	"                          xxxxxxxx",
	"          ppp",
	"",
	"                                    w",
	"        w",
	"",
	"",
	"",
	"                                               o",
	"",
	"     kj     r                               c         kr",
]
## Tile row of the first map line (row 0 = floor top at y = 0).
const MAP_TOP := -14

@export var world_layer: TileMapLayer
@export var deco_layer: TileMapLayer


func _ready() -> void:
	if world_layer:
		CellarTiles.paint_ascii(world_layer, WORLD_MAP, Vector2i(0, MAP_TOP))
	if deco_layer:
		CellarTiles.paint_ascii(deco_layer, DECO_MAP, Vector2i(0, MAP_TOP))
	_apply_zoom.call_deferred()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--kit-shot="):
			_screenshots(arg.substr(11))


func _apply_zoom() -> void:
	var info := LevelInfo.find_in(get_tree())
	var player := get_tree().get_first_node_in_group(Layers.GROUP_PLAYER)
	var cam := player.get_node_or_null(^"Camera2D") as Camera2D if player else null
	if info and cam:
		cam.zoom = Vector2.ONE * info.camera_zoom


func _screenshots(out_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(30)
	_save(out_dir, "kit_preview_start")
	var player := get_tree().get_first_node_in_group(Layers.GROUP_PLAYER) as Node2D
	for stop: Vector2 in [Vector2(420, -1), Vector2(640, -1), Vector2(790, -1)]:
		if player:
			player.global_position = stop
		await _frames(45)
		_save(out_dir, "kit_preview_x%d" % int(stop.x))
	# overview: whole kit at a lower zoom
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam.limit_left = -10000
		cam.limit_right = 10000
		cam.limit_top = -10000
		cam.limit_bottom = 10000
		cam.position_smoothing_enabled = false
		cam.zoom = Vector2.ONE * 0.62
		cam.top_level = true
		cam.global_position = Vector2(480, -90)
	await _frames(20)
	_save(out_dir, "kit_preview_overview")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(dir: String, file: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file + ".png"))
	print("saved ", dir.path_join(file + ".png"))
