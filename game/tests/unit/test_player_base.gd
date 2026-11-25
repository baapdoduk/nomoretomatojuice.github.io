class_name PlayerTestCase
extends TestCase
## Shared helpers for player / exploration tests (no test_ methods here, so the
## runner skips this file). Builds tiny levels in code.

const PLAYER_SCENE := "res://scenes/core/player/player.tscn"

var input := PlayerInputState.new()


func before_each() -> void:
	GameState.new_game(5)
	input = PlayerInputState.new()


## Static box on the World layer. `rect` is in global coordinates.
func make_block(rect: Rect2, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.one_way_collision = one_way
	body.add_child(shape)
	if one_way:
		body.add_to_group(SideViewMotor.ONE_WAY_GROUP)
	add_test_node(body)
	return body


## Instantiates the player scene (camera off, scripted input) at `pos`.
func make_player(mode: Player.MovementMode, pos: Vector2, config: PlayerConfig = null) -> Player:
	var packed: PackedScene = load(PLAYER_SCENE)
	var p: Player = packed.instantiate()
	p.movement_mode = mode
	p.use_camera = false
	if config:
		p.config = config
	p.position = pos
	p.set_input_override(input)
	add_test_node(p)
	return p


## Puts a player on a wide floor (top of floor at y=0) and lets it settle.
func make_side_player_on_floor(x: float = 0.0, config: PlayerConfig = null) -> Player:
	make_block(Rect2(-2000, 0, 4000, 40))
	var p := make_player(Player.MovementMode.SIDE_VIEW, Vector2(x, -1), config)
	await wait_physics_frames(3)
	# Lower retuned gravity: the 1 px drop can take a few more frames.
	await wait_until(func() -> bool: return p.is_on_floor(), 1.0)
	return p


## Replaces the current (lab) scene with an empty placeholder so a loaded
## level's player cannot react to later tests, and clears respawn snapshots.
func unload_current_scene() -> void:
	var tree := get_tree()
	var old := tree.current_scene
	if old == null or old.name == "TestPlaceholderScene" and old.get_child_count() == 0:
		return
	var placeholder := Node.new()
	placeholder.name = "TestPlaceholderScene"
	tree.root.add_child(placeholder)
	tree.current_scene = placeholder
	old.queue_free()
	await tree.process_frame
	GameState.new_game(5)


## Waits for the running SceneRouter transition (if any) to finish.
func wait_transition(timeout: float = 5.0) -> bool:
	await wait_physics_frames(1)
	return await wait_until(func() -> bool: return not SceneRouter.is_transitioning, timeout)


var toasts: Array[String] = []

## Starts collecting GameState toasts into `toasts` (disconnected in after_each).
func capture_toasts() -> void:
	toasts.clear()
	if not GameState.notification_requested.is_connected(_on_toast):
		GameState.notification_requested.connect(_on_toast)

func _on_toast(text: String, _duration: float) -> void:
	toasts.append(text)

func after_each() -> void:
	if GameState.notification_requested.is_connected(_on_toast):
		GameState.notification_requested.disconnect(_on_toast)


func make_interactable_at(pos: Vector2, radius: float = 6.0) -> Interactable:
	var it := Interactable.new()
	it.position = pos
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	it.add_child(shape)
	add_test_node(it)
	return it


func find_popup(root: Node) -> InfoPopup:
	for c in root.get_children():
		if c is InfoPopup:
			return c
	return null


func press_jump() -> void:
	input.jump_pressed = true
	input.jump_held = true


func release_jump() -> void:
	input.jump_held = false


func press_dash() -> void:
	input.dash_pressed = true


## Disables hit-stop / screen shake for tests that need exact timing.
## Undo with restore_feel_settings() (GameState.new_game keeps settings).
func disable_feel_settings() -> void:
	GameState.set_setting(&"hit_stop", false)
	GameState.set_setting(&"screen_shake", false)


func restore_feel_settings() -> void:
	GameState.settings.erase(&"hit_stop")
	GameState.settings.erase(&"screen_shake")
	HitStop.stop()
