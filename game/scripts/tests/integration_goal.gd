extends Interactable
## Final marker of the integration slice. Needs the boss defeated (base
## required_flags); interacting sets `complete_flag` and shows a toast.
## A SceneDoor to the hub next to it requires the same flag.

signal completed

@export var complete_flag: StringName = &"integration.complete"
@export var complete_message: String = "Integration slice complete!"


func _init() -> void:
	super._init()
	prompt_text = "Finish"
	locked_prompt_text = "Defeat the boss first"
	blocked_message = "The shrine is still sealed."


func is_complete() -> bool:
	return GameState.has_flag(complete_flag)


func _perform(_actor: Node) -> void:
	GameState.set_flag(complete_flag, true)
	if complete_message != "":
		GameState.notify(complete_message)
	completed.emit()
