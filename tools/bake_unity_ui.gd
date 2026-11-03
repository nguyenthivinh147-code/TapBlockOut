extends SceneTree
## Bakes every data/ui_unity/<Layer>.json (tools/unity_ui_export.mjs) into scenes/unity/<Layer>.tscn: a Canvas fitted
## to 720x1280 holding the prefab root as plain nodes. UnityUI.build instances these scenes, so after baking a layer
## the scene is what the game shows; edit it in the editor, re-bake only after a new export (it overwrites edits).
## Run: tools/godot.sh --headless --path . -s res://tools/bake_unity_ui.gd [-- Layer ...]

const UnityUI := preload("res://src/ui/unity_ui.gd")

const VIEW := Vector2(720, 1280)


func _initialize() -> void:
	var only := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(UnityUI.BAKED))
	var host := Control.new()
	host.size = VIEW
	root.add_child(host)
	var failed := 0
	for f in DirAccess.get_files_at(UnityUI.DIR):
		if not f.ends_with(".json") or f.begins_with("_"):
			continue
		var layer := f.get_basename()
		if not only.is_empty() and not only.has(layer):
			continue
		if not _bake(host, layer):
			failed += 1
	host.free()
	print("bake_unity_ui: xong, %d lỗi" % failed)
	quit(1 if failed > 0 else 0)


func _bake(host: Control, layer: String) -> bool:
	var canvas := UnityUI.make_canvas(layer)
	host.add_child(canvas)
	var s := UnityUI.canvas_scale(VIEW)
	canvas.scale = Vector2(s, s)
	canvas.size = VIEW / s
	UnityUI.relayout(canvas.get_child(0) as Control)
	host.remove_child(canvas)
	for n in canvas.find_children("*", "", true, false):
		n.owner = canvas
		# The scene holds the children; a copy of their specs in every ancestor would only bloat it.
		if n.has_meta("u"):
			var spec: Dictionary = (n.get_meta("u") as Dictionary).duplicate()
			spec.erase("ch")
			n.set_meta("u", spec)
	var ps := PackedScene.new()
	var err := ps.pack(canvas)
	if err == OK:
		err = ResourceSaver.save(ps, UnityUI.BAKED + layer + ".tscn")
	canvas.free()
	if err != OK:
		push_error("bake_unity_ui: %s lỗi %d" % [layer, err])
		return false
	print("  ", layer)
	return true
