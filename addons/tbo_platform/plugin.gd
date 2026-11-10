@tool
extends EditorPlugin

const ExportPlugin := preload("res://addons/tbo_platform/export_plugin.gd")

var _export_plugin: EditorExportPlugin
var _scene_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = ExportPlugin.new()
	add_export_plugin(_export_plugin)
	_scene_plugin = DeflatedScenes.new()
	add_export_plugin(_scene_plugin)


func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null
	if _scene_plugin != null:
		remove_export_plugin(_scene_plugin)
		_scene_plugin = null


## Android exports each text scene (.tscn) as a binary scene named <path>.res instead of Godot's own <name>.scn.
## The Android exporter stores every .scn without zip compression ("binary scenes are usually already compressed"),
## but Godot's text-to-binary conversion does not compress them, so the UI scenes shipped at full size. A .res is
## deflated in the APK (2.6 MB -> 0.56 MB on 2026-11-10) and loads as fast as .scn. Text scenes load about 3.5x
## slower, and RSCC (ResourceSaver.FLAG_COMPRESS) compresses 4 KB blocks only (1.6 MB).
## Lives in plugin.gd, which export_presets.cfg already keeps out of the build.
class DeflatedScenes extends EditorExportPlugin:
	func _get_name() -> String:
		return "TboDeflatedScenes"


	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		if not path.ends_with(".tscn"):
			return
		var scene := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		if scene == null:
			push_warning("TboDeflatedScenes: could not load %s, exported as .scn" % path)
			return
		# Pack again as the editor does on save: a text scene saved straight to binary keeps one name entry per
		# property use (2.5x bigger). The result matches Godot's own conversion apart from generated sub-resource ids.
		var root := scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
		if root == null:
			push_warning("TboDeflatedScenes: could not instantiate %s, exported as .scn" % path)
			return
		var packed := PackedScene.new()
		var err := packed.pack(root)
		root.free()
		if err != OK:
			push_warning("TboDeflatedScenes: could not pack %s (error %d), exported as .scn" % [path, err])
			return
		var tmp := EditorInterface.get_editor_paths().get_cache_dir().path_join("tbo_export_scene.res")
		err = ResourceSaver.save(packed, tmp)
		if err != OK:
			push_warning("TboDeflatedScenes: could not save %s (error %d), exported as .scn" % [path, err])
			return
		add_file(path + ".res", FileAccess.get_file_as_bytes(tmp), true)
