class_name CombatLab
extends ExplorationLab
## Combat lab root (res://scenes/tests/combat_lab.tscn).
## Adds boss state lines to the ExplorationLab info overlay and keeps a boss
## victory: when `boss` is defeated the pre-boss checkpoint is re-saved (without
## refill), so the defeated flag survives a later death in this lab.

## Main arena boss (test boss).
@export var boss: Boss
## Side-room prototype boss (mogu bottle).
@export var side_boss: Boss
## Checkpoint re-saved on victory.
@export var victory_checkpoint: Checkpoint


func _ready() -> void:
	if boss and is_instance_valid(boss):
		boss.defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	if victory_checkpoint:
		GameState.save_checkpoint(SceneRouter.get_current_scene_path(), victory_checkpoint.get_spawn_id(), false)


func _format_info() -> String:
	var text := super._format_info()
	for candidate in [boss, side_boss]:
		if candidate == null or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		var b := candidate as Boss
		if b.config:
			text += "\n%s: %s  phase %d  hp %d/%d  %s" % [b.config.display_name, Boss.state_name(b.state),
				b.phase_index, b.health.current, b.health.max_health, "OPEN" if b.is_vulnerable() else "guarded"]
	return text
