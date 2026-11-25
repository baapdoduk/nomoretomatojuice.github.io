class_name SceneExit
extends SceneDoor
## Touch-triggered scene transition (screen edges, corridors). Never focused by
## the Interactor; fires when the player body enters. Base conditions still
## apply (blocked_message is shown when unmet).

func _ready() -> void:
	collision_mask = Layers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)


func _can_interact(_actor: Node) -> bool:
	return false


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or not enabled or SceneRouter.is_transitioning:
		return
	if not conditions_met():
		if blocked_message != "":
			GameState.notify(blocked_message)
		return
	interacted.emit(body)
	go()
