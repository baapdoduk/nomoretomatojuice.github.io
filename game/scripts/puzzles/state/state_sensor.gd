class_name StateSensor
extends PuzzleDevice
## Puzzle input that is active while the int GameState flag `state_flag`
## (missing = `default_value`) is one of `active_values`. Lets gates, emitters and
## controllers react to map-wide state (e.g. "power == 1" powers an emitter).
## Its state is derived, so persist_flag / start_active are ignored.

@export var state_flag: StringName = &""
@export var default_value: int = 0
@export var active_values: Array[int] = [1]


func _ready() -> void:
	persist_flag = &""
	active = _compute()
	_apply_state(active, true)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_restored.connect(_sync)


func reset() -> void:
	_sync()


func _compute() -> bool:
	return active_values.has(int(GameState.get_flag(state_flag, default_value)))


func _sync() -> void:
	set_active(_compute())


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if flag == state_flag:
		_sync()
