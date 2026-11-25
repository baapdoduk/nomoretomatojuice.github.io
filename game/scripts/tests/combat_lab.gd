class_name CombatLab
extends ExplorationLab
## Combat lab root (res://scenes/tests/combat_lab.tscn).
## Adds boss state lines to the ExplorationLab info overlay. (A boss victory
## survives a later death through GameState.commit_progress(), called by Boss.)

## Main arena boss (test boss).
@export var boss: Boss
## Side-room prototype boss (mogu bottle).
@export var side_boss: Boss


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
