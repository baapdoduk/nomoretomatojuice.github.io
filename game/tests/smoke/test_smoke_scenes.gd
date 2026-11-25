extends TestCase
## Smoke test for every lab scene in res://scenes/tests/ (except the hub).
## Picks up new labs automatically. For each: load through SceneRouter, drive ~3 s
## of scripted gameplay input, open/close the pause menu, check that a player exists
## when the scene references the player scene, then return to the hub.
## Any engine/script error during the run fails the test (runner Logger capture).

const SCENE_DIR := "res://scenes/tests/"
const HUB := "res://scenes/tests/test_hub.tscn"
const PLAYER_SCENE_DIR := "res://scenes/core/player/"

## [action, hold seconds]; null action = idle. Total ~3 s.
const SCRIPT: Array = [
	[&"move_right", 0.5], [&"move_left", 0.4], [&"jump", 0.15], [null, 0.2],
	[&"move_up", 0.3], [&"move_down", 0.3], [&"dash", 0.15], [null, 0.15],
	[&"attack", 0.15], [null, 0.2], [&"interact", 0.15], [null, 0.2],
	[&"context_left", 0.1], [&"context_right", 0.1],
]


func before_each() -> void:
	GameState.new_game(5)


static func find_lab_scenes() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(SCENE_DIR)
	if dir == null:
		return out
	var files := Array(dir.get_files())
	files.sort()
	for f: String in files:
		f = f.trim_suffix(".remap")
		var path := SCENE_DIR + f
		if f.ends_with(".tscn") and path != HUB and not out.has(path):
			out.append(path)
	return out


func test_lab_scenes_found() -> void:
	var scenes := find_lab_scenes()
	assert_true(scenes.has(SCENE_DIR + "controller_lab.tscn"), "controller lab discovered: %s" % str(scenes))


func test_all_lab_scenes_survive_scripted_input() -> void:
	var menu := get_tree().get_first_node_in_group(PauseMenu.GROUP) as PauseMenu
	for path in find_lab_scenes():
		print("        smoke: ", path)
		await _smoke_scene(path, menu)
	await change_scene_and_wait(HUB)
	assert_eq(SceneRouter.get_current_scene_path(), HUB, "back on hub")


func _smoke_scene(path: String, menu: PauseMenu) -> void:
	var expects_player := FileAccess.get_file_as_string(path).contains(PLAYER_SCENE_DIR)
	GameState.begin_chapter(StringName(path.get_file().get_basename()), path, &"start")
	await change_scene_and_wait(path, &"start")
	assert_eq(SceneRouter.get_current_scene_path(), path, "loaded " + path)
	if expects_player:
		assert_not_null(SceneRouter.get_player(), "player present in " + path)
	for step: Array in SCRIPT:
		var action: Variant = step[0]
		if action != null:
			Input.action_press(action)
		await wait_seconds(step[1])
		if action != null:
			Input.action_release(action)
	release_all_actions()
	# A lab may have started a transition (door, death -> respawn).
	await wait_until(func() -> bool: return not SceneRouter.is_transitioning, 5.0)
	if expects_player:
		var player := SceneRouter.get_player()
		assert_not_null(player, "player still present after input in " + path)
		if player:
			assert_true(player.global_position.is_finite(), "player position finite in " + path)
	if not SceneRouter.is_transitioning:
		var paused_before := get_tree().paused  # a lab popup may legitimately pause
		assert_true(menu.open(), "pause opens in " + path)
		assert_true(get_tree().paused, "paused in " + path)
		await wait_frames(2)
		menu.close()
		assert_eq(get_tree().paused, paused_before, "pause state restored in " + path)
	await change_scene_and_wait(HUB)
