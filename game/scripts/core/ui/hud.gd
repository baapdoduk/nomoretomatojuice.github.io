class_name HUD
extends CanvasLayer
## In-level HUD (res://scenes/core/ui/hud.tscn). Instance it in any level; it only
## talks to GameState / InputFeedback / SceneRouter, so it works without a player.
##   - hearts      <- GameState.health_changed
##   - item bar    <- GameState.inventory_changed (+ "Got: <name>" toast on item_added)
##   - toast queue <- GameState.notification_requested, or show_toast() (group "hud")
##   - debug corner (F3 toggles; off by default)
## Toasts still visible when a scene transition starts are carried over to the
## next scene's HUD (e.g. the assist tip emitted right before a respawn).

## Max toasts visible at once; the rest wait in the queue.
@export var max_visible_toasts: int = 3
@export var default_toast_duration: float = 2.0
@export var show_item_pickup_toast: bool = true
## Hearts + item bar (off for menus such as the hub, which only want toasts).
@export var show_status: bool = true:
	set(value):
		show_status = value
		if is_node_ready():
			_top_left.visible = value
@export var debug_visible: bool = false:
	set(value):
		debug_visible = value
		if is_node_ready():
			_debug_label.visible = value

@onready var _top_left: Control = %TopLeft
@onready var _hearts: HeartsDisplay = %Hearts
@onready var _item_bar: HBoxContainer = %ItemBar
@onready var _toast_box: VBoxContainer = %ToastBox
@onready var _debug_label: Label = %DebugLabel

## Pending toasts: Array of [text, duration].
var _queue: Array = []
## Visible toasts: Array of { "node": Control, "text": String, "time_left": float }.
var _active: Array = []

## Toasts handed from a HUD that is being unloaded to the next one: [text, time_left].
static var _carry_over: Array = []
static var _carry_over_msec: int = 0


func _ready() -> void:
	add_to_group(Layers.GROUP_HUD)
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.health_changed.connect(_on_health_changed)
	GameState.inventory_changed.connect(refresh_items)
	GameState.item_added.connect(_on_item_added)
	GameState.notification_requested.connect(show_toast)
	SceneRouter.transition_started.connect(_on_transition_started)
	_on_health_changed(GameState.health, GameState.max_health)
	refresh_items()
	_debug_label.visible = debug_visible
	_top_left.visible = show_status
	if not _carry_over.is_empty() and Time.get_ticks_msec() - _carry_over_msec < 5000:
		for entry: Array in _carry_over:
			show_toast(entry[0], entry[1])
	_carry_over = []


## Queues a toast message. Safe to call through get_tree().call_group("hud", "show_toast", ...).
func show_toast(text: String, duration: float = -1.0) -> void:
	if duration <= 0.0:
		duration = default_toast_duration
	_queue.append([text, duration])
	_pump_queue()


## Texts of the toasts currently on screen (oldest first).
func get_visible_toasts() -> PackedStringArray:
	var out: PackedStringArray = []
	for t: Dictionary in _active:
		out.append(t.text)
	return out

func get_queued_toast_count() -> int:
	return _queue.size()

func get_heart_values() -> Vector2i:
	return Vector2i(_hearts.current, _hearts.maximum)

## Item ids currently shown in the item bar.
func get_item_bar_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for child in _item_bar.get_children():
		if not child.is_queued_for_deletion():
			out.append(StringName(child.get_meta(&"item_id", &"")))
	return out


## Rebuilds the item bar from GameState.
func refresh_items() -> void:
	for child in _item_bar.get_children():
		child.queue_free()
	for id in GameState.get_item_ids():
		_item_bar.add_child(_make_item_slot(id, GameState.get_item_count(id)))


func _make_item_slot(id: StringName, count: int) -> Control:
	var data := GameState.get_item_data(id)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(14, 14)
	slot.set_meta(&"item_id", id)
	slot.tooltip_text = data.display_name if data and data.display_name != "" else String(id)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot.add_child(bg)
	if data and data.icon:
		var icon := TextureRect.new()
		icon.texture = data.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(icon)
	else:
		var swatch := ColorRect.new()
		swatch.name = "Visual"
		swatch.color = data.placeholder_color if data else Color(1.0, 0.85, 0.3)
		swatch.position = Vector2(2, 2)
		swatch.size = Vector2(10, 10)
		slot.add_child(swatch)
	if count > 1:
		var label := Label.new()
		label.text = str(count)
		label.add_theme_font_size_override(&"font_size", 7)
		label.position = Vector2(8, 5)
		slot.add_child(label)
	return slot


func _on_health_changed(current: int, max_health: int) -> void:
	_hearts.set_health(current, max_health)


func _on_item_added(item_id: StringName) -> void:
	if not show_item_pickup_toast:
		return
	var data := GameState.get_item_data(item_id)
	var item_name := data.display_name if data and data.display_name != "" else String(item_id)
	show_toast("Got: %s" % item_name, default_toast_duration)


func _on_transition_started(_path: String, _spawn: StringName) -> void:
	var carry: Array = []
	for t: Dictionary in _active:
		if t.time_left > 0.3:
			carry.append([t.text, t.time_left])
	carry.append_array(_queue)
	if not carry.is_empty():
		_carry_over = carry
		_carry_over_msec = Time.get_ticks_msec()


func _process(delta: float) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var t: Dictionary = _active[i]
		t.time_left -= delta
		var node: Control = t.node
		node.modulate.a = clampf(t.time_left / 0.25, 0.0, 1.0)
		if t.time_left <= 0.0:
			node.queue_free()
			_active.remove_at(i)
	_pump_queue()
	if _debug_label.visible:
		_update_debug()


func _pump_queue() -> void:
	while not _queue.is_empty() and _active.size() < max_visible_toasts:
		var entry: Array = _queue.pop_front()
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.06, 0.05, 0.1, 0.85)
		style.set_content_margin_all(3)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.set_corner_radius_all(3)
		panel.add_theme_stylebox_override(&"panel", style)
		var label := Label.new()
		label.text = entry[0]
		label.add_theme_font_size_override(&"font_size", 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(label)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_toast_box.add_child(panel)
		_active.append({"node": panel, "text": entry[0], "time_left": float(entry[1])})


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F3:
		debug_visible = not debug_visible


func _update_debug() -> void:
	var lines: PackedStringArray = []
	lines.append("FPS %d" % Engine.get_frames_per_second())
	var scene := get_tree().current_scene
	lines.append(scene.name if scene else "-")
	lines.append("input: %s dev %d" % [InputFeedback.last_input_kind, InputFeedback.active_device])
	var player := SceneRouter.get_player()
	if player:
		lines.append("player %d,%d" % [roundi(player.global_position.x), roundi(player.global_position.y)])
		var vel: Variant = player.get(&"velocity")
		if vel is Vector2:
			lines.append("vel %d,%d" % [roundi(vel.x), roundi(vel.y)])
	lines.append("HP %d/%d  deaths %d" % [GameState.health, GameState.max_health, GameState.death_count])
	_debug_label.text = "\n".join(lines)
