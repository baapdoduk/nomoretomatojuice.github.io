extends PlayerTestCase
## Player hurt / invulnerability / knockback, input locks and melee swings.


func _make_enemy_target(pos: Vector2, hp: int = 10) -> Health:
	var root := Node2D.new()
	root.position = pos
	var health := Health.new()
	health.max_health = hp
	root.add_child(health)
	var hurt := Hurtbox.new()
	hurt.collision_layer = Layers.ENEMY
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 8
	shape.shape = c
	hurt.add_child(shape)
	root.add_child(hurt)
	add_test_node(root)
	return health


func test_hurt_knockback_stun_and_invulnerability() -> void:
	var p := await make_side_player_on_floor()
	var hurts := [0]
	p.hurt.connect(func(_e: DamageEvent) -> void: hurts[0] += 1)
	var src := Node2D.new()
	src.position = Vector2(30, -10)  # attacker on the right
	add_test_node(src)
	var ev := DamageEvent.create(1, src)
	assert_true(p.hurtbox.receive_hit(ev), "hit accepted")
	assert_eq(GameState.health, 4, "GameState health reduced")
	assert_eq(hurts[0], 1)
	assert_true(p.is_stunned(), "stunned")
	assert_true(p.velocity.x < 0.0 and p.velocity.y < 0.0, "knocked away (left) and up")
	assert_false(p.hurtbox.receive_hit(DamageEvent.create(1, src)), "i-frames block second hit")
	input.move = Vector2.RIGHT
	await wait_physics_frames(3)
	assert_true(p.velocity.x < 0.0, "no control while stunned")
	await wait_seconds(p.config.hurt_stun_time)
	await wait_physics_frames(10)
	assert_true(p.velocity.x > 0.0, "control restored after stun")
	assert_true(p.health.is_invulnerable(), "still invulnerable (1 s)")
	await wait_seconds(p.config.invulnerability_time)
	assert_false(p.health.is_invulnerable(), "invulnerability ended")
	assert_true(p.hurtbox.receive_hit(DamageEvent.create(1, src)), "hittable again")
	assert_eq(GameState.health, 3)


func test_input_locks_stack() -> void:
	var p := await make_side_player_on_floor()
	p.add_input_lock(&"a")
	p.add_input_lock(&"b")
	input.move = Vector2.RIGHT
	await wait_physics_frames(10)
	assert_almost_eq(p.velocity.x, 0.0, 0.01, "locked: no movement")
	p.remove_input_lock(&"a")
	assert_true(p.is_input_locked(), "still locked by b")
	p.remove_input_lock(&"b")
	await wait_physics_frames(10)
	assert_true(p.velocity.x > 0.0, "unlocked moves")


func test_melee_hits_once_per_swing_and_follows_facing() -> void:
	var p := await make_side_player_on_floor()
	var target := _make_enemy_target(p.global_position + Vector2(-18, -10))
	var attacks: Array[Vector2] = []
	p.attacked.connect(func(d: Vector2) -> void: attacks.append(d))
	input.move = Vector2.LEFT
	await wait_physics_frames(1)
	input.move = Vector2.ZERO
	await wait_physics_frames(15)
	assert_eq(p.get_facing(), Vector2.LEFT, "facing left")
	input.attack_pressed = true
	await wait_seconds(p.config.get_attack_total_time() + 0.05)
	assert_eq(attacks.size(), 1, "one swing")
	assert_eq(attacks[0], Vector2.LEFT, "swing direction follows facing")
	assert_eq(target.current, 9, "one swing = one hit")
	input.attack_pressed = true
	await wait_seconds(p.config.get_attack_total_time() + 0.05)
	assert_eq(target.current, 8, "second swing hits again")


func test_melee_misses_behind() -> void:
	var p := await make_side_player_on_floor()
	var target := _make_enemy_target(p.global_position + Vector2(-18, -10))
	assert_eq(p.get_facing(), Vector2.RIGHT)
	input.attack_pressed = true
	await wait_seconds(p.config.get_attack_total_time() + 0.05)
	assert_eq(target.current, 10, "target behind the player is not hit")


func test_top_down_attack_eight_directions() -> void:
	var p := make_player(Player.MovementMode.TOP_DOWN, Vector2.ZERO)
	var target := _make_enemy_target(Vector2(12, 2))  # down-right of pivot (0,-10)
	await wait_physics_frames(2)
	input.move = Vector2(1, 1)
	await wait_physics_frames(1)
	input.move = Vector2.ZERO
	p.global_position = Vector2.ZERO
	await wait_physics_frames(20)
	p.global_position = Vector2.ZERO
	assert_vec_almost_eq(p.get_facing(), Vector2(1, 1).normalized(), 0.01, "diagonal facing")
	input.attack_pressed = true
	await wait_seconds(p.config.get_attack_total_time() + 0.05)
	assert_almost_eq(p.melee.rotation, PI / 4.0, 0.01, "pivot rotated diagonally")
	assert_eq(target.current, 9, "diagonal swing hits")
