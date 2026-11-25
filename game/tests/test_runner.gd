extends Node
## Headless test runner scene (res://tests/test_runner.tscn).
## Usage (from repo root):  game/tools/run_tests.sh [filter]
##   or: godot --headless --path game --fixed-fps 60 res://tests/test_runner.tscn -- --filter=light
## Discovers res://tests/{unit,integration,smoke}/test_*.gd, runs every test_* method,
## captures engine/script errors through a Logger (an error during a test fails it),
## prints a summary and exits with code 0 (all passed) or 1.

const TEST_DIRS := ["res://tests/unit", "res://tests/integration", "res://tests/smoke"]
const WATCHDOG_SECONDS := 600.0

class ErrorCatcher extends Logger:
	var errors: PackedStringArray = []
	var _mutex := Mutex.new()
	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		errors.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		_mutex.unlock()
	func take() -> PackedStringArray:
		_mutex.lock()
		var out := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return out

var _catcher := ErrorCatcher.new()
var _filter := ""
var _passed := 0
var _failed: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OS.add_logger(_catcher)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			_filter = arg.substr(9)
	# Detach from current_scene so SceneRouter.change_scene() in tests can't free the runner.
	var placeholder := Node.new()
	placeholder.name = "TestPlaceholderScene"
	get_tree().root.add_child.call_deferred(placeholder)
	await get_tree().process_frame
	get_tree().current_scene = placeholder
	# No respawn fallback into the runner itself; tests that die must load a real scene first.
	GameState.scene_entry = {}
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog)
	await _run_all()


func _run_all() -> void:
	var files := _collect_files()
	print("\n=== Running %d test file(s)%s ===" % [files.size(), (" filter=" + _filter) if _filter != "" else ""])
	for path in files:
		await _run_file(path)
	_catcher.take()
	print("\n=== RESULT: %d passed, %d failed ===" % [_passed, _failed.size()])
	for f in _failed:
		print("  FAIL ", f)
	OS.remove_logger(_catcher)
	get_tree().quit(0 if _failed.is_empty() else 1)


func _collect_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for dir_path in TEST_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var names := Array(dir.get_files())
		names.sort()
		for file_name: String in names:
			if file_name.begins_with("test_") and file_name.ends_with(".gd"):
				out.append(dir_path.path_join(file_name))
	return out


func _run_file(path: String) -> void:
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		_failed.append("%s (failed to load / parse)" % path)
		return
	var methods: PackedStringArray = []
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not methods.has(n):
			if _filter == "" or path.contains(_filter) or n.contains(_filter):
				methods.append(n)
	if methods.is_empty():
		return
	print("\n-- ", path)
	for method in methods:
		var suite: TestCase = script.new()
		suite.name = path.get_file().get_basename()
		add_child(suite)
		_catcher.take()
		await suite.before_each()
		await suite.call(method)
		await suite.after_each()
		suite._cleanup_tracked()
		await get_tree().process_frame
		var errors := _catcher.take()
		for e in errors:
			suite._failures.append("engine error: " + e)
		if suite._failures.is_empty():
			_passed += 1
			print("  ok   ", method)
		else:
			_failed.append("%s::%s" % [path.get_file(), method])
			print("  FAIL ", method)
			for f in suite._failures:
				print("        - ", f)
		suite.queue_free()
		await get_tree().process_frame


func _on_watchdog() -> void:
	print("\n=== WATCHDOG: tests exceeded %ds, aborting ===" % int(WATCHDOG_SECONDS))
	get_tree().quit(2)
