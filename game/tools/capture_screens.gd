extends Node
## Renders every lab and saves PNG screenshots (visual sanity check).
## Needs a real renderer:  xvfb-run -a godot --path game --rendering-driver opengl3 res://tools/capture_screens.tscn -- --out=/abs/dir
const SCENES := [
	"res://scenes/tests/test_hub.tscn",
	"res://scenes/tests/controller_lab.tscn",
	"res://scenes/tests/side_view_lab.tscn",
	"res://scenes/tests/top_down_lab.tscn",
	"res://scenes/tests/combat_lab.tscn",
	"res://scenes/tests/puzzle_lab.tscn",
	"res://scenes/tests/puzzle_lab_world.tscn",
	"res://scenes/tests/integration_overworld.tscn",
	"res://scenes/tests/integration_interior.tscn",
	"res://scenes/level_kit/kit_preview.tscn",
]
var _out := "user://screens"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	var holder := Node.new()
	get_tree().root.add_child.call_deferred(holder)
	await get_tree().process_frame
	get_tree().current_scene = holder
	for path in SCENES:
		if not ResourceLoader.exists(path):
			continue
		SceneRouter.change_scene(path, &"start", 0.0)
		await SceneRouter.transition_finished
		await _frames(40)
		_save(path.get_file().get_basename())
		if path.ends_with("combat_lab.tscn"):
			await _capture_combat()
	# pause menu over a gameplay lab
	SceneRouter.change_scene("res://scenes/tests/side_view_lab.tscn", &"start", 0.0)
	await SceneRouter.transition_finished
	await _frames(10)
	var pm := get_tree().get_first_node_in_group(&"pause_menu")
	if pm:
		pm.call(&"open")
		await _frames(10)
		_save("pause_menu")
		pm.call(&"close")
	get_tree().quit()

func _capture_combat() -> void:
	var player := SceneRouter.get_player()
	var boss := get_tree().get_first_node_in_group(&"boss")
	if player == null or boss == null:
		return
	boss.call(&"start_fight")
	player.global_position = boss.global_position + Vector2(-120, 40)
	for i in 240:
		await get_tree().physics_frame
		if str(boss.get(&"state")) == "2":  # TELEGRAPH
			break
	await _frames(45)
	_save("combat_lab_telegraph")

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())
