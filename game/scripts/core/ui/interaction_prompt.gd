class_name InteractionPrompt
extends Node2D
## World-space prompt ("[glyph] Text") shown above the focused Interactable.
## top_level, so it follows the target's get_prompt_position() rather than the
## player. Scene: res://scenes/core/ui/interaction_prompt.tscn.

@export var glyph: ButtonGlyph
@export var label: Label

var target: Interactable = null


func _ready() -> void:
	top_level = true
	z_index = 50
	if glyph == null:
		glyph = find_child("Glyph", true, false) as ButtonGlyph
	if label == null:
		label = find_child("Label", true, false) as Label
	hide_prompt()


func show_for(p_target: Interactable) -> void:
	target = p_target
	_refresh()
	visible = true


func hide_prompt() -> void:
	target = null
	visible = false


func get_text() -> String:
	return label.text if label else ""


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	if target == null or not is_instance_valid(target):
		hide_prompt()
		return
	global_position = target.get_prompt_position()
	if glyph and glyph.action != target.prompt_action:
		glyph.action = target.prompt_action
	if label:
		label.text = target.get_prompt_text()
