extends Node2D
## Puzzle lab root (puzzle_lab.tscn / puzzle_lab_world.tscn). Presentation only:
## refreshes an info overlay listing the GameState flags that matter for the lab
## (solved puzzles, opened doors, water level, active world layer).

## Label that shows the live flag overview.
@export var info_label: Label
## Flags listed in the overlay (name -> shown as "name: value").
@export var watched_flags: Array[StringName] = []

var _t := 0.0


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		_refresh()


func _refresh() -> void:
	if info_label == null:
		return
	var lines: PackedStringArray = []
	for f in watched_flags:
		lines.append("%s: %s" % [f, str(GameState.get_flag(f, "-"))])
	info_label.text = "\n".join(lines)
