extends LevelKitTestCase
## Spikes and Cork.


func test_spikes_damage_once_per_contact_with_knockback() -> void:
	var spikes := kit("spikes", Vector2(0, 0)) as Spikes
	var target := make_target(Vector2(0, 0))
	var events: Array[DamageEvent] = []
	target.hurt.connect(func(e: DamageEvent) -> void: events.append(e))
	await wait_physics_frames(4)
	assert_eq(target.health.current, 4, "one damage")
	assert_eq(events.size(), 1, "one hit")
	assert_true(events[0].knockback.y < 0.0, "knocked up: %s" % events[0].knockback)
	assert_true(events[0].has_tag(&"hazard"), "hazard tag")
	await wait_physics_frames(10)
	assert_eq(target.health.current, 4, "still in contact: no repeat")
	(target.get_parent() as Node2D).position = Vector2(100, 0)
	await wait_physics_frames(3)
	(target.get_parent() as Node2D).position = Vector2(0, 0)
	await wait_physics_frames(3)
	assert_eq(target.health.current, 3, "new contact hits again")
	assert_false(spikes.collision_layer != Layers.ENEMY_ATTACK, "enemy attack layer")


func test_cork_turns_at_ledge() -> void:
	make_block(Rect2(-100, 0, 200, 20))
	var cork := kit("cork", Vector2(60, -1), func(n: Node) -> void: n.start_direction = 1) as Cork
	assert_true(await wait_until(func() -> bool: return cork.direction == -1, 3.0), "turned at ledge")
	assert_true(cork.global_position.x < 100.0 and cork.global_position.y < 2.0, "did not fall: %s" % cork.global_position)


func test_cork_turns_at_wall() -> void:
	make_block(Rect2(-300, 0, 600, 20))
	make_block(Rect2(100, -40, 16, 40))
	var cork := kit("cork", Vector2(60, -1), func(n: Node) -> void: n.start_direction = 1) as Cork
	assert_true(await wait_until(func() -> bool: return cork.direction == -1, 3.0), "turned at wall")
	assert_true(cork.global_position.x < 100.0, "stayed left of wall")


func test_cork_contact_damage() -> void:
	make_block(Rect2(-300, 0, 600, 20))
	var cork := kit("cork", Vector2(0, -1)) as Cork
	cork.walk_speed = 0.0
	var target := make_target(Vector2(0, 0))
	target.health.invulnerability_time = 0.3
	await wait_physics_frames(4)
	assert_eq(target.health.current, 4, "contact damage (then i-frames)")
	await wait_seconds(0.4)
	assert_eq(target.health.current, 3, "repeats after i-frames while touching")


func test_cork_dies_to_sword_hitbox() -> void:
	make_block(Rect2(-300, 0, 600, 20))
	var cork := kit("cork", Vector2(0, -1)) as Cork
	cork.walk_speed = 0.0
	var defeated := [false]
	cork.defeated.connect(func() -> void: defeated[0] = true)
	var sword := Hitbox.new()
	sword.collision_layer = Layers.PLAYER_ATTACK
	sword.collision_mask = Layers.ENEMY
	sword.damage = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	sword.add_child(shape)
	sword.position = Vector2(0, -10)
	add_test_node(sword)
	await wait_physics_frames(2)
	sword.activate()
	await wait_physics_frames(3)
	assert_true(defeated[0], "defeated by sword")
	assert_true(cork.is_defeated)
	assert_false(cork.contact_hitbox.active, "no contact damage while dying")
	await wait_seconds(cork.defeat_time + 0.2)
	assert_false(is_instance_valid(cork), "freed")
