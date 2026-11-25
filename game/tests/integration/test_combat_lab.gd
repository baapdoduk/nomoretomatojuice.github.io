extends PlayerTestCase
## Combat lab with the real Player (scripted input / teleports).

const LAB := "res://scenes/tests/combat_lab.tscn"
const BOSS_FLAG := &"boss.test_boss.defeated"

var lab: Node
var player: Player
var boss: Boss


func before_each() -> void:
	super.before_each()
	GameState.set_setting(&"assist_combat_timing", false)
	await _load_lab()

func after_each() -> void:
	super.after_each()
	await unload_current_scene()


func _load_lab() -> void:
	await change_scene_and_wait(LAB, &"start")
	lab = get_tree().current_scene
	player = SceneRouter.get_player() as Player
	input = PlayerInputState.new()
	player.set_input_override(input)
	boss = lab.get_node_or_null(^"Arena/Boss") as Boss

func _teleport(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	await wait_physics_frames(2)

## Stands south of the boss, facing it, close enough for the sword (not for contact damage).
func _stand_under_boss() -> void:
	await _teleport(boss.global_position + Vector2(0, 46))
	player.set_facing(Vector2.UP)

func _swing() -> void:
	input.attack_pressed = true
	await wait_physics_frames(frames(0.35))

func frames(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


func test_lab_layout() -> void:
	assert_eq(lab.scene_file_path, LAB)
	assert_eq(player.movement_mode, Player.MovementMode.TOP_DOWN, "top-down player")
	assert_vec_almost_eq(player.global_position, Vector2(120, 620), 1.0, "at start spawn")
	assert_not_null(boss, "arena boss")
	assert_eq(boss.state, Boss.State.INACTIVE, "boss waits for the arena trigger")
	assert_not_null(get_tree().get_first_node_in_group(&"hud"), "HUD present")
	var gate := lab.get_node("ExitGate") as Gate
	await wait_physics_frames(2)
	assert_false(gate.is_open, "exit closed before victory")
	var door := lab.get_node("Interactables/DoorHub") as SceneDoor
	assert_eq(door.target_scene, "res://scenes/tests/test_hub.tscn", "victory door leads to hub")

func test_melee_hits_boss_only_in_recovery() -> void:
	player.health.set_invulnerable_flag(&"test", true)
	boss.start_fight()
	await _stand_under_boss()
	await wait_until(func() -> bool: return boss.state == Boss.State.TELEGRAPH, 5.0)
	var hp := boss.health.current
	await _swing()
	assert_eq(boss.health.current, hp, "guarded during telegraph: no damage")
	await wait_until(func() -> bool: return boss.state == Boss.State.ATTACK, 3.0)
	await _stand_under_boss()
	await _swing()
	assert_eq(boss.health.current, hp, "guarded during attack: no damage")
	await wait_until(func() -> bool: return boss.state == Boss.State.RECOVERY, 3.0)
	await _stand_under_boss()
	await _swing()
	assert_eq(boss.health.current, hp - 1, "sword hits in recovery (1 damage)")
	await _swing()
	assert_eq(boss.health.current, hp - 2, "each swing hits once")

func test_walk_into_arena_starts_fight_and_attack_hurts_player() -> void:
	await _teleport(Vector2(440, 370))
	await wait_physics_frames(3)
	assert_eq(String(GameState.checkpoint.get("spawn_id", "")), "cp_pre_boss", "pre-boss checkpoint saved")
	input.move = Vector2.RIGHT
	var trigger := lab.get_node("Arena/FightTrigger") as BossFightTrigger
	assert_true(await wait_until(func() -> bool: return trigger.has_triggered, 3.0), "walked into trigger")
	input.move = Vector2.ZERO
	assert_true(boss.is_fight_active(), "fight started by the player")
	var hits: Array = []
	var b := boss
	var on_hp := func(h: int, _m: int) -> void: hits.append([h, b.state if is_instance_valid(b) else -1])
	GameState.health_changed.connect(on_hp)
	await wait_until(func() -> bool: return boss.state == Boss.State.RECOVERY, 8.0)
	GameState.health_changed.disconnect(on_hp)
	assert_eq(GameState.health, 4, "first circle drop on the standing player: 5 -> 4")
	assert_eq(hits.size(), 1, "exactly one hit")
	assert_eq(hits[0][1], Boss.State.ATTACK, "damage happened in the ATTACK stage")

func test_death_in_arena_respawns_at_checkpoint_with_boss_reset() -> void:
	await _teleport(Vector2(440, 370))
	boss.start_fight()
	await wait_until(func() -> bool: return boss.state == Boss.State.IDLE, 3.0)
	boss.health.apply_damage(DamageEvent.create(3))
	assert_eq(boss.health.current, 9)
	GameState.apply_damage(4)
	await _teleport(boss.global_position + Vector2(0, 120))
	var old_id := lab.get_instance_id()
	var tree := get_tree()
	assert_true(await wait_until(func() -> bool: return player.is_dead(), 8.0), "boss attack killed the player")
	assert_true(await wait_until(func() -> bool: return tree.current_scene != null and tree.current_scene.get_instance_id() != old_id and not SceneRouter.is_transitioning, 8.0), "respawned")
	lab = get_tree().current_scene
	player = SceneRouter.get_player() as Player
	boss = lab.get_node("Arena/Boss") as Boss
	assert_eq(lab.scene_file_path, LAB)
	assert_vec_almost_eq(player.global_position, Vector2(440, 380), 1.0, "at pre-boss checkpoint")
	assert_eq(GameState.health, 5, "full health")
	assert_false(GameState.has_flag(BOSS_FLAG), "boss not defeated")
	assert_eq(boss.state, Boss.State.INACTIVE, "boss reset, waiting for trigger")
	assert_eq(boss.health.current, 12, "boss health reset")

func test_victory_opens_exit_and_persists() -> void:
	player.health.set_invulnerable_flag(&"test", true)
	boss.start_fight()
	await wait_until(func() -> bool: return boss.state == Boss.State.IDLE, 3.0)
	boss.health.apply_damage(DamageEvent.create(boss.health.current - 1))
	await wait_until(func() -> bool: return boss.state == Boss.State.RECOVERY, 10.0)
	await _stand_under_boss()
	await _swing()
	assert_eq(boss.state, Boss.State.DEFEATED, "sword finished the boss")
	assert_true(GameState.has_flag(BOSS_FLAG), "defeated flag set")
	var gate := lab.get_node("ExitGate") as Gate
	await wait_physics_frames(2)
	assert_true(gate.is_open, "exit gate opened")
	player.health.set_invulnerable_flag(&"test", false)
	await _teleport(Vector2(1080, 370))
	input.move = Vector2.RIGHT
	await wait_physics_frames(frames(0.6))
	input.move = Vector2.ZERO
	assert_true(player.global_position.x > 1140, "walked through the exit (x=%.0f)" % player.global_position.x)
	await change_scene_and_wait("res://scenes/tests/test_hub.tscn")
	await _load_lab()
	await wait_physics_frames(2)
	assert_null(lab.get_node_or_null(^"Arena/Boss"), "boss stays defeated (removed on load)")
	assert_true((lab.get_node("ExitGate") as Gate).is_open, "exit open on re-entry")

func test_dash_iframes_ignore_active_area() -> void:
	var p := AttackPattern.new()
	p.shape = AttackPattern.Shape.LINE
	p.line_length = 60.0
	p.line_width = 20.0
	p.origin = AttackPattern.Origin.SELF
	p.aim = AttackPattern.Aim.FIXED_ANGLE
	p.fixed_angle_degrees = 90.0
	p.telegraph_time = 0.0
	p.active_time = 3.0
	p.knockback = 0.0
	var runner := AttackRunner.new()
	runner.position = Vector2(200, 580)  # vertical strip x 190..210, y 580..640
	lab.add_child(runner)
	runner.run(p)
	await _teleport(Vector2(178, 620))
	input.move = Vector2.RIGHT
	input.dash_pressed = true
	await wait_physics_frames(frames(0.3))
	input.move = Vector2.ZERO
	assert_true(player.global_position.x > 230, "dashed through (x=%.0f)" % player.global_position.x)
	assert_eq(GameState.health, 5, "no damage while dashing through the active area")
	# control: walking through the same active area hurts
	await _teleport(Vector2(250, 620))
	input.move = Vector2.LEFT
	await wait_physics_frames(frames(0.4))
	input.move = Vector2.ZERO
	assert_eq(GameState.health, 4, "walking through the active area takes 1 damage")
	runner.cancel()
