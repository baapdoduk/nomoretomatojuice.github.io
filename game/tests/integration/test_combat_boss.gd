extends "res://tests/unit/test_combat_base.gd"
## Boss state machine, vulnerability, phases, defeat persistence.

func _spec_pattern() -> AttackPattern:
	var p := make_pattern(AttackPattern.Shape.CIRCLE)
	p.origin = AttackPattern.Origin.TARGET
	p.telegraph_time = 1.6
	p.active_time = 0.25
	p.recovery_time = 3.5
	return p

func _hit(boss: Boss) -> bool:
	return boss.hurtbox.receive_hit(DamageEvent.create(1))

func test_state_order_and_timings() -> void:
	make_target(Vector2(400, 300), 99)
	var p := _spec_pattern()
	var cfg := make_boss_config([p] as Array[AttackPattern], 1.0)
	cfg.start_delay = 0.5
	var packed: PackedScene = load(BOSS_SCENE)
	var boss := packed.instantiate() as Boss
	boss.config = cfg
	var log := record(boss.state_changed)
	var attacks := record(boss.attack_started)
	add_test_node(boss)
	assert_true(boss.is_in_group(&"boss"), "group boss")
	await wait_until(func() -> bool: return log.size() >= 7, 15.0)
	var states: Array = log.map(func(e: Array) -> int: return e[0])
	var S := Boss.State
	assert_eq(states.slice(0, 7), [S.INACTIVE, S.IDLE, S.TELEGRAPH, S.ATTACK, S.RECOVERY, S.IDLE, S.TELEGRAPH], "state order")
	var d := func(a: int, b: int) -> int: return log[b][1] - log[a][1]
	assert_almost_eq(d.call(0, 1), 0.5 * 60, 1.0, "start delay")
	assert_almost_eq(d.call(1, 2), 1.0 * 60, 1.0, "idle 1.0 s")
	assert_almost_eq(d.call(2, 3), 1.6 * 60, 1.0, "telegraph 1.6 s")
	assert_almost_eq(d.call(3, 4), 0.25 * 60, 1.0, "active 0.25 s")
	assert_almost_eq(d.call(4, 5), 3.5 * 60, 1.0, "recovery 3.5 s")
	assert_eq(attacks.size(), 2, "attack_started per attack")
	assert_eq(attacks[0][0], p, "attack_started carries pattern")
	assert_eq(attacks[0][1], log[2][1], "attack_started with TELEGRAPH")

func test_invulnerable_while_attacking_damageable_in_recovery() -> void:
	make_target(Vector2(400, 300), 99)
	var cfg := make_boss_config([_spec_pattern()] as Array[AttackPattern], 0.2)
	var boss := spawn_boss(cfg)
	await wait_until(func() -> bool: return boss.state == Boss.State.IDLE, 2.0)
	assert_true(_hit(boss), "idle damageable (invulnerable_during_idle=false)")
	await wait_until(func() -> bool: return boss.state == Boss.State.TELEGRAPH, 2.0)
	assert_false(boss.is_vulnerable(), "telegraph guarded")
	assert_false(_hit(boss), "telegraph rejects damage")
	await wait_until(func() -> bool: return boss.state == Boss.State.ATTACK, 3.0)
	assert_false(_hit(boss), "attack rejects damage")
	await wait_until(func() -> bool: return boss.state == Boss.State.RECOVERY, 2.0)
	assert_true(boss.is_vulnerable(), "recovery vulnerable")
	# physical melee: a player-like Hitbox (PlayerAttack -> Enemy) lands on the boss Hurtbox
	var sword := make_player_hitbox(boss.global_position)
	await wait_physics_frames(2)
	sword.activate()
	await wait_physics_frames(3)
	assert_eq(boss.health.current, 8, "idle hit + sword hit in recovery")
	sword.deactivate()

func test_vulnerability_flags_configurable() -> void:
	make_target(Vector2(400, 300), 99)
	var cfg := make_boss_config([_spec_pattern()] as Array[AttackPattern], 0.2)
	cfg.invulnerable_during_idle = true
	cfg.invulnerable_during_telegraph = false
	cfg.invulnerable_during_attack = false
	var boss := spawn_boss(cfg)
	await wait_until(func() -> bool: return boss.state == Boss.State.IDLE, 2.0)
	assert_false(_hit(boss), "idle guarded by flag")
	await wait_until(func() -> bool: return boss.state == Boss.State.TELEGRAPH, 2.0)
	assert_true(_hit(boss), "telegraph open by flag")
	await wait_until(func() -> bool: return boss.state == Boss.State.ATTACK, 3.0)
	assert_true(_hit(boss), "attack open by flag")

func test_phase_switch_at_threshold_changes_patterns() -> void:
	make_target(Vector2(400, 300), 99)
	var a := _spec_pattern()
	a.id = &"phase0"
	var b := _spec_pattern()
	b.id = &"phase1"
	var c := _spec_pattern()
	c.id = &"phase2"
	var cfg := make_boss_config([a] as Array[AttackPattern], 0.2)
	cfg.invulnerable_during_telegraph = false
	cfg.invulnerable_during_attack = false
	for spec in [[0.5, b], [0.2, c]]:
		var ph := BossPhase.new()
		ph.health_threshold = spec[0]
		ph.patterns = [spec[1]] as Array[AttackPattern]
		ph.idle_time = 0.2
		cfg.phases.append(ph)
	var boss := spawn_boss(cfg)
	var phases := record(boss.phase_changed)
	await wait_until(func() -> bool: return boss.state == Boss.State.IDLE, 2.0)
	assert_eq(boss.phase_index, 0)
	for i in 4:
		boss.health.apply_damage(DamageEvent.create(1))
	assert_eq(boss.phase_index, 0, "60% > 50% threshold: still phase 0")
	boss.health.apply_damage(DamageEvent.create(1))
	assert_eq(boss.phase_index, 1, "50%: phase 1")
	assert_eq(phases.size(), 1)
	assert_eq(phases[0][0], 1)
	var started := record(boss.attack_started)
	await wait_until(func() -> bool: return not started.is_empty(), 8.0)
	assert_eq((started[0][0] as AttackPattern).id, &"phase1", "next attack from phase 1 list")
	boss.health.apply_damage(DamageEvent.create(3))  # 2/10 = 20% -> phase 2
	assert_eq(boss.phase_index, 2, "20%: phase 2")
	assert_eq(phases[phases.size() - 1][0], 2)

func test_random_order_with_seed_avoids_repeats() -> void:
	var list: Array[AttackPattern] = [_spec_pattern(), _spec_pattern(), _spec_pattern()]
	var cfg := make_boss_config(list, 0.0)
	cfg.phases[0].order = BossPhase.Order.RANDOM
	cfg.random_seed = 1234
	cfg.auto_start = false
	var boss := spawn_boss(cfg)
	var last: AttackPattern = null
	for i in 30:
		var pick := boss._pick_pattern()
		assert_ne(pick, last, "no immediate repeat")
		last = pick

func test_defeat_cancels_attacks_and_sets_flag() -> void:
	make_target(Vector2(400, 300), 99)
	var p := _spec_pattern()
	p.repeat_count = 3
	var cfg := make_boss_config([p] as Array[AttackPattern], 0.2)
	cfg.invulnerable_during_attack = false
	cfg.invulnerable_during_telegraph = false
	cfg.defeated_flag = &"boss.test_combat.defeated"
	var boss := spawn_boss(cfg)
	var defeated := [0]
	boss.defeated.connect(func() -> void: defeated[0] += 1)
	await wait_until(func() -> bool: return boss.state == Boss.State.TELEGRAPH, 2.0)
	await wait_physics_frames(frames(0.4))
	var spawned := boss.runner.get_spawned()
	assert_true(spawned.size() >= 2, "attacks in flight")
	boss.health.apply_damage(DamageEvent.create(99))
	await wait_frames(2)
	assert_eq(boss.state, Boss.State.DEFEATED)
	assert_eq(defeated[0], 1, "defeated emitted once")
	assert_true(GameState.has_flag(&"boss.test_combat.defeated"), "flag set")
	assert_false(boss.runner.is_running, "runner stopped")
	for n in spawned:
		assert_false(is_instance_valid(n), "spawned attack cleared")
	assert_false(boss.hurtbox.enabled, "hurtbox disabled")
	await wait_physics_frames(frames(4.0))
	assert_eq(boss.state, Boss.State.DEFEATED, "stays defeated")
	assert_eq(boss.runner.get_child_count(), 0, "no new attacks")

func test_already_defeated_on_load() -> void:
	GameState.set_flag(&"boss.loaded.defeated", true)
	var cfg := make_boss_config([_spec_pattern()] as Array[AttackPattern])
	cfg.defeated_flag = &"boss.loaded.defeated"
	cfg.already_defeated = BossConfig.AlreadyDefeated.REMOVE
	var removed := spawn_boss(cfg)
	assert_true(removed.was_defeated_on_load)
	assert_true(removed.is_queued_for_deletion(), "REMOVE frees the boss")
	var cfg2 := make_boss_config([_spec_pattern()] as Array[AttackPattern])
	cfg2.defeated_flag = &"boss.loaded.defeated"
	cfg2.already_defeated = BossConfig.AlreadyDefeated.START_DEFEATED
	var kept := spawn_boss(cfg2)
	var defeated := [0]
	kept.defeated.connect(func() -> void: defeated[0] += 1)
	await wait_physics_frames(frames(2.0))
	assert_eq(kept.state, Boss.State.DEFEATED, "starts defeated")
	assert_eq(kept.runner.get_child_count(), 0, "never attacks")
	assert_eq(defeated[0], 0, "no defeated signal on load")

func test_defeat_behavior_free() -> void:
	var cfg := make_boss_config([_spec_pattern()] as Array[AttackPattern])
	cfg.defeat_behavior = BossConfig.DefeatBehavior.FREE
	cfg.defeat_remove_delay = 0.5
	var boss := spawn_boss(cfg)
	await wait_physics_frames(2)
	boss.health.apply_damage(DamageEvent.create(99))
	await wait_physics_frames(frames(0.3))
	assert_true(is_instance_valid(boss) and boss.visible, "visible during defeat delay")
	await wait_physics_frames(frames(0.4))
	assert_false(is_instance_valid(boss), "freed after delay")

func test_manual_start_and_inactive_invulnerable() -> void:
	var cfg := make_boss_config([_spec_pattern()] as Array[AttackPattern])
	cfg.auto_start = false
	var boss := spawn_boss(cfg)
	await wait_physics_frames(frames(1.0))
	assert_eq(boss.state, Boss.State.INACTIVE, "waits for start_fight")
	assert_false(_hit(boss), "inactive guarded")
	var bar := boss.get_node("HealthBarLayer/HealthBar") as BossHealthBar
	assert_false(bar.visible, "bar hidden before fight")
	boss.start_fight()
	await wait_physics_frames(2)
	assert_eq(boss.state, Boss.State.IDLE)
	assert_true(bar.visible, "bar shown in fight")
	boss.health.apply_damage(DamageEvent.create(3))
	assert_almost_eq(bar.displayed_ratio, 0.7, 0.001, "bar follows health")

func test_contact_damage() -> void:
	var target := make_target(Vector2(110, 100), 99)
	var cfg := make_boss_config([_spec_pattern()] as Array[AttackPattern], 5.0)
	cfg.contact_damage = 1
	cfg.contact_interval = 0.5
	spawn_boss(cfg, Vector2(100, 100))
	await wait_physics_frames(frames(0.25))
	assert_eq(target_health(target).current, 98, "contact hit")
	await wait_physics_frames(frames(0.5))
	assert_eq(target_health(target).current, 97, "re-hit after contact_interval")

func test_shipped_boss_configs_valid() -> void:
	for path in ["res://resources/combat/test_boss.tres", "res://resources/combat/mogu_bottle_prototype.tres"]:
		var cfg: BossConfig = load(path)
		assert_not_null(cfg, path)
		assert_true(cfg.phases.size() >= 1, "phases " + path)
		var last := 2.0
		for ph in cfg.phases:
			assert_true(ph.health_threshold < last, "descending thresholds " + path)
			last = ph.health_threshold
			assert_true(ph.patterns.size() > 0, "patterns " + path)
			for p in ph.patterns:
				assert_not_null(p, "pattern " + path)
				assert_true(p.telegraph_time >= 1.5 and p.telegraph_time <= 2.0, "spec telegraph " + String(p.id))
				assert_true(p.recovery_time >= 3.0 and p.recovery_time <= 4.0, "spec recovery " + String(p.id))
		assert_ne(cfg.defeated_flag, &"", "defeated flag " + path)
	var test_boss: BossConfig = load("res://resources/combat/test_boss.tres")
	assert_true(test_boss.phases.size() > 1, "test boss is multi-phase")

func test_boss_scenes_instantiate_and_fight() -> void:
	make_target(Vector2(300, 200), 99)
	for path in [BOSS_SCENE, "res://scenes/combat/mogu_bottle_boss.tscn"]:
		var boss := instantiate_scene(path) as Boss
		assert_not_null(boss, path)
		await wait_until(func() -> bool: return boss.state == Boss.State.RECOVERY, 10.0)
		assert_eq(boss.state, Boss.State.RECOVERY, "reaches recovery " + path)
		boss.queue_free()
		await wait_frames(1)
	var mogu := instantiate_scene("res://scenes/combat/mogu_bottle_boss.tscn") as Boss
	assert_eq((mogu.get_node("Visual") as BossVisual).style, BossVisual.Style.BOTTLE, "bottle visual")
	assert_eq(mogu.config.id, &"mogu_bottle")

func test_arena_trigger_starts_fight() -> void:
	var arena := instantiate_scene("res://scenes/combat/boss_arena.tscn") as Node2D
	var boss := arena.get_node("Boss") as Boss
	var trigger := arena.get_node("FightTrigger") as BossFightTrigger
	var target := make_target(Vector2(320, 340), 99)
	await wait_physics_frames(frames(1.0))
	assert_eq(boss.state, Boss.State.INACTIVE, "waits for trigger (wait_for_trigger)")
	target.global_position = trigger.global_position
	await wait_physics_frames(3)
	assert_true(trigger.has_triggered, "player hurtbox entered trigger")
	assert_true(boss.is_fight_active())
	await wait_until(func() -> bool: return boss.state == Boss.State.IDLE, 2.0)
	assert_eq(boss.state, Boss.State.IDLE, "fight started")

func test_lethal_hit_skips_phase_switch() -> void:
	var a := _spec_pattern()
	var cfg := make_boss_config([a] as Array[AttackPattern], 0.5)
	var ph := BossPhase.new()
	ph.health_threshold = 0.5
	ph.patterns = [_spec_pattern()] as Array[AttackPattern]
	ph.interrupt_current_attack = true
	cfg.phases.append(ph)
	var boss := spawn_boss(cfg)
	var phases := record(boss.phase_changed)
	var states := record(boss.state_changed)
	await wait_until(func() -> bool: return boss.state == Boss.State.IDLE, 2.0)
	boss.health.apply_damage(DamageEvent.create(99))
	assert_eq(phases.size(), 0, "no phase_changed on the lethal hit")
	assert_eq(boss.phase_index, 0)
	var seen: Array = states.map(func(e: Array) -> int: return e[0])
	assert_eq(seen, [Boss.State.DEFEATED], "IDLE -> DEFEATED directly (no interrupt / extra IDLE)")
