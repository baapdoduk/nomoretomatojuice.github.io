extends PlayerTestCase
## Pickup: touch / interact collection, duplicate guard, hidden on reload,
## memory popup.

const PICKUP := "res://scenes/core/interaction/pickup.tscn"


func _item(id: StringName, type := ItemData.ItemType.PROGRESSION, stack := 1) -> ItemData:
	var it := ItemData.new()
	it.id = id
	it.display_name = String(id).capitalize()
	it.type = type
	it.max_stack = stack
	return it


func _pickup(item: ItemData, pos: Vector2, props := {}) -> Pickup:
	var packed: PackedScene = load(PICKUP)
	var pk: Pickup = packed.instantiate()
	pk.item = item
	pk.position = pos
	for k in props:
		pk.set(k, props[k])
	add_test_node(pk)
	return pk


func test_touch_collect_and_duplicate_guard() -> void:
	capture_toasts()
	var key := _item(&"test_key")
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	var a := _pickup(key, Vector2(40, -10))
	var got := [0]
	a.collected.connect(func(_i: ItemData) -> void: got[0] += 1)
	await wait_physics_frames(2)
	assert_false(a.is_collected)
	input.move = Vector2.RIGHT
	var ok := await wait_until(func() -> bool: return a.is_collected, 2.0)
	input.move = Vector2.ZERO
	assert_true(ok, "collected on touch")
	assert_eq(got[0], 1)
	assert_eq(GameState.get_item_count(&"test_key"), 1)
	assert_false(a.visible, "hidden after collection")
	assert_false(toasts.has("Got Test Key"), "no duplicate pickup toast (HUD shows item_added)")
	# Same item again (e.g. a duplicate placed elsewhere / scene reload).
	var b := _pickup(key, Vector2(200, -10))
	await wait_physics_frames(1)
	assert_true(b.is_collected, "already-owned pickup hides on ready")
	assert_false(b.visible)
	var added: bool = await b.collect(p)
	assert_false(added, "collect() is a no-op")
	assert_eq(GameState.get_item_count(&"test_key"), 1, "never duplicated")
	assert_eq(got[0], 1)


func test_collected_flag_hides_stackable_after_reload() -> void:
	var coin := _item(&"test_coin", ItemData.ItemType.CONSUMABLE, 9)
	var a := _pickup(coin, Vector2.ZERO, {"collected_flag": &"test.coin_1"})
	await wait_physics_frames(1)
	assert_true(await a.collect(null), "collected")
	assert_true(GameState.has_flag(&"test.coin_1"))
	# Simulated reload: a fresh instance of the same pickup.
	a.queue_free()
	var again := _pickup(coin, Vector2.ZERO, {"collected_flag": &"test.coin_1"})
	await wait_physics_frames(1)
	assert_true(again.is_collected, "hidden after reload via collected_flag")
	# A different coin (other flag) is still collectable and stacks.
	var other := _pickup(coin, Vector2(50, 0), {"collected_flag": &"test.coin_2"})
	await wait_physics_frames(1)
	assert_false(other.is_collected)
	assert_true(await other.collect(null))
	assert_eq(GameState.get_item_count(&"test_coin"), 2, "stackable coins stack")


func test_interact_mode_requires_press() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	var pk := _pickup(_item(&"test_lens"), Vector2(6, -10), {"auto_collect": false})
	await wait_physics_frames(4)
	assert_false(pk.is_collected, "not collected by touch")
	assert_eq(p.interactor.target, pk, "focusable")
	input.interact_pressed = true
	await wait_physics_frames(3)
	assert_true(pk.is_collected, "collected on interact")
	assert_true(GameState.has_item(&"test_lens"))
	await wait_physics_frames(2)
	assert_null(p.interactor.target, "collected pickup no longer focusable")


func test_memory_item_popup_locks_player() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	var mem := _item(&"test_memory", ItemData.ItemType.MEMORY)
	mem.description = "A memory."
	var pk := _pickup(mem, Vector2(4, -10))
	await wait_physics_frames(4)
	assert_true(pk.is_collected)
	var popup := find_popup(get_tree().current_scene)
	assert_not_null(popup, "memory popup opened")
	assert_true(p.has_input_lock(&"popup"), "player locked by popup")
	if popup:
		assert_eq(popup.title_label.text, "Test Memory")
		popup.close()
	await wait_frames(2)
	assert_false(p.has_input_lock(&"popup"), "unlocked after close")
