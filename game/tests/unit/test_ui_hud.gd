extends TestCase
## HUD reacts to GameState signals (hearts, item bar, toasts) and works without a player.

const HUD_SCENE := "res://scenes/core/ui/hud.tscn"

func before_each() -> void:
	GameState.new_game(5)

func _hud() -> HUD:
	return instantiate_scene(HUD_SCENE) as HUD

func _item(id: StringName, item_name: String) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = item_name
	item.placeholder_color = Color.CYAN
	return item

func test_hearts_follow_health() -> void:
	var hud := _hud()
	assert_eq(hud.get_heart_values(), Vector2i(5, 5), "initial")
	GameState.apply_damage(2)
	assert_eq(hud.get_heart_values(), Vector2i(3, 5), "after damage")
	GameState.set_max_health(7)
	assert_eq(hud.get_heart_values(), Vector2i(7, 7), "max raised + refill")
	assert_true(hud.is_in_group(&"hud"), "in hud group")
	assert_null(SceneRouter.get_player(), "no player needed")

func test_item_bar_and_pickup_toast() -> void:
	var hud := _hud()
	assert_true(GameState.add_item(_item(&"photo_a", "Old Photo")))
	assert_eq(hud.get_item_bar_ids(), [&"photo_a"] as Array[StringName], "item shown")
	assert_true(hud.get_visible_toasts().has("Got: Old Photo"), "pickup toast")
	GameState.remove_item(&"photo_a")
	assert_eq(hud.get_item_bar_ids().size(), 0, "item removed from bar")
	GameState.add_item(_item(&"photo_b", "B"))
	GameState.restore_snapshot(GameState.make_snapshot("res://x.tscn", &""))
	assert_eq(hud.get_item_bar_ids(), [&"photo_b"] as Array[StringName], "rebuilt after restore")

func test_toast_queue() -> void:
	var hud := _hud()
	hud.max_visible_toasts = 3
	for i in 5:
		GameState.notify("msg %d" % i, 0.1)
	assert_eq(hud.get_visible_toasts().size(), 3, "three visible")
	assert_eq(hud.get_queued_toast_count(), 2, "two queued")
	assert_eq(hud.get_visible_toasts()[0], "msg 0")
	await wait_seconds(0.5)
	assert_eq(hud.get_visible_toasts().size(), 0, "all expired")
	assert_eq(hud.get_queued_toast_count(), 0, "queue drained")
	get_tree().call_group(&"hud", &"show_toast", "via group", 1.0)
	assert_true(hud.get_visible_toasts().has("via group"), "group call")

func test_toasts_carry_over_scene_change() -> void:
	var hud := _hud()
	hud.show_toast("Tip: carried", 3.0)
	SceneRouter.transition_started.emit("res://dummy.tscn", &"")
	hud.queue_free()
	await wait_frames(1)
	var next := _hud()
	assert_true(next.get_visible_toasts().has("Tip: carried"), "toast carried to new HUD")

func test_debug_corner_toggle() -> void:
	var hud := _hud()
	hud.debug_visible = true
	await wait_frames(2)
	var label: Label = hud.get_node("%DebugLabel")
	assert_true(label.visible, "visible")
	assert_true(label.text.contains("HP 5/5"), "debug text: " + label.text)
	hud.debug_visible = false
	assert_false(label.visible)
