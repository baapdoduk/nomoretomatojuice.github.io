extends PlayerTestCase
## Scripted traversal of the side-view lab: checks that the authored geometry
## is actually beatable with the default PlayerConfig (full-jump ledge,
## dash gap, locked door with key).

const SIDE := "res://scenes/tests/side_view_lab.tscn"


func after_each() -> void:
	super.after_each()
	await unload_current_scene()


func _setup() -> Player:
	await change_scene_and_wait(SIDE, &"start")
	var p := SceneRouter.get_player() as Player
	p.set_input_override(input)
	return p


func _place(p: Player, pos: Vector2) -> void:
	p.global_position = pos
	p.velocity = Vector2.ZERO
	await wait_physics_frames(4)


func test_full_jump_ledge_needs_full_jump() -> void:
	var p: Player = await _setup()
	# FullJumpLedge: x 800..848, top at y = -64. Short hop must fail, full jump succeeds.
	await _place(p, Vector2(770, 0))
	input.move = Vector2.RIGHT
	press_jump()
	await wait_physics_frames(2)
	release_jump()
	await wait_physics_frames(40)
	assert_true(p.global_position.x < 800.0, "short hop bonks into the 64 px ledge")
	input.move = Vector2.ZERO
	await _place(p, Vector2(770, 0))
	input.move = Vector2.RIGHT
	press_jump()
	var landed_on_top := await wait_until(func() -> bool:
		return p.is_on_floor() and p.global_position.y < -60.0, 1.5)
	release_jump()
	input.move = Vector2.ZERO
	assert_true(landed_on_top, "reached the top of the ledge")
	await wait_physics_frames(20)
	assert_almost_eq(p.global_position.y, -64.0, 1.0, "full jump lands on the ledge")


func test_dash_gap_needs_jump_plus_dash() -> void:
	var p: Player = await _setup()
	# Dash gap: FloorMid ends at x=1000, FloorEnd starts at x=1160.
	await _place(p, Vector2(930, 0))
	input.move = Vector2.RIGHT
	assert_true(await wait_until(func() -> bool: return p.global_position.x >= 994.0, 2.0))
	press_jump()
	await wait_physics_frames(20)  # near the apex
	press_dash()
	await wait_physics_frames(60)
	release_jump()
	assert_false(p.is_dead(), "did not fall into the pit")
	assert_true(p.global_position.x > 1160.0 and absf(p.global_position.y) < 1.0,
		"landed on the far side (%s)" % str(p.global_position))


func test_locked_door_blocks_until_key() -> void:
	var p: Player = await _setup()
	await _place(p, Vector2(1780, 0))
	input.move = Vector2.RIGHT
	await wait_physics_frames(40)
	assert_true(p.global_position.x < 1817.0, "blocked by locked door (x=%.1f)" % p.global_position.x)
	press_jump()
	await wait_physics_frames(50)
	release_jump()
	assert_true(p.global_position.x < 1817.0, "cannot jump over (lintel)")
	input.move = Vector2.ZERO
	GameState.add_item(load("res://resources/items/lab_key.tres"))
	await wait_physics_frames(3)
	var door := get_tree().current_scene.get_node(^"Interactables/LockedDoor") as LockedDoor
	assert_eq(p.interactor.target, door, "door focused")
	input.interact_pressed = true
	await wait_physics_frames(5)
	assert_true(door.is_open(), "unlocked with key")
	input.move = Vector2.RIGHT
	await wait_physics_frames(30)
	assert_true(p.global_position.x > 1840.0, "walked through (x=%.1f)" % p.global_position.x)
