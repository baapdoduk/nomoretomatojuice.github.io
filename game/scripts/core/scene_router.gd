extends Node
## SceneRouter (autoload) — scene transitions, spawning and respawn flow.
##
## Flow of change_scene(): pause tree + block input -> fade out -> load scene ->
## place player at SpawnPoint -> record GameState.scene_entry -> fade in -> unpause.
## The whole SceneTree is paused during a transition, so gameplay input,
## interactions and physics cannot run twice or mid-transition.
##
## Spawn contract: nodes in group "spawn_point" expose `spawn_id: StringName`
## and optionally `is_default: bool` and `facing: Vector2`.
## The player is the first node in group "player"; if it has
## `on_spawned(spawn: Node2D)` it is called after placement.

signal transition_started(scene_path: String, spawn_id: StringName)
## New scene is in the tree and the player has been placed (screen still black).
signal scene_loaded(scene_path: String, spawn_id: StringName)
signal transition_finished(scene_path: String)

const DEFAULT_FADE := 0.25
const FADE_LAYER := 100
const STYLE_FADE := &"fade"
const STYLE_IRIS := &"iris"
## Iris wipe = circle closing on the player / opening on the new spawn.
const TRANSITION_SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5);
uniform float aspect = 1.7778;
uniform bool iris = false;
void fragment() {
	float a = progress;
	if (iris) {
		vec2 d = UV - center;
		d.x *= aspect;
		float r = (1.0 - progress) * 2.1;
		a = progress >= 0.999 ? 1.0 : smoothstep(r - 0.006, r + 0.006, length(d));
	}
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""

var is_transitioning := false
var current_spawn_id: StringName = &""
## Style used when change_scene() gets no explicit style.
var default_style: StringName = STYLE_IRIS

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _fade_material: ShaderMaterial
var _style: StringName = STYLE_FADE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = FADE_LAYER
	_fade_layer.name = "FadeLayer"
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	var shader := Shader.new()
	shader.code = TRANSITION_SHADER
	_fade_material = ShaderMaterial.new()
	_fade_material.shader = shader
	_fade_rect.material = _fade_material
	_set_progress(0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)
	# Scenes started directly (F6 / tests) still get a respawn fallback snapshot.
	_capture_initial_scene.call_deferred()


func _capture_initial_scene() -> void:
	var scene := get_tree().current_scene
	if scene and GameState.scene_entry.is_empty():
		GameState.scene_entry = GameState.make_snapshot(scene.scene_file_path, &"")


## Main entry point. Safe to call repeatedly: ignored while a transition runs.
## style: STYLE_FADE or STYLE_IRIS (empty = default_style).
func change_scene(scene_path: String, spawn_id: StringName = &"", fade_time: float = DEFAULT_FADE,
		style: StringName = &"") -> void:
	if is_transitioning:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: scene not found: %s" % scene_path)
		return
	is_transitioning = true
	# Leaving a scene while the death delay runs (pause menu > hub, corpse sliding
	# into an exit) would otherwise carry 0 HP into a scene that can't kill us.
	if GameState.is_dead():
		GameState.refill_health()
	transition_started.emit(scene_path, spawn_id)
	InputFeedback.stop_all_rumble()
	var tree := get_tree()
	tree.paused = true
	_style = style if style != &"" else default_style
	await _fade_to(1.0, fade_time)
	var err := tree.change_scene_to_file(scene_path)
	if err != OK:
		push_error("SceneRouter: failed to load %s (%s)" % [scene_path, error_string(err)])
		await _fade_to(0.0, fade_time)
		tree.paused = false
		is_transitioning = false
		return
	await tree.scene_changed
	current_spawn_id = spawn_id
	place_player_at_spawn(spawn_id)
	GameState.scene_entry = GameState.make_snapshot(scene_path, spawn_id)
	scene_loaded.emit(scene_path, spawn_id)
	await _fade_to(0.0, fade_time)
	tree.paused = false
	is_transitioning = false
	transition_finished.emit(scene_path)


func reload_current_scene(spawn_id: StringName = current_spawn_id) -> void:
	change_scene(get_current_scene_path(), spawn_id)


## Death / "restart from checkpoint". Restores the checkpoint snapshot
## (or, if none, the snapshot taken when the current scene was entered)
## and reloads the corresponding scene.
func respawn_at_checkpoint() -> void:
	if is_transitioning:
		return
	GameState.note_death()
	var snap: Dictionary = GameState.checkpoint
	if snap.is_empty():
		snap = GameState.scene_entry
	if snap.is_empty():
		GameState.refill_health()
		reload_current_scene()
		return
	GameState.restore_snapshot(snap)
	var path := String(snap.get("scene_path", ""))
	if path == "":
		path = get_current_scene_path()
	change_scene(path, StringName(String(snap.get("spawn_id", ""))))


## Restores the GameState.begin_chapter() snapshot (falls back to checkpoint).
func restart_chapter() -> void:
	if is_transitioning:
		return
	var snap: Dictionary = GameState.chapter_start
	if snap.is_empty():
		respawn_at_checkpoint()
		return
	GameState.restore_snapshot(snap)
	GameState.checkpoint = snap.duplicate(true)
	change_scene(String(snap.get("scene_path", "")), StringName(String(snap.get("spawn_id", ""))))


## Returns to the project's main scene (the test hub during framework work).
func go_to_hub() -> void:
	var main_scene := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene != "":
		change_scene(main_scene)


func get_current_scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene else ""


func get_player() -> Node2D:
	return get_tree().get_first_node_in_group(Layers.GROUP_PLAYER) as Node2D


func find_spawn_point(spawn_id: StringName) -> Node2D:
	var first: Node2D = null
	var default_spawn: Node2D = null
	for node in get_tree().get_nodes_in_group(Layers.GROUP_SPAWN_POINT):
		if not node is Node2D:
			continue
		if spawn_id != &"" and node.get(&"spawn_id") == spawn_id:
			return node
		if first == null:
			first = node
		if default_spawn == null and node.get(&"is_default") == true:
			default_spawn = node
	if spawn_id != &"":
		push_warning("SceneRouter: spawn '%s' not found, using default" % spawn_id)
	return default_spawn if default_spawn else first


## Moves the player to the requested spawn point. Returns false if either is missing.
func place_player_at_spawn(spawn_id: StringName) -> bool:
	var player := get_player()
	var spawn := find_spawn_point(spawn_id)
	if player == null or spawn == null:
		return false
	player.global_position = spawn.global_position
	if player.has_method(&"on_spawned"):
		player.call(&"on_spawned", spawn)
	return true


## 0 = clear, 1 = fully covered. Iris centres on the player (or the screen).
func _fade_to(target: float, duration: float) -> void:
	var iris := _style == STYLE_IRIS
	_fade_material.set_shader_parameter(&"iris", iris)
	if iris:
		var vp := get_viewport().get_visible_rect().size
		_fade_material.set_shader_parameter(&"aspect", vp.x / maxf(1.0, vp.y))
		_fade_material.set_shader_parameter(&"center", _iris_center(vp))
	if duration <= 0.0:
		_set_progress(target)
		return
	var tween := create_tween()
	tween.tween_method(_set_progress, get_transition_progress(), target, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _set_progress(value: float) -> void:
	_fade_material.set_shader_parameter(&"progress", value)

## Current cover amount of the transition overlay (0..1).
func get_transition_progress() -> float:
	var value: Variant = _fade_material.get_shader_parameter(&"progress")
	return float(value) if value != null else 0.0

func _iris_center(viewport_size: Vector2) -> Vector2:
	var player := get_player()
	if player and player.is_inside_tree() and viewport_size.x > 0.0:
		var screen_pos := player.get_global_transform_with_canvas().origin
		return (screen_pos / viewport_size).clamp(Vector2.ZERO, Vector2.ONE)
	return Vector2(0.5, 0.5)
