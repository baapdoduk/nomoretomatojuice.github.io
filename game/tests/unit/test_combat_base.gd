extends TestCase
## Shared helpers for module B combat tests (no test_ methods here; other
## combat test files extend this script).

const BOSS_SCENE := "res://scenes/combat/boss.tscn"


func before_each() -> void:
	GameState.new_game(5)
	GameState.set_setting(&"assist_combat_timing", false)

func after_each() -> void:
	GameState.set_setting(&"assist_combat_timing", false)


## Stand-in player: Node2D in group "player" with a local Health and a Hurtbox on layer PLAYER.
func make_target(pos: Vector2, max_hp: int = 5, radius: float = 8.0) -> Node2D:
	var root := Node2D.new()
	root.name = "StandInPlayer"
	root.position = pos
	root.add_to_group(Layers.GROUP_PLAYER)
	var health := Health.new()
	health.name = "Health"
	health.max_health = max_hp
	root.add_child(health)
	var hurt := Hurtbox.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = Layers.PLAYER
	hurt.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	hurt.add_child(shape)
	root.add_child(hurt)
	add_test_node(root)
	return root

func target_health(target: Node) -> Health:
	return target.get_node("Health") as Health

func make_runner(pos: Vector2) -> AttackRunner:
	var runner := AttackRunner.new()
	runner.position = pos
	add_test_node(runner)
	return runner

func make_pattern(shape: AttackPattern.Shape = AttackPattern.Shape.CIRCLE) -> AttackPattern:
	var p := AttackPattern.new()
	p.shape = shape
	p.radius = 30.0
	p.telegraph_time = 0.5
	p.active_time = 0.5
	p.recovery_time = 0.5
	p.knockback = 0.0
	return p

## Player-like melee hitbox (layer PLAYER_ATTACK, mask ENEMY), rect of `size`.
func make_player_hitbox(pos: Vector2, size: Vector2 = Vector2(40, 40)) -> Hitbox:
	var hb := Hitbox.new()
	hb.position = pos
	hb.collision_layer = Layers.PLAYER_ATTACK
	hb.collision_mask = Layers.ENEMY
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	hb.add_child(shape)
	add_test_node(hb)
	return hb

## Short single-phase boss config for deterministic tests.
func make_boss_config(patterns: Array[AttackPattern], idle: float = 1.0) -> BossConfig:
	var c := BossConfig.new()
	c.id = &"test"
	c.max_health = 10
	c.start_delay = 0.0
	c.contact_damage = 0
	var ph := BossPhase.new()
	ph.health_threshold = 1.0
	ph.patterns = patterns
	ph.idle_time = idle
	var phases: Array[BossPhase] = [ph]
	c.phases = phases
	return c

func spawn_boss(config: BossConfig, pos: Vector2 = Vector2(100, 100)) -> Boss:
	var packed: PackedScene = load(BOSS_SCENE)
	var boss := packed.instantiate() as Boss
	boss.config = config
	boss.position = pos
	add_test_node(boss)
	return boss

## Records [value, physics_frame] for every emission of a 1-arg signal.
func record(sig: Signal) -> Array:
	var log: Array = []
	sig.connect(func(v: Variant) -> void: log.append([v, Engine.get_physics_frames()]))
	return log

func frames(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)
