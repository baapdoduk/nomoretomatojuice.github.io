class_name ResetLever
extends Node2D
## Anti-soft-lock tool: using its Interactable calls reset() on every node in
## `targets` (PuzzleControllers, devices, mirrors, push boxes, gates, StateLevers...).

signal reset_triggered

@export var targets: Array[Node] = []
## Toast shown after a reset (empty = none).
@export var message: String = "The puzzle has been reset."
## Interactable that triggers the reset (optional; auto-found/created).
@export var interactable: Interactable


func _ready() -> void:
	interactable = PuzzlePhysics.ensure_interactable(self, interactable, "Reset")
	interactable.interacted.connect(_on_interacted)


## Resets all targets now.
func reset_all() -> void:
	PuzzleInputs.reset_nodes(targets)
	if message != "":
		GameState.notify(message)
	reset_triggered.emit()


func _on_interacted(_actor: Node) -> void:
	reset_all()
