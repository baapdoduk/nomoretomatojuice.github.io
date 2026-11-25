extends PlayerTestCase
## puzzle_lab_world.tscn with the real Player: water-level lever and parallel-world
## switch refuse changes that would trap the player and accept them otherwise.

const WORLD := "res://scenes/tests/puzzle_lab_world.tscn"

var lab: Node
var player: Player


func _load() -> void:
	await change_scene_and_wait(WORLD, &"start")
	lab = get_tree().current_scene
	player = SceneRouter.get_player() as Player
	assert_not_null(player, "player in world lab")
	player.set_input_override(input)

func _use_at(pos: Vector2) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	await wait_physics_frames(3)
	input.interact_pressed = true
	await wait_physics_frames(14)

func after_each() -> void:
	super.after_each()
	await unload_current_scene()


func test_water_lever_refused_then_accepted() -> void:
	await _load()
	capture_toasts()
	var lever := lab.get_node("SectionF/WaterLever") as StateLever
	var water1 := lab.get_node("SectionF/Water1") as StateDriven
	var sluice := lab.get_node("SectionF/Sluice") as Gate
	await wait_physics_frames(3)
	assert_eq(lever.get_value(), 0)
	# Standing inside the channel that level 1 floods.
	await _use_at(Vector2(110, 140))
	assert_eq(lever.get_value(), 0, "refused while standing in the way")
	assert_false(water1.is_enabled)
	assert_true(toasts.has(lever.blocked_message), "blocked message toast")
	# Step out of the channel and pull again.
	await _use_at(Vector2(70, 140))
	assert_eq(lever.get_value(), 1, "accepted after moving")
	assert_true(water1.is_enabled, "water level 1 collision on")
	assert_false(sluice.is_open)
	await _use_at(Vector2(70, 140))
	assert_eq(lever.get_value(), 2)
	await wait_physics_frames(3)
	assert_true(sluice.is_open, "level 2 opens the sluice")
	# The player can't walk into the flooded channel now.
	player.global_position = Vector2(70, 140)
	input.move = Vector2.RIGHT
	await wait_seconds(0.6)
	input.move = Vector2.ZERO
	assert_true(player.global_position.x <= 104.0 - 5.0, "water blocks movement (x=%.1f)" % player.global_position.x)

func test_parallel_world_switch_refused_when_blocked() -> void:
	await _load()
	capture_toasts()
	var sw := lab.get_node("SectionG/WorldSwitch") as ParallelWorldSwitch
	var layer_b := lab.get_node("SectionG/LayerB") as StateDriven
	var layer_a := lab.get_node("SectionG/LayerA") as StateDriven
	await wait_physics_frames(3)
	assert_eq(sw.get_active_layer(), 0)
	# Standing where layer B's wall is: switching to B is refused.
	await _use_at(Vector2(760, 320))
	assert_eq(sw.get_active_layer(), 0, "refused inside layer B wall")
	assert_true(toasts.has(sw.blocked_message), "refusal message")
	await _use_at(Vector2(720, 340))
	assert_eq(sw.get_active_layer(), 1, "accepted when clear")
	await wait_physics_frames(2)
	assert_true(layer_b.is_enabled and not layer_a.is_enabled, "only layer B active")
	# Reset lever returns to layer A.
	await _use_at(Vector2(680, 370))
	await wait_physics_frames(3)
	assert_eq(sw.get_active_layer(), 0, "reset to layer A")
