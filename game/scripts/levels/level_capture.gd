extends Node
## Screenshot capture of a side-view level, one PNG per beat marker
## (SideViewLevel.get_beat_ids()) plus a few close-ups and zoomed-out overview
## strips. Used to review readability of every beat:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##     --resolution 1280x720 res://scenes/levels/level_capture.tscn -- --out=/abs/dir \
##     [--level=res://scenes/levels/cellar_shelf.tscn]

@export_file("*.tscn") var level_path: String = "res://scenes/levels/cellar_shelf.tscn"

var _level: SideViewLevel
var _player: Player


func _ready() -> void:
	var out_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
		elif arg.begins_with("--level="):
			level_path = arg.substr(8)
	if out_dir == "":
		push_error("level_capture: pass -- --out=/abs/dir")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.set_setting(&"screen_shake", false)
	_run.call_deferred(out_dir)


func _run(out_dir: String) -> void:
	var tree := get_tree()
	_level = (load(level_path) as PackedScene).instantiate() as SideViewLevel
	tree.root.add_child(_level)
	tree.current_scene = _level
	_player = tree.get_first_node_in_group(Layers.GROUP_PLAYER) as Player
	await _frames(30)
	var i := 0
	for id in _level.get_beat_ids():
		await _shot(out_dir, "%02d_%s" % [i, id], _level.get_beat_position(id))
		i += 1
	if _level.name == "CellarShelf":
		await _cellar_extras(out_dir)
	await _overview(out_dir)
	tree.quit()


## Close-ups of states the beat markers do not show.
func _cellar_extras(out_dir: String) -> void:
	var drip := _level.get_node(^"Drips/Drip1") as DripEmitter
	drip.running = false
	drip.is_on = true
	drip._apply_state()
	await _shot(out_dir, "x1_drip_on", Vector2(2700, -1))
	drip.is_on = false
	drip._apply_state()
	await _shot(out_dir, "x2_drip_off", Vector2(2700, -1))
	drip.running = true
	await _shot(out_dir, "x3_climb_mid", Vector2(3288, -241))
	await _shot(out_dir, "x4_climb_top", Vector2(3288, -337))
	await _shot(out_dir, "x5_secret_inside", Vector2(3600, -337))
	await _shot(out_dir, "x6_shard_shelf", Vector2(2160, -113))
	await _shot(out_dir, "x7_door", Vector2(5260, -1))


func _shot(out_dir: String, file: String, feet: Vector2) -> void:
	if _player:
		_player.global_position = feet
		_player.velocity = Vector2.ZERO
	await _frames(50)
	_save(out_dir, file)


## Zoomed-out strips of the whole level (camera detached from the player).
func _overview(out_dir: String) -> void:
	var cam := get_viewport().get_camera_2d()
	var bounds := get_tree().get_first_node_in_group(&"camera_bounds") as CameraBounds
	if cam == null or bounds == null:
		return
	var r := bounds.get_global_rect()
	cam.process_mode = Node.PROCESS_MODE_DISABLED
	cam.limit_left = -100000
	cam.limit_right = 100000
	cam.limit_top = -100000
	cam.limit_bottom = 100000
	cam.zoom = Vector2.ONE * 0.5
	var view := Vector2(get_viewport().get_visible_rect().size) / cam.zoom
	var x := r.position.x + view.x * 0.5
	var n := 0
	while x - view.x * 0.5 < r.end.x:
		cam.global_position = Vector2(x, r.end.y - view.y * 0.5)
		cam.force_update_scroll()
		await _frames(5)
		_save(out_dir, "overview_%d" % n)
		n += 1
		x += view.x
	# upper part of the climb
	cam.global_position = Vector2(3400, r.position.y + view.y * 0.5)
	await _frames(5)
	_save(out_dir, "overview_top")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(dir: String, file: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(file + ".png"))
	print("saved ", dir.path_join(file + ".png"))
