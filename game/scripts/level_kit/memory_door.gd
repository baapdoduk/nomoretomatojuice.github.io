class_name MemoryDoor
extends Area2D
## Level goal. When the player reaches it: input lock, short celebration (door
## opens, light spills out), milestone "level.<level_id>.clear" (committed),
## toast, then SceneRouter.change_scene(next_scene) or, when empty, go_to_hub().
## level_id comes from the export or the scene's LevelInfo.
## Layer: none, mask: Player. Origin = bottom centre of the door.
## Visuals: swappable `Visual` child (placeholder: DoorVisual) reading
## `open_amount` (0 closed .. 1 open, rises after the trigger).

signal reached
signal finished

const LOCK_REASON := &"memory_door"

@export var level_id: StringName = &""
## Scene to load after the celebration; empty = SceneRouter.go_to_hub().
@export_file("*.tscn") var next_scene: String = ""
@export var next_spawn_id: StringName = &""
@export var celebration_time: float = 1.2
@export var toast_text: String = "Memory restored"
## Seconds for the door to open fully (visual only).
@export var open_time: float = 0.4

var is_triggered: bool = false
var open_amount: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitoring = true
	monitorable = false
	KitUtil.ensure_rect_shape(self, Vector2(16, 30), Vector2(0, -15))
	body_entered.connect(_on_body_entered)


func get_level_id() -> StringName:
	if level_id != &"":
		return level_id
	var info := LevelInfo.find_in(get_tree())
	return info.level_id if info else &"level"


func get_clear_flag() -> StringName:
	return LevelInfo.make_clear_flag(get_level_id())


func _on_body_entered(body: Node2D) -> void:
	if KitUtil.is_live_player(body):
		trigger(body)


## Runs the goal sequence once. `player` may be null (scripted clear).
func trigger(player: Node = null) -> void:
	if is_triggered:
		return
	is_triggered = true
	if player:
		if player.has_method(&"add_input_lock"):
			player.call(&"add_input_lock", LOCK_REASON)
		if &"velocity" in player:
			player.set(&"velocity", Vector2.ZERO)
	GameState.set_milestone(get_clear_flag(), true)
	if toast_text != "":
		GameState.notify(toast_text, maxf(celebration_time + 0.5, 1.5))
	reached.emit()
	if celebration_time > 0.0:
		await get_tree().create_timer(celebration_time, false).timeout
	if not is_inside_tree():
		return
	finished.emit()
	if next_scene != "":
		SceneRouter.change_scene(next_scene, next_spawn_id)
	else:
		SceneRouter.go_to_hub()


func _process(delta: float) -> void:
	if is_triggered:
		open_amount = minf(1.0, open_amount + delta / maxf(open_time, 0.01))

