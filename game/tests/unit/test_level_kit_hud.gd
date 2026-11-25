extends LevelKitTestCase
## HUD Fizz counter + polaroid shard slots; lab debug overlays hidden by default.

const HUD_SCENE := "res://scenes/core/ui/hud.tscn"


func test_hud_fizz_counter() -> void:
	var hud := instantiate_scene(HUD_SCENE) as HUD
	assert_eq(hud.get_fizz_count(), 0)
	GameState.add_coins(3)
	assert_eq(hud.get_fizz_count(), 3, "follows coins_changed")
	GameState.new_game(5)
	assert_eq(hud.get_fizz_count(), 0, "reset")


func test_hud_shard_slots_follow_level_info() -> void:
	var hud := instantiate_scene(HUD_SCENE) as HUD
	assert_false(hud.is_shard_bar_visible(), "hidden without LevelInfo")
	assert_eq(hud.get_shard_slots().size(), 0)
	var info := LevelInfo.new()
	info.level_id = &"kit_hud"
	add_test_node(info)
	await wait_frames(2)
	assert_true(hud.is_shard_bar_visible(), "shown with LevelInfo")
	assert_eq(hud.get_shard_slots(), [false, false, false] as Array[bool], "3 empty slots")
	GameState.set_flag(&"shard.kit_hud.1", true)
	assert_eq(hud.get_shard_slots(), [false, true, false] as Array[bool], "slot 1 filled")
	info.queue_free()
	await wait_frames(2)
	assert_false(hud.is_shard_bar_visible(), "hidden after LevelInfo left")


func test_exploration_lab_debug_hidden_by_default() -> void:
	var lab := ExplorationLab.new()
	assert_false(lab.show_debug, "debug overlay off by default")
	lab.free()
