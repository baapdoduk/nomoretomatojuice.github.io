class_name InfoPopup
extends CanvasLayer
## Modal photo / dialog popup (title, body, optional image).
## Scene: res://scenes/core/ui/popup_panel.tscn. Closes with interact, jump or
## ui_accept (keyboard and pad). The press that opened it is ignored: input is
## only read from the frame after show_popup().
## (Named InfoPopup because Godot already has a built-in PopupPanel class.)

signal opened
signal closed

const CLOSE_ACTIONS: Array[StringName] = [&"interact", &"jump", &"ui_accept"]
## Fallback scene used when a caller does not provide its own popup_scene.
const DEFAULT_SCENE_PATH := "res://scenes/core/ui/popup_panel.tscn"

@export var title_label: Label
@export var body_label: Label
@export var image_rect: TextureRect
@export var root_control: Control

var _open: bool = false
var _input_armed: bool = false


## Instantiates a popup (scene or the default one) under `parent`, shows it,
## optionally locks `player` input (reason &"popup") until closed, and waits
## for it to close. The popup frees itself afterwards. Coroutine.
static func show_and_wait(parent: Node, title: String, body: String, texture: Texture2D = null,
		scene: PackedScene = null, player: Player = null) -> void:
	if scene == null:
		scene = load(DEFAULT_SCENE_PATH)
	var popup := scene.instantiate() as InfoPopup
	parent.add_child(popup)
	if player:
		player.add_input_lock(&"popup")
	popup.show_popup(title, body, texture)
	await popup.closed
	if player and is_instance_valid(player):
		player.remove_input_lock(&"popup")
	popup.queue_free()


func _ready() -> void:
	if root_control:
		root_control.visible = false


## Shows the popup. texture may be null (no image row).
func show_popup(title: String, body: String, texture: Texture2D = null) -> void:
	if title_label:
		title_label.text = title
		title_label.visible = title != ""
	if body_label:
		body_label.text = body
	if image_rect:
		image_rect.texture = texture
		image_rect.visible = texture != null
	if root_control:
		root_control.visible = true
	_open = true
	_input_armed = false
	opened.emit()


func is_open() -> bool:
	return _open


func close() -> void:
	if not _open:
		return
	_open = false
	if root_control:
		root_control.visible = false
	closed.emit()


func _process(_delta: float) -> void:
	if not _open:
		return
	if not _input_armed:
		# Wait until the opening press is released / one frame has passed.
		_input_armed = true
		return
	for action in CLOSE_ACTIONS:
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			close()
			return
