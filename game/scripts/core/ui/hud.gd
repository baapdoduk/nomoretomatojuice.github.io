class_name HUD
extends CanvasLayer
## In-level HUD (res://scenes/core/ui/hud.tscn). Instance it in any level; it only
## talks to GameState / InputFeedback / SceneRouter, so it works without a player.
##   - hearts      <- GameState.health_changed
##   - item bar    <- GameState.inventory_changed (+ "Got: <name>" toast on item_added)
##   - Fizz counter <- GameState.coins_changed (bubble icon + number)
##   - shard slots (top-right, 3 polaroids) <- the scene's LevelInfo + "shard.<level>.<n>"
##     flags; hidden when the scene has no LevelInfo
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
			refresh_shards()
## Fizz counter (part of the status block).
@export var show_fizz: bool = true:
	set(value):
		show_fizz = value
		if is_node_ready():
			_fizz_row.visible = value
@export var fizz_icon_color: Color = Color(0.72, 0.95, 1.0, 0.9)
@export var fizz_rim_color: Color = Color(0.35, 0.8, 0.85)
@export var shard_frame_color: Color = Color(0.96, 0.93, 0.86)
@export var shard_empty_color: Color = Color(0.12, 0.08, 0.14, 0.85)
@export var shard_photo_color: Color = Color(0.42, 0.26, 0.45)
@export var shard_light_color: Color = Color(0.95, 0.68, 0.3)
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
@onready var _fizz_row: HBoxContainer = %FizzRow
@onready var _fizz_icon: Control = %FizzIcon
@onready var _fizz_label: Label = %FizzLabel
@onready var _shard_bar: HBoxContainer = %ShardBar

## Pending toasts: Array of [text, duration].
var _queue: Array = []
## Visible toasts: Array of { "node": Control, "text": String, "time_left": float }.
var _active: Array = []

## Toasts handed from a HUD that is being unloaded to the next one: [text, time_left].
var _shards_dirty := false

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
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.state_restored.connect(refresh_shards)
	get_tree().node_added.connect(_on_tree_node_changed)
	get_tree().node_removed.connect(_on_tree_node_changed)
	_fizz_icon.draw.connect(_draw_fizz_icon)
	_fizz_row.visible = show_fizz
	_on_health_changed(GameState.health, GameState.max_health)
	_on_coins_changed(GameState.coins)
	refresh_items()
	refresh_shards()
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


## Number shown by the Fizz counter.
func get_fizz_count() -> int:
	return int(_fizz_label.text)

## Shard slot states (true = collected); empty when the bar is hidden.
func get_shard_slots() -> Array[bool]:
	var out: Array[bool] = []
	if not _shard_bar.visible:
		return out
	for child in _shard_bar.get_children():
		if not child.is_queued_for_deletion():
			out.append(bool(child.get_meta(&"collected", false)))
	return out

func is_shard_bar_visible() -> bool:
	return _shard_bar.visible


## Rebuilds the polaroid slots from the scene's LevelInfo (hidden without one).
func refresh_shards() -> void:
	if not is_node_ready():
		return
	for child in _shard_bar.get_children():
		_shard_bar.remove_child(child)
		child.queue_free()
	var info := LevelInfo.find_in(get_tree())
	_shard_bar.visible = info != null and info.shard_count > 0 and show_status
	if not _shard_bar.visible:
		return
	for got in info.get_shard_states():
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(13, 16)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.set_meta(&"collected", got)
		slot.draw.connect(_draw_shard_slot.bind(slot, got))
		_shard_bar.add_child(slot)


func _draw_shard_slot(slot: Control, got: bool) -> void:
	var r := Rect2(Vector2.ZERO, slot.custom_minimum_size)
	slot.draw_rect(r.grow(1), Color(0.06, 0.04, 0.08, 0.9))
	if got:
		slot.draw_rect(r, shard_frame_color)
		slot.draw_rect(Rect2(2, 2, r.size.x - 4, r.size.y - 7), shard_photo_color)
		slot.draw_circle(Vector2(r.size.x - 5, 5), 1.5, shard_light_color)
	else:
		slot.draw_rect(r, shard_empty_color)
		slot.draw_rect(r.grow(-1), Color(shard_frame_color, 0.35), false, 1.0)


func _draw_fizz_icon() -> void:
	var c := _fizz_icon.size * 0.5
	var rad := minf(c.x, c.y) - 0.5
	_fizz_icon.draw_circle(c, rad, fizz_icon_color)
	_fizz_icon.draw_arc(c, rad, 0.0, TAU, 14, fizz_rim_color, 1.0)
	_fizz_icon.draw_circle(c + Vector2(-rad * 0.35, -rad * 0.35), rad * 0.3, Color.WHITE)


func _on_coins_changed(total: int) -> void:
	_fizz_label.text = str(total)


func _on_flag_changed(flag: StringName, _value: Variant) -> void:
	if String(flag).begins_with("shard."):
		refresh_shards()


## LevelInfo added/removed: rebuild the slots on the next frame (after removal).
func _on_tree_node_changed(node: Node) -> void:
	if node is LevelInfo:
		_shards_dirty = true


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
	if _shards_dirty:
		_shards_dirty = false
		refresh_shards()
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
