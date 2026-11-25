class_name PopupInteractable
extends Interactable
## Sign / photo / dialog spot: interact opens an InfoPopup with title, body and
## an optional image; player movement is locked until it closes (interact /
## jump / ui_accept). Optionally sets `read_flag` after the first read.

@export var title: String = ""
@export_multiline var body: String = ""
@export var image: Texture2D
## Popup UI scene (defaults to res://scenes/core/ui/popup_panel.tscn).
@export var popup_scene: PackedScene
## Optional GameState flag set when the popup was read.
@export var read_flag: StringName = &""

## The open popup while showing (null otherwise).
var current_popup: InfoPopup = null


func _init() -> void:
	super._init()
	prompt_text = "Read"
	lock_movement = true


func _perform(_actor: Node) -> void:
	var scene := popup_scene if popup_scene else load(InfoPopup.DEFAULT_SCENE_PATH) as PackedScene
	current_popup = scene.instantiate() as InfoPopup
	add_child(current_popup)
	current_popup.show_popup(title, body, image)
	await current_popup.closed
	current_popup.queue_free()
	current_popup = null
	if read_flag != &"":
		GameState.set_flag(read_flag, true)
