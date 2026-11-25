class_name PuzzleController
extends PuzzleDevice
## Combines puzzle devices into one "solved" state.
##
## - `devices` (puzzle input contract) combined with `mode` (ALL = AND, ANY = OR).
## - `solved_flag`: GameState progress flag written on solve; a puzzle whose flag is
##   already set loads solved (and, being latched, stays solved).
## - `latch` (default on): once solved it stays solved until reset().
## - reset(): resets every device (calls their reset()) and itself; safe at any time.
## - Is itself a PuzzleDevice (active = solved), so controllers chain:
##   switch A -> controller A -> gate B ... -> controller C -> final door.
## - Success feedback: `success_player` (AudioStreamPlayer/2D, play() on solve),
##   `flash_targets` (CanvasItems flashed bright), and the `success_feedback` signal
##   for any extra presentation. Feedback never fires for puzzles that load solved.
## - P1 hint: `hint_text` is sent through GameState.notify() after the puzzle stayed
##   unsolved for `hint_delay` seconds while the player was within `hint_radius`.

signal solved
signal unsolved
signal state_changed(is_solved: bool)
## Presentation hook fired on a live solve (not on load).
signal success_feedback
signal hint_shown(text: String)

@export var devices: Array[Node] = []
@export var mode: PuzzleInputs.Logic = PuzzleInputs.Logic.ALL
@export var solved_flag: StringName = &""
@export var latch: bool = true
## Physics frames after reset() during which device changes are ignored, so devices
## whose state settles late (light receivers wait for emitters to re-trace, boxes
## and gates move deferred) cannot instantly re-solve a latched puzzle.
@export_range(0, 30) var reset_settle_frames: int = 3
@export_group("Feedback")
## AudioStreamPlayer / AudioStreamPlayer2D played on solve (any node with play()).
@export var success_player: Node
## CanvasItems whose modulate flashes on solve.
@export var flash_targets: Array[Node] = []
@export var flash_color: Color = Color(2.0, 2.0, 2.0)
@export var flash_time: float = 0.35
@export_group("Hint")
@export_multiline var hint_text: String = ""
## Seconds before the hint (< 0: config.hint_delay).
@export var hint_delay: float = -1.0
## "Nearby" radius in px (< 0: config.hint_radius; 0: anywhere).
@export var hint_radius: float = -1.0
## Show the hint again every hint_delay seconds while still unsolved.
@export var hint_repeat: bool = true
@export var config: PuzzleConfig

var _resetting := false
var _settle_left := 0
var _hint_timer := 0.0
var _hint_count := 0


func _ready() -> void:
	if solved_flag != &"" and persist_flag == &"":
		persist_flag = solved_flag
	super._ready()
	PuzzleInputs.connect_inputs(devices, _on_device_changed, name)
	set_process(hint_text != "")
	set_physics_process(false)
	_evaluate.call_deferred()


func is_solved() -> bool:
	return active

## The raw combination of the devices right now (ignores latch).
func evaluate_devices() -> bool:
	return PuzzleInputs.evaluate(devices, mode)

## Resets all devices and the controller (clears solved_flag). Never soft-locks:
## latched devices, push boxes, mirrors etc. return to their start states.
## The controller reports unsolved immediately and re-evaluates its devices after
## `reset_settle_frames` physics frames.
func reset() -> void:
	_resetting = true
	PuzzleInputs.reset_nodes(devices)
	if persist_flag != &"":
		GameState.clear_flag(persist_flag)
	_settle_left = reset_settle_frames
	_resetting = _settle_left > 0
	set_physics_process(_resetting)
	_hint_timer = 0.0
	_hint_count = 0
	if active:
		active = false
		_apply_state(false, false)
		activated_changed.emit(false)
		unsolved.emit()
		state_changed.emit(false)
	_evaluate()

## Number of times the hint was shown (debug / tests).
func get_hint_count() -> int:
	return _hint_count


## True while the post-reset settle window is running.
func is_settling() -> bool:
	return _resetting


func _physics_process(_delta: float) -> void:
	_settle_left -= 1
	if _settle_left <= 0:
		_resetting = false
		set_physics_process(false)
		_evaluate()


func _evaluate() -> void:
	if _resetting or not is_inside_tree():
		return
	var now := evaluate_devices()
	if active and latch:
		return
	if now == active:
		return
	set_active(now)
	if now:
		if solved_flag != &"":
			GameState.commit_progress()  # milestone: solved state survives a later death
		solved.emit()
		state_changed.emit(true)
		_play_feedback()
	else:
		unsolved.emit()
		state_changed.emit(false)


func _play_feedback() -> void:
	success_feedback.emit()
	if success_player and is_instance_valid(success_player) and success_player.has_method(&"play"):
		success_player.call(&"play")
	for t in flash_targets:
		if t is CanvasItem and is_instance_valid(t):
			var item := t as CanvasItem
			var base := item.modulate
			var tw := item.create_tween()
			tw.tween_property(item, "modulate", flash_color, flash_time * 0.3)
			tw.tween_property(item, "modulate", base, flash_time * 0.7)


func _process(delta: float) -> void:
	if active or hint_text == "":
		_hint_timer = 0.0
		return
	if not _player_nearby():
		return
	_hint_timer += delta
	var cfg := PuzzleConfig.resolve(config)
	var delay := hint_delay if hint_delay >= 0.0 else cfg.hint_delay
	if _hint_timer >= delay and (hint_repeat or _hint_count == 0):
		_hint_timer = 0.0
		_hint_count += 1
		GameState.notify(hint_text, cfg.hint_duration)
		hint_shown.emit(hint_text)


func _player_nearby() -> bool:
	var radius := hint_radius if hint_radius >= 0.0 else PuzzleConfig.resolve(config).hint_radius
	var player := get_tree().get_first_node_in_group(Layers.GROUP_PLAYER) as Node2D
	if player == null:
		return false
	return radius <= 0.0 or player.global_position.distance_to(global_position) <= radius


func _on_device_changed(_active: bool) -> void:
	_evaluate()
