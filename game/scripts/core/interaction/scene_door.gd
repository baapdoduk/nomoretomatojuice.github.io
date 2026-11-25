class_name SceneDoor
extends Interactable
## Door to another scene: interact -> SceneRouter.change_scene(target_scene, target_spawn_id).
## Lock it with the base conditions (required_item / required_flags,
## locked_prompt_text, blocked_message). The router pauses the tree during the
## transition, so no extra input lock is needed.

## Emitted right before the transition starts.
signal entered(target_scene: String, target_spawn_id: StringName)

@export_file("*.tscn") var target_scene: String = ""
## Spawn id in the target scene (convention: &"from_<this_scene_name>").
@export var target_spawn_id: StringName = &""
@export var fade_time: float = 0.25


func _init() -> void:
	super._init()
	prompt_text = "Enter"


func _perform(_actor: Node) -> void:
	go()


## Starts the transition (also usable from scripts).
func go() -> void:
	if target_scene == "":
		push_warning("SceneDoor %s has no target_scene" % name)
		return
	entered.emit(target_scene, target_spawn_id)
	SceneRouter.change_scene(target_scene, target_spawn_id, fade_time)
