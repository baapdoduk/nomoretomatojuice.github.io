class_name Mirror
extends StaticBody2D
## Flat mirror on the World layer. The reflective surface runs along local +X;
## its front normal is local -Y. Double-sided by default (single-sided mirrors
## block light hitting their back). Hits on the short end caps always block.
##
## Interaction (child Interactable) rotates it by `rotation_step_degrees`
## (<= 0: config.mirror_step_degrees, 90 by default; 45 for finer puzzles).
## The orientation is an integer step index relative to the authored rotation and
## can persist through `persist_flag` (int GameState flag).
## Every rotation notifies the light system (LightTracer.notify_changed).

signal rotated(step_index: int)

@export var double_sided: bool = true
## Degrees per interaction (<= 0: use config.mirror_step_degrees).
@export var rotation_step_degrees: float = 0.0
## Optional int flag storing the orientation step index.
@export var persist_flag: StringName = &""
## Surface length / thickness of the auto-created collision shape.
@export var mirror_length: float = 24.0
@export var mirror_thickness: float = 4.0
@export var config: PuzzleConfig
## Interactable that rotates the mirror (optional; auto-found/created).
@export var interactable: Interactable

## Current orientation as a step count from the authored rotation.
var step_index: int = 0

var _base_rotation: float = 0.0


func _ready() -> void:
	collision_layer = Layers.WORLD
	_base_rotation = rotation
	PuzzlePhysics.ensure_rect_shape(self, Vector2(mirror_length, mirror_thickness))
	interactable = PuzzlePhysics.ensure_interactable(self, interactable, "Rotate", mirror_length * 0.75)
	interactable.interacted.connect(_on_interacted)
	if persist_flag != &"" and GameState.has_flag(persist_flag):
		step_index = int(GameState.get_flag(persist_flag))
	_apply_rotation()


## Degrees per rotation step actually used.
func get_step_degrees() -> float:
	return rotation_step_degrees if rotation_step_degrees > 0.0 else PuzzleConfig.resolve(config).mirror_step_degrees

## Number of distinct orientations (a mirror is symmetric every 180 degrees).
func get_orientation_count() -> int:
	return maxi(1, roundi(180.0 / get_step_degrees()))

## Rotates by one step (`direction` = +1 clockwise on screen, -1 counter-clockwise).
func rotate_step(direction: int = 1) -> void:
	set_step_index(step_index + (1 if direction >= 0 else -1))

func set_step_index(index: int) -> void:
	var count := get_orientation_count()
	step_index = posmod(index, count)
	if persist_flag != &"":
		GameState.set_flag(persist_flag, step_index)
	_apply_rotation()
	rotated.emit(step_index)

## Returns to the authored orientation (clears persist_flag).
func reset() -> void:
	if persist_flag != &"":
		GameState.clear_flag(persist_flag)
	step_index = 0
	_apply_rotation()
	rotated.emit(step_index)

## Global front-face normal.
func get_front_normal() -> Vector2:
	return Vector2.UP.rotated(global_rotation)


## Light classification hook (see LightTracer).
func get_light_response(hit: Dictionary, _direction: Vector2) -> int:
	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	var front := get_front_normal()
	var facing := normal.dot(front)
	if absf(facing) < 0.7:
		return LightTracer.Response.BLOCK # end cap
	if not double_sided and facing < 0.0:
		return LightTracer.Response.BLOCK # back side
	return LightTracer.Response.REFLECT


func _apply_rotation() -> void:
	rotation = _base_rotation + deg_to_rad(get_step_degrees() * step_index)
	if is_inside_tree():
		LightTracer.notify_changed(get_tree())


func _on_interacted(_actor: Node) -> void:
	rotate_step(1)
