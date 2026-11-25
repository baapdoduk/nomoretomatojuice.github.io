extends LevelKitTestCase
## Fizz, FizzTrail and MemoryShard.


func test_fizz_adds_coins_once_and_frees() -> void:
	var fizz := kit("fizz_pickup", Vector2(0, -6)) as FizzPickup
	var got: Array[int] = []
	fizz.collected.connect(func(v: int) -> void: got.append(v))
	await wait_physics_frames(2)
	make_stand_in(Vector2(0, 0))
	await wait_physics_frames(3)
	assert_eq(GameState.coins, 1, "one coin")
	assert_eq(got, [1] as Array[int], "collected once")
	assert_false(fizz.collect(), "second collect refused")
	assert_eq(GameState.coins, 1, "still one coin")
	await wait_seconds(fizz.pop_time + 0.15)
	assert_false(is_instance_valid(fizz), "freed after pop")


func test_fizz_trail_places_pickups_on_arc() -> void:
	var trail := kit("fizz_trail", Vector2(10, 0), func(n: Node) -> void:
		n.count = 5
		n.end_point = Vector2(100, 0)
		n.arc_height = 40.0) as FizzTrail
	var pickups := trail.get_pickups()
	assert_eq(pickups.size(), 5, "5 pickups")
	assert_vec_almost_eq((pickups[0] as Node2D).position, Vector2(0, 0), 0.01, "start")
	assert_vec_almost_eq((pickups[2] as Node2D).position, Vector2(50, -40), 0.01, "apex")
	assert_vec_almost_eq((pickups[4] as Node2D).position, Vector2(100, 0), 0.01, "end")
	assert_true(pickups[1] is FizzPickup, "pickup type")
	trail.shape = FizzTrail.Shape.LINE
	trail.count = 3
	var line := trail.rebuild()
	await wait_frames(1)
	assert_eq(trail.get_pickups().size(), 3, "rebuilt")
	assert_vec_almost_eq((line[1] as Node2D).position, Vector2(50, 0), 0.01, "line midpoint")


func test_memory_shard_sets_flag_commits_and_stays_hidden() -> void:
	var info := LevelInfo.new()
	info.level_id = &"kit_t"
	add_test_node(info)
	GameState.save_checkpoint("res://dummy.tscn", &"cp_a")
	var shard := kit("memory_shard", Vector2(0, -8), func(n: Node) -> void: n.index = 1) as MemoryShard
	assert_eq(shard.get_flag(), &"shard.kit_t.1", "flag name")
	capture_toasts()
	await wait_physics_frames(2)
	make_stand_in(Vector2(0, 0))
	await wait_physics_frames(3)
	assert_true(GameState.has_flag(&"shard.kit_t.1"), "flag set")
	assert_true(toasts.has("Memory shard 1/3"), "toast: %s" % [toasts])
	await wait_frames(2)
	var flags: Dictionary = GameState.checkpoint.get("flags", {})
	assert_true(bool(flags.get("shard.kit_t.1", false)), "committed to checkpoint")
	# Reload: a fresh shard with the same flag starts hidden.
	var again := kit("memory_shard", Vector2(40, -8), func(n: Node) -> void: n.index = 1) as MemoryShard
	assert_true(again.is_collected, "already collected")
	assert_false(again.visible, "hidden")
	var other := kit("memory_shard", Vector2(80, -8), func(n: Node) -> void: n.index = 2) as MemoryShard
	assert_true(other.visible, "other index still visible")
