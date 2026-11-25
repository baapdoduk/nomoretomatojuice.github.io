extends "res://tests/unit/test_combat_base.gd"
## HitFeedback hooks and TrainingDummy.

func test_hit_feedback_flashes_on_damage_and_restores() -> void:
	var health := Health.new()
	health.max_health = 3
	add_test_node(health)
	var vis := Polygon2D.new()
	vis.modulate = Color(0.5, 0.6, 0.7)
	add_test_node(vis)
	var fb := HitFeedback.new()
	fb.health = health
	fb.flash_target = vis
	fb.flash_time = 0.2
	fb.flash_color = Color(3, 3, 3)
	fb.hurt_rumble = &"player_hurt"  # no joypad in headless: silent no-op
	var player := AudioStreamPlayer.new()
	add_test_node(player)
	fb.hurt_sound = player  # no stream assigned: skipped silently
	add_test_node(fb)
	var kinds: Array = []
	fb.feedback_played.connect(func(k: StringName) -> void: kinds.append(k))
	health.apply_damage(DamageEvent.create(1))
	assert_eq(kinds, [&"hurt"])
	assert_true(fb.is_flashing, "flashing")
	assert_eq(vis.modulate, Color(3, 3, 3), "flash colour applied")
	await wait_seconds(0.3)
	assert_false(fb.is_flashing, "flash ended")
	assert_eq(vis.modulate, Color(0.5, 0.6, 0.7), "modulate restored")

func test_hit_feedback_confirm_on_hitbox() -> void:
	var target := make_target(Vector2(100, 100))
	var hb := Hitbox.new()
	hb.position = Vector2(100, 100)
	hb.collision_layer = Layers.ENEMY_ATTACK
	hb.collision_mask = Layers.PLAYER
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10
	shape.shape = c
	hb.add_child(shape)
	add_test_node(hb)
	var fb := HitFeedback.new()
	fb.hitbox = hb
	fb.confirm_rumble = &"hit_confirm"
	add_test_node(fb)
	var kinds: Array = []
	fb.feedback_played.connect(func(k: StringName) -> void: kinds.append(k))
	await wait_physics_frames(2)
	hb.activate()
	await wait_physics_frames(3)
	assert_eq(kinds, [&"confirm"], "confirm once")
	assert_eq(target_health(target).current, 4)

func test_training_dummy_counts_and_resets() -> void:
	var dummy := instantiate_scene("res://scenes/combat/training_dummy.tscn") as TrainingDummy
	dummy.position = Vector2(200, 200)
	dummy.reset_delay = 1.0
	var sword := make_player_hitbox(Vector2(200, 200))
	sword.damage = 2
	await wait_physics_frames(2)
	sword.activate()
	await wait_physics_frames(2)
	sword.deactivate()
	sword.activate()
	await wait_physics_frames(2)
	sword.deactivate()
	assert_eq(dummy.hit_count, 2, "two activations, two hits")
	assert_eq(dummy.total_damage, 4)
	assert_eq(dummy.health.current, dummy.health.max_health - 4)
	assert_true(dummy.stats_label.text.contains("dmg 4"), "label shows damage")
	var resets := [0]
	dummy.reset_done.connect(func() -> void: resets[0] += 1)
	await wait_physics_frames(frames(0.9))
	assert_eq(resets[0], 0, "not yet reset")
	await wait_physics_frames(frames(0.2))
	assert_eq(resets[0], 1, "auto reset after reset_delay")
	assert_eq(dummy.total_damage, 0)
	assert_eq(dummy.health.current, dummy.health.max_health, "health refilled")

func test_training_dummy_resets_after_death() -> void:
	var dummy := instantiate_scene("res://scenes/combat/training_dummy.tscn") as TrainingDummy
	await wait_physics_frames(1)
	dummy.health.apply_damage(DamageEvent.create(999))
	assert_true(dummy.health.is_dead)
	await wait_physics_frames(frames(dummy.death_reset_delay) + 2)
	assert_false(dummy.health.is_dead, "revived")
	assert_eq(dummy.health.current, dummy.health.max_health)

func test_dummy_ignores_enemy_attacks_layering() -> void:
	var dummy := instantiate_scene("res://scenes/combat/training_dummy.tscn") as TrainingDummy
	assert_eq(dummy.hurtbox.collision_layer, Layers.ENEMY, "dummy hurtbox on Enemy layer")
	assert_eq(dummy.collision_layer, Layers.ENEMY, "dummy body on Enemy layer")
	var runner := make_runner(Vector2.ZERO)
	runner.target = dummy
	var p := make_pattern()
	p.telegraph_time = 0.0
	p.origin = AttackPattern.Origin.TARGET
	runner.run(p)
	await wait_physics_frames(10)
	assert_eq(dummy.hit_count, 0, "EnemyAttack does not hit Enemy layer")
