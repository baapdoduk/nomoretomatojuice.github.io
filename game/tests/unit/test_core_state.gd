extends TestCase
## Core contracts owned by the architect: GameState, Health/Hurtbox/Hitbox, Interactable, PuzzleDevice.

func before_each() -> void:
	GameState.new_game(5)

func _make_item(id: StringName, type: ItemData.ItemType = ItemData.ItemType.MEMORY, stack: int = 1) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.type = type
	item.max_stack = stack
	return item

func test_item_duplicate_guard() -> void:
	var key := _make_item(&"key_a", ItemData.ItemType.PROGRESSION)
	assert_true(GameState.add_item(key), "first add")
	assert_false(GameState.add_item(key), "duplicate rejected")
	assert_eq(GameState.get_item_count(&"key_a"), 1)
	var potion := _make_item(&"potion", ItemData.ItemType.CONSUMABLE, 3)
	for i in 5:
		GameState.add_item(potion)
	assert_eq(GameState.get_item_count(&"potion"), 3, "stack capped")
	assert_true(GameState.remove_item(&"potion", 2))
	assert_eq(GameState.get_item_count(&"potion"), 1)

func test_snapshot_restores_items_and_flags_together() -> void:
	GameState.add_item(_make_item(&"photo_1"))
	GameState.set_flag(&"door.a.open")
	GameState.save_checkpoint("res://x.tscn", &"cp")
	GameState.add_item(_make_item(&"photo_2"))
	GameState.set_flag(&"door.b.open")
	GameState.apply_damage(4)
	GameState.restore_snapshot(GameState.checkpoint)
	assert_true(GameState.has_item(&"photo_1"))
	assert_false(GameState.has_item(&"photo_2"), "post-checkpoint item reverted")
	assert_true(GameState.has_flag(&"door.a.open"))
	assert_false(GameState.has_flag(&"door.b.open"), "post-checkpoint flag reverted")
	assert_eq(GameState.health, 5, "checkpoint was taken at full health")

func test_save_load_roundtrip() -> void:
	var path := "user://test_save_roundtrip.json"
	GameState.set_flag(&"water.level", 2)
	GameState.save_checkpoint("res://y.tscn", &"start")
	assert_eq(GameState.save_to_disk(path), OK)
	GameState.new_game()
	assert_true(GameState.load_from_disk(path), "load ok")
	assert_eq(GameState.get_flag(&"water.level"), 2, "int flag survives JSON")
	assert_eq(String(GameState.checkpoint.get("scene_path")), "res://y.tscn")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_player_death_emitted_once() -> void:
	var count := [0]
	var cb := func() -> void: count[0] += 1
	GameState.player_died.connect(cb)
	GameState.apply_damage(10)
	GameState.apply_damage(10)
	GameState.player_died.disconnect(cb)
	assert_eq(count[0], 1)

func _make_target(layer: int) -> Array:
	var root := Node2D.new()
	var health := Health.new()
	health.max_health = 3
	health.name = "Health"
	root.add_child(health)
	var hurt := Hurtbox.new()
	hurt.collision_layer = layer
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10
	shape.shape = circle
	hurt.add_child(shape)
	root.add_child(hurt)
	add_test_node(root)
	return [root, health, hurt]

func test_hitbox_hits_once_per_activation() -> void:
	var t := _make_target(Layers.ENEMY)
	var health: Health = t[1]
	var hitbox := Hitbox.new()
	hitbox.collision_layer = Layers.PLAYER_ATTACK
	hitbox.collision_mask = Layers.ENEMY
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	hitbox.add_child(shape)
	add_test_node(hitbox)
	await wait_physics_frames(3)
	hitbox.activate()
	await wait_physics_frames(10)
	assert_eq(health.current, 2, "single hit during one activation")
	hitbox.deactivate()
	hitbox.activate()
	await wait_physics_frames(3)
	assert_eq(health.current, 1, "new activation hits again")

func test_health_invulnerability() -> void:
	var t := _make_target(Layers.ENEMY)
	var health: Health = t[1]
	health.invulnerability_time = 0.5
	assert_true(health.apply_damage(DamageEvent.create(1)))
	assert_false(health.apply_damage(DamageEvent.create(1)), "i-frames block")
	await wait_seconds(0.6)
	assert_true(health.apply_damage(DamageEvent.create(1)), "after i-frames")
	health.set_invulnerable_flag(&"boss_attacking", true)
	assert_false(health.apply_damage(DamageEvent.create(1)), "flag blocks")
	assert_eq(health.current, 1)

func test_interactable_conditions() -> void:
	var it := Interactable.new()
	it.required_item = &"key_a"
	it.consume_required_item = true
	add_test_node(it)
	var hits := [0]
	it.interacted.connect(func(_a: Node) -> void: hits[0] += 1)
	await it.interact(self)
	assert_eq(hits[0], 0, "blocked without item")
	GameState.add_item(_make_item(&"key_a", ItemData.ItemType.PROGRESSION))
	await it.interact(self)
	assert_eq(hits[0], 1, "works with item")
	assert_false(GameState.has_item(&"key_a"), "consumed")

func test_puzzle_device_persist_flag() -> void:
	var d := PuzzleDevice.new()
	d.persist_flag = &"puzzle.test.dev"
	add_test_node(d)
	d.set_active(true)
	assert_true(GameState.has_flag(&"puzzle.test.dev"))
	var d2 := PuzzleDevice.new()
	d2.persist_flag = &"puzzle.test.dev"
	add_test_node(d2)
	assert_true(d2.is_active(), "restored from flag")
	d2.reset()
	assert_false(d2.is_active())
