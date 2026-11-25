class_name DripEmitter
extends Node2D
## Leaking bottle (lying on a shelf) that toggles StickyPuddles on a rhythm.
## Cycle = on_time + off_time. Puddles are active for the first `on_time`
## seconds of each cycle (shifted by `phase`). During the last `telegraph_time`
## of the off part a drop forms at the bottle's mouth and falls toward the first
## puddle (telegraph), so the player can read when the puddle returns.
## Origin = bottle mouth. Visuals: swappable `Visual` child (placeholder:
## DripVisual) reading `is_on`, get_telegraph_progress() and get_drip_distance().

signal toggled(active: bool)
signal telegraph_started

@export var puddles: Array[StickyPuddle] = []
@export var on_time: float = 2.0
@export var off_time: float = 2.0
@export var telegraph_time: float = 0.6
## Seconds added to the clock at start (offset several emitters).
@export var phase: float = 0.0
@export var running: bool = true

var time: float = 0.0
var is_on: bool = false
var _telegraphing: bool = false


func _ready() -> void:
	time = phase
	is_on = _phase_on(time)
	_apply_state()


func get_cycle() -> float:
	return maxf(0.01, on_time + off_time)


func _phase_on(t: float) -> bool:
	return fposmod(t, get_cycle()) < on_time


## 0..1 progress of the telegraph (0 when not telegraphing).
func get_telegraph_progress() -> float:
	var c := fposmod(time, get_cycle())
	var start := get_cycle() - telegraph_time
	if is_on or telegraph_time <= 0.0 or c < start:
		return 0.0
	return clampf((c - start) / telegraph_time, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if not running:
		return
	time += delta
	var now := _phase_on(time)
	if now != is_on:
		is_on = now
		_apply_state()
		toggled.emit(is_on)
	var tele := get_telegraph_progress() > 0.0
	if tele and not _telegraphing:
		telegraph_started.emit()
	_telegraphing = tele


## Vertical distance (px) from the mouth to the first puddle (drip fall length).
func get_drip_distance() -> float:
	if not puddles.is_empty() and is_instance_valid(puddles[0]):
		return maxf(4.0, puddles[0].global_position.y - global_position.y)
	return 48.0


func _apply_state() -> void:
	for p in puddles:
		if is_instance_valid(p):
			p.active = is_on

