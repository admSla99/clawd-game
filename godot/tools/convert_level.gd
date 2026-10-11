# Converts levels/<id>.txt (written by export_levels.mjs) into levels/<id>.tscn with Level.build()
# (scripts/level.gd): Terrain and OneWay GridMaps, a Start marker, bugs and tokens. Other spawn
# characters are skipped for now.
# Run from godot/: godot --headless --script tools/convert_level.gd [-- <id>...]   (no ids = all)
extends SceneTree


func _init() -> void:
	# Bugs and tokens use the Game autoload, which exists only after the first frame.
	await process_frame
	var level_script: GDScript = load("res://scripts/level.gd")
	var ids := Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		ids = Array(DirAccess.get_files_at("res://levels")).filter(func(f): return f.ends_with(".txt")).map(func(f): return f.get_basename())

	var failed := false
	for id in ids:
		var txt := "res://levels/%s.txt" % id
		if not FileAccess.file_exists(txt):
			push_error("%s not found; run tools/export_levels.mjs first" % txt)
			failed = true
			continue
		var level: Node3D = level_script.build(FileAccess.get_file_as_string(txt).trim_suffix("\n").split("\n"))
		if not level.has_node("Start"):
			push_error("%s has no start '@'" % txt)
			failed = true
		var scene := PackedScene.new()
		scene.pack(level)
		var path := "res://levels/%s.tscn" % id
		var err := ResourceSaver.save(scene, path)
		var cells: int = level.get_node("Terrain").get_used_cells().size() + level.get_node("OneWay").get_used_cells().size()
		print("%s: %d cells, %d spawns, %s" % [path, cells, level.get_child_count() - 2, error_string(err)])
		failed = failed or err != OK
		level.free()
	quit(1 if failed else 0)
