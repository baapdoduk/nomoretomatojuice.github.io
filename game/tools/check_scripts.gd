extends Node
## Loads every .gd / .tscn / .tres in the project and reports load/parse failures.
## Runs as a scene (so autoload identifiers resolve):
##   godot --headless --path game res://tools/check_scripts.tscn

var _bad: PackedStringArray = []

func _ready() -> void:
	var files: PackedStringArray = []
	_walk("res://", files)
	for path in files:
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if res == null:
			_bad.append(path)
		elif res is GDScript and not (res as GDScript).can_instantiate():
			_bad.append(path + " (cannot instantiate: parse/compile error)")
	print("checked %d resources, %d failed" % [files.size(), _bad.size()])
	for b in _bad:
		print("  BAD ", b)
	get_tree().quit(0 if _bad.is_empty() else 1)

func _walk(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub.begins_with(".") or (dir_path == "res://" and sub == "tools"):
			continue
		_walk(dir_path.path_join(sub), out)
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			out.append(dir_path.path_join(f))
