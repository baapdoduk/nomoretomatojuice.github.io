class_name ExplorationLab
extends Node2D
## Root script of the exploration labs (side_view_lab / top_down_lab).
## Updates an on-screen flag label (the HUD shows hearts/items/toasts) and, optionally, a live
## player debug label (state, velocity, coyote/buffer, dash cooldown).

@export var debug_label: Label
@export var info_label: Label
## Player debug + flag overlays; off by default, F3 toggles it (like the HUD debug corner).
@export var show_debug: bool = false


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		show_debug = not show_debug


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(Layers.GROUP_PLAYER) as Player
	if debug_label:
		debug_label.visible = show_debug and player != null
		if debug_label.visible:
			debug_label.text = _format_debug(player.get_debug_info())
	if info_label:
		info_label.visible = show_debug
		if show_debug:
			info_label.text = _format_info()


func _format_debug(info: Dictionary) -> String:
	var v: Vector2 = info.get("velocity", Vector2.ZERO)
	var lines := PackedStringArray()
	lines.append("state: %s" % info.get("state", ""))
	lines.append("vel: (%.0f, %.0f)" % [v.x, v.y])
	if info.has("coyote"):
		lines.append("floor: %s  coyote: %.2f  buffer: %.2f" % [info.on_floor, info.coyote, info.buffer])
		lines.append("air dashes: %d" % info.air_dashes_left)
	lines.append("dash: %.2f  cooldown: %.2f" % [info.get("dash_left", 0.0), info.get("dash_cooldown", 0.0)])
	lines.append("invuln: %s  locks: %s" % [info.get("invulnerable", false), str(info.get("locks", []))])
	return "\n".join(lines)


## Flags only: hearts, items and toasts are shown by the HUD.
func _format_info() -> String:
	var flags := PackedStringArray()
	var all := GameState.get_all_flags()
	for f in all:
		if bool(all[f]):
			flags.append(String(f))
	return "Flags: %s" % (", ".join(flags) if not flags.is_empty() else "-")
