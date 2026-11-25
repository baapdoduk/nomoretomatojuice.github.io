extends "res://tests/unit/test_combat_base.gd"
## Projectile: hits once, frees on hit / lifetime / off-screen / World.

func _spawn(pos: Vector2, velocity: Vector2, lifetime: float = 2.0) -> Projectile:
	var p := Projectile.new()
	p.configure(velocity, 1, 0.0, lifetime, 5.0, null)
	p.position = pos
	add_test_node(p)
	return p

func _reasons(p: Projectile) -> Array:
	var out: Array = []
	p.despawned.connect(func(r: StringName) -> void: out.append(r))
	return out

func test_projectile_hits_once_and_frees() -> void:
	var target := make_target(Vector2(160, 100))
	var health := target_health(target)
	var p := _spawn(Vector2(100, 100), Vector2(240, 0))
	var reasons := _reasons(p)
	assert_eq(p.collision_layer, Layers.ENEMY_ATTACK, "layer")
	assert_eq(p.collision_mask, Layers.PLAYER | Layers.WORLD, "mask")
	await wait_physics_frames(frames(0.5))
	assert_eq(health.current, 4, "one hit")
	assert_eq(reasons, [&"hit"], "despawned on hit")
	assert_false(is_instance_valid(p), "freed")
	await wait_physics_frames(10)
	assert_eq(health.current, 4, "no further damage")

func test_projectile_lifetime() -> void:
	var p := _spawn(Vector2(0, 0), Vector2(10, 0), 0.5)
	var reasons := _reasons(p)
	var start := Engine.get_physics_frames()
	var end := [-1]
	p.despawned.connect(func(_r: StringName) -> void: end[0] = Engine.get_physics_frames())
	await wait_physics_frames(frames(0.5) - 3)
	assert_true(is_instance_valid(p), "alive before lifetime")
	await wait_physics_frames(6)
	assert_eq(reasons, [&"lifetime"])
	assert_almost_eq(end[0] - start, frames(0.5), 1.0, "removed at lifetime")
	assert_false(is_instance_valid(p), "freed")

func test_projectile_moves_at_velocity() -> void:
	var p := _spawn(Vector2(0, 0), Vector2(120, 0), 5.0)
	await wait_physics_frames(1)
	var x0 := p.global_position.x
	await wait_physics_frames(60)
	assert_almost_eq(p.global_position.x - x0, 120.0, 2.5, "120 px in 1 s")
	assert_almost_eq(p.rotation, 0.0, 0.0001, "faces travel direction")

func test_projectile_offscreen_notifier_frees() -> void:
	# Headless rendering never fires the notifier, so emit its signal to verify the wiring.
	var p := _spawn(Vector2(0, 0), Vector2(10, 0), 5.0)
	var reasons := _reasons(p)
	var notifier := p.get_node("ScreenNotifier") as VisibleOnScreenNotifier2D
	assert_not_null(notifier, "has VisibleOnScreenNotifier2D")
	notifier.screen_exited.emit()
	await wait_frames(2)
	assert_eq(reasons, [&"offscreen"])
	assert_false(is_instance_valid(p), "freed off-screen")

func test_projectile_destroyed_by_world() -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = Layers.WORLD
	wall.position = Vector2(150, 100)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 100)
	shape.shape = rect
	wall.add_child(shape)
	add_test_node(wall)
	var p := _spawn(Vector2(100, 100), Vector2(200, 0))
	var reasons := _reasons(p)
	await wait_physics_frames(frames(0.6))
	assert_eq(reasons, [&"world"])
	assert_false(is_instance_valid(p), "freed by World")

func test_projectile_scene_loads() -> void:
	var p := instantiate_scene("res://scenes/combat/projectile.tscn") as Projectile
	assert_not_null(p, "projectile scene root is a Projectile")
	p.despawn(&"cancelled")
