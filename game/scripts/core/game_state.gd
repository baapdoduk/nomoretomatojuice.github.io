extends Node
## GameState (autoload) — single source of truth for persistent progress.
##
## Owns: player health, inventory (items), progress flags, checkpoint / chapter
## snapshots, user settings and the on-disk save (P1).
## Does NOT own: scene loading (SceneRouter), devices/rumble (InputFeedback),
## per-entity runtime state (components).
##
## Flag naming convention: "<scope>.<id>.<what>", e.g.
##   "puzzle.lab_light_a.solved", "door.overworld_shortcut.open", "boss.test_boss.defeated".
## Flag values must be JSON-compatible: bool, int, float or String.

signal health_changed(current: int, max_health: int)
signal coins_changed(total: int)
signal player_died
signal item_added(item_id: StringName)
signal item_removed(item_id: StringName)
signal inventory_changed
signal flag_changed(flag: StringName, value: Variant)
signal checkpoint_saved(snapshot: Dictionary)
## Emitted after restore_snapshot() replaced health/items/flags wholesale.
signal state_restored
## UI-facing transient message (toast). The HUD listens; no HUD = silently ignored.
signal notification_requested(text: String, duration: float)
signal settings_changed(key: StringName, value: Variant)
## Emitted once per frame after commit_progress() folded live progress into the
## respawn snapshot(s). Payload = the updated checkpoint (or scene_entry).
signal progress_committed(snapshot: Dictionary)

const SAVE_VERSION := 1
const SAVE_PATH := "user://save_slot_0.json"
## After this many deaths since the last checkpoint, suggest the combat assist option.
const ASSIST_SUGGEST_DEATHS := 3

var max_health: int = 5
var health: int = 5
## Currency collected in levels (part of snapshots: reverts with a death like
## other non-milestone progress, so respawning coins can't be farmed).
var coins: int = 0
## Last checkpoint snapshot ({} when none). See make_snapshot() for the layout.
var checkpoint: Dictionary = {}
## Snapshot taken by begin_chapter(); used by "restart chapter".
var chapter_start: Dictionary = {}
## Snapshot taken by SceneRouter whenever a scene finished loading (respawn fallback).
var scene_entry: Dictionary = {}
var current_chapter: StringName = &""
var death_count: int = 0
var deaths_since_checkpoint: int = 0

var settings: Dictionary = {
	&"vibration_enabled": true,
	&"vibration_strength": 1.0,
	&"stick_deadzone": 0.2,
	## P1: longer telegraphs / recovery windows for bosses (see get_combat_timing_scale()).
	&"assist_combat_timing": false,
	## Context actions: replace mash/timed inputs with simple holds.
	&"assist_context_actions": false,
	&"autosave_on_checkpoint": false,
	## Game-feel toggles (accessibility): camera shake and hit-stop freeze frames.
	&"screen_shake": true,
	&"hit_stop": true,
}

var _items: Dictionary = {}      # StringName -> int (count)
var _item_data: Dictionary = {}  # StringName -> ItemData
var _flags: Dictionary = {}      # StringName -> Variant
var _death_emitted := false
var _commit_pending := false


# --------------------------------------------------------------------------- lifecycle

func new_game(starting_max_health: int = 5) -> void:
	max_health = starting_max_health
	health = max_health
	coins = 0
	coins_changed.emit(coins)
	_items.clear()
	_flags.clear()
	checkpoint = {}
	chapter_start = {}
	scene_entry = {}
	current_chapter = &""
	death_count = 0
	deaths_since_checkpoint = 0
	_death_emitted = false
	_commit_pending = false
	health_changed.emit(health, max_health)
	inventory_changed.emit()
	state_restored.emit()


# --------------------------------------------------------------------------- health

func set_max_health(value: int, refill: bool = true) -> void:
	max_health = maxi(1, value)
	health = max_health if refill else mini(health, max_health)
	_death_emitted = health <= 0
	health_changed.emit(health, max_health)

## Returns the new health. Emits player_died exactly once when reaching 0.
func apply_damage(amount: int) -> int:
	if amount <= 0 or health <= 0:
		return health
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health == 0 and not _death_emitted:
		_death_emitted = true
		player_died.emit()
	return health

func heal(amount: int) -> int:
	if amount <= 0 or health <= 0:
		return health
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)
	return health

func refill_health() -> void:
	health = max_health
	_death_emitted = false
	health_changed.emit(health, max_health)

func is_dead() -> bool:
	return health <= 0


# --------------------------------------------------------------------------- coins

func add_coins(amount: int) -> int:
	if amount == 0:
		return coins
	coins = maxi(0, coins + amount)
	coins_changed.emit(coins)
	return coins


# --------------------------------------------------------------------------- items

## Makes an ItemData known (for icons / names) without granting it.
func register_item(item: ItemData) -> void:
	if item and item.id != &"":
		_item_data[item.id] = item

## Grants an item. Returns false (and changes nothing) when it would duplicate a
## non-stackable item or exceed max_stack. This is the duplicate-pickup guard.
func add_item(item: ItemData, count: int = 1) -> bool:
	if item == null or item.id == &"" or count <= 0:
		push_warning("GameState.add_item: invalid item")
		return false
	register_item(item)
	var owned: int = _items.get(item.id, 0)
	var limit := item.get_stack_limit()
	if owned >= limit:
		return false
	_items[item.id] = mini(limit, owned + count)
	item_added.emit(item.id)
	inventory_changed.emit()
	return true

func has_item(item_id: StringName, count: int = 1) -> bool:
	return int(_items.get(item_id, 0)) >= count

func get_item_count(item_id: StringName) -> int:
	return int(_items.get(item_id, 0))

func remove_item(item_id: StringName, count: int = 1) -> bool:
	var owned: int = _items.get(item_id, 0)
	if owned < count or count <= 0:
		return false
	if owned == count:
		_items.erase(item_id)
	else:
		_items[item_id] = owned - count
	item_removed.emit(item_id)
	inventory_changed.emit()
	return true

func get_item_data(item_id: StringName) -> ItemData:
	return _item_data.get(item_id, null)

## Owned item ids in acquisition order.
func get_item_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _items:
		ids.append(id)
	return ids


# --------------------------------------------------------------------------- flags

func set_flag(flag: StringName, value: Variant = true) -> void:
	if _flags.has(flag) and _flags[flag] == value:
		return
	_flags[flag] = value
	flag_changed.emit(flag, value)

func get_flag(flag: StringName, default: Variant = false) -> Variant:
	return _flags.get(flag, default)

## True when the flag exists and is truthy (non-zero / non-empty / true).
func has_flag(flag: StringName) -> bool:
	return _flags.has(flag) and bool(_flags[flag])

func clear_flag(flag: StringName) -> void:
	if _flags.erase(flag):
		flag_changed.emit(flag, null)

func get_all_flags() -> Dictionary:
	return _flags.duplicate(true)


# --------------------------------------------------------------------------- snapshots

## Snapshot layout (also the save-file "checkpoint" payload):
## { version, scene_path, spawn_id, chapter, health, max_health,
##   items: {id: count}, item_paths: {id: res_path}, flags: {name: value} }
func make_snapshot(scene_path: String, spawn_id: StringName) -> Dictionary:
	var items := {}
	var paths := {}
	for id: StringName in _items:
		items[String(id)] = _items[id]
		var data: ItemData = _item_data.get(id, null)
		if data and data.resource_path != "":
			paths[String(id)] = data.resource_path
	var flags := {}
	for f: StringName in _flags:
		flags[String(f)] = _flags[f]
	return {
		"version": SAVE_VERSION,
		"scene_path": scene_path,
		"spawn_id": String(spawn_id),
		"chapter": String(current_chapter),
		"health": health,
		"max_health": max_health,
		"coins": coins,
		"items": items,
		"item_paths": paths,
		"flags": flags,
	}

## Replaces health, items and flags with the snapshot contents. Items and world
## flags are restored together, so pickups collected after the snapshot reappear
## in the world and are removed from the inventory (no duplication, no loss).
func restore_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	max_health = int(snapshot.get("max_health", max_health))
	health = clampi(int(snapshot.get("health", max_health)), 1, max_health)
	coins = int(snapshot.get("coins", coins))
	_death_emitted = false
	_commit_pending = false
	current_chapter = StringName(String(snapshot.get("chapter", "")))
	_items.clear()
	var paths: Dictionary = snapshot.get("item_paths", {})
	var items: Dictionary = snapshot.get("items", {})
	for key in items:
		var id := StringName(String(key))
		_items[id] = int(items[key])
		if not _item_data.has(id) and paths.has(key):
			var res := load(String(paths[key]))
			if res is ItemData:
				_item_data[id] = res
	_flags.clear()
	var flags: Dictionary = snapshot.get("flags", {})
	for key in flags:
		_flags[StringName(String(key))] = _normalize_json_value(flags[key])
	health_changed.emit(health, max_health)
	coins_changed.emit(coins)
	inventory_changed.emit()
	state_restored.emit()

## Called by Checkpoint nodes. refill=true heals the player before snapshotting.
func save_checkpoint(scene_path: String, spawn_id: StringName, refill: bool = true) -> void:
	if refill:
		refill_health()
	var same_checkpoint := not checkpoint.is_empty() and String(checkpoint.get("scene_path", "")) == scene_path \
		and String(checkpoint.get("spawn_id", "")) == String(spawn_id)
	checkpoint = make_snapshot(scene_path, spawn_id)
	if not same_checkpoint:
		deaths_since_checkpoint = 0
	checkpoint_saved.emit(checkpoint)
	if settings.get(&"autosave_on_checkpoint", false):
		save_to_disk()

func has_checkpoint() -> bool:
	return not checkpoint.is_empty()

## Marks the start of a chapter (scene_path/spawn_id = chapter entrance).
## Also acts as a checkpoint so a death before any checkpoint returns here.
func begin_chapter(chapter_id: StringName, scene_path: String, spawn_id: StringName) -> void:
	current_chapter = chapter_id
	chapter_start = make_snapshot(scene_path, spawn_id)
	checkpoint = chapter_start.duplicate(true)
	deaths_since_checkpoint = 0

## Milestone commit (progress policy, see ARCHITECTURE.md §6).
## Death still restores the whole snapshot, but milestone progress (boss defeated,
## puzzle solved, shortcut opened, key/memory collected, item used) must survive.
## This folds the *entire* live items + flags (+ max_health) into the respawn
## snapshot(s) while keeping their scene, spawn and health. Atomic (items and
## flags always move together, so no duplication/loss) and deferred/coalesced to
## the end of the frame so multi-step mutations (add_item + set_flag) are captured
## whole. Never touches chapter_start ("Restart chapter" reverts everything).
## Components call it automatically; custom scripts use set_milestone().
func commit_progress() -> void:
	if _commit_pending:
		return
	_commit_pending = true
	_flush_commit.call_deferred()

## set_flag() + commit_progress(), for cutscenes / custom level scripts.
func set_milestone(flag: StringName, value: Variant = true) -> void:
	set_flag(flag, value)
	commit_progress()

func _flush_commit() -> void:
	if not _commit_pending:
		return  # cancelled by new_game()/restore
	_commit_pending = false
	if is_dead():
		return  # the player did not survive the frame: nothing is committed
	var live := make_snapshot("", &"")
	var committed := {}
	for target: Dictionary in [checkpoint, scene_entry]:
		if target.is_empty():
			continue
		target["items"] = (live["items"] as Dictionary).duplicate(true)
		target["item_paths"] = (live["item_paths"] as Dictionary).duplicate(true)
		target["flags"] = (live["flags"] as Dictionary).duplicate(true)
		target["max_health"] = max_health
		target["coins"] = coins
		target["health"] = clampi(int(target.get("health", max_health)), 1, max_health)
		if committed.is_empty():
			committed = target
	if committed.is_empty():
		return
	progress_committed.emit(committed)
	if settings.get(&"autosave_on_checkpoint", false) and has_checkpoint():
		save_to_disk()

## Bookkeeping hook used by SceneRouter.respawn_at_checkpoint().
func note_death() -> void:
	death_count += 1
	deaths_since_checkpoint += 1
	if deaths_since_checkpoint >= ASSIST_SUGGEST_DEATHS and not settings.get(&"assist_combat_timing", false):
		notify("Tip: Assist timing can be enabled in the pause menu.", 3.5)


# --------------------------------------------------------------------------- settings / ui

func set_setting(key: StringName, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit(key, value)

func get_setting(key: StringName, default: Variant = null) -> Variant:
	return settings.get(key, default)

## Multiplier for boss telegraph / recovery durations (P1 assist option).
func get_combat_timing_scale() -> float:
	return 1.35 if settings.get(&"assist_combat_timing", false) else 1.0

func notify(text: String, duration: float = 2.0) -> void:
	notification_requested.emit(text, duration)


# --------------------------------------------------------------------------- disk save (P1)

func save_to_disk(path: String = SAVE_PATH) -> Error:
	var data := {
		"version": SAVE_VERSION,
		"checkpoint": checkpoint,
		"chapter_start": chapter_start,
		"death_count": death_count,
		"settings": _settings_to_json(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("GameState.save_to_disk failed: %s" % error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	return OK

## Loads settings + checkpoint data and restores the checkpoint snapshot.
## Returns false when the file is missing, unreadable or from an unknown version.
## The caller (e.g. a title menu) then calls SceneRouter.respawn_at_checkpoint().
func load_from_disk(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("GameState.load_from_disk: corrupt save")
		return false
	var data: Dictionary = parsed
	var version := int(data.get("version", 0))
	if version < 1 or version > SAVE_VERSION:
		push_warning("GameState.load_from_disk: unsupported save version %d" % version)
		return false
	var saved_settings: Dictionary = data.get("settings", {})
	for key in saved_settings:
		set_setting(StringName(String(key)), _normalize_json_value(saved_settings[key]))
	death_count = int(data.get("death_count", 0))
	chapter_start = data.get("chapter_start", {})
	checkpoint = data.get("checkpoint", {})
	restore_snapshot(checkpoint)
	return true

func _settings_to_json() -> Dictionary:
	var out := {}
	for key: StringName in settings:
		out[String(key)] = settings[key]
	return out

## JSON turns every number into float; restore integral values to int.
func _normalize_json_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT and is_equal_approx(value, roundf(value)) and absf(value) < 1e9:
		return int(value)
	return value
