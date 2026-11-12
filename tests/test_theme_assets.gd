extends RefCounted
## UI art theme (src/ui/theme_assets.gd, docs/UI_THEME_PASTEL.md): a texture with a twin under assets/themes/<theme>/
## loads as the twin from load(), scene ext_resources and the atlas helper; every twin keeps its source's size and
## import settings, so atlas regions, 9-slice margins and size limits stay valid.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const ThemeAssets := preload("res://src/ui/theme_assets.gd")
const Loader := preload("res://src/ui/theme_loader.gd")

const SRC := "res://assets/ui/cc/Popup2.png"
const SWAP := "res://assets/ui/cc/light1.png"
const SCENE := "res://scenes/unity/BoosterTutorialLayer.tscn"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _fresh(path: String) -> Texture2D:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D


## Width and height from a PNG header (no decode).
func _png_size(path: String) -> Vector2i:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return Vector2i(-1, -1)
	f.big_endian = true
	f.seek(16)
	return Vector2i(f.get_32(), f.get_32())


func _pngs(dir: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "png":
			out.append(dir + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_pngs(dir + d + "/"))
	return out


func _params(import_path: String) -> String:
	var text := FileAccess.get_file_as_string(import_path)
	var at := text.find("[params]")
	return text.substr(at) if at >= 0 else ""


func test_theme_registered_at_boot(t: T) -> void:
	var node: Node = _tree().root.get_node_or_null("ThemeAssets")
	t.ok(node != null, "autoload ThemeAssets")
	if node == null:
		return
	t.eq(node.get("theme"), Config.UI_THEME, "theme = Config.UI_THEME")
	var map := ThemeAssets.twins(Config.UI_THEME)
	t.ok(Config.UI_THEME == "" or not map.is_empty(), "theme %s has twins" % Config.UI_THEME)
	t.ok(node.get("_loader") != null or map.is_empty(), "loader registered")
	t.eq(ThemeAssets.twins(""), {}, "empty theme: base art")
	t.eq(ThemeAssets.twins("no_such_theme"), {}, "missing theme: base art")


func test_loader_swaps_load_scene_and_atlas(t: T) -> void:
	var want := _fresh(SWAP).get_size()
	t.ok(_fresh(SRC).get_size() != want, "test pair differs in size")
	var loader := Loader.new({SRC: SWAP})
	ResourceLoader.add_resource_format_loader(loader, true)
	var direct := _fresh(SRC)
	t.eq(direct.get_size(), want, "load(): twin")
	var scene := ResourceLoader.load(SCENE, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var root := scene.instantiate()
	var found := 0
	for c in root.find_children("*", "", true, false):
		var tex: Variant = c.get("tex")
		if tex is Texture2D and (tex as Texture2D).get_size() == want:
			found += 1
	t.ok(found > 0, "scene ext_resource: twin")
	root.free()
	ResourceLoader.remove_resource_format_loader(loader)
	t.ok(_fresh(SRC).get_size() != want, "loader removed: source again")


## Every twin file of the theme is imported (twins() skips the others silently) and matches its source.
func test_twins_match_sources(t: T) -> void:
	var map := ThemeAssets.twins(Config.UI_THEME)
	var dir := ThemeAssets.THEMES + Config.UI_THEME + "/"
	var files := 0
	for f in _pngs(dir):
		files += 1
		t.ok(map.values().has(f), "%s: imported" % f)
	t.eq(map.size(), files, "every twin in use")
	for src in map:
		var twin: String = map[src]
		t.ok(FileAccess.file_exists(src + ".import"), "%s: source exists" % src)
		t.eq(_png_size(twin), _png_size(src), "%s: same size" % twin)
		t.ok(FileAccess.file_exists(twin + ".import"), "%s: imported" % twin)
		t.eq(_params(twin + ".import"), _params(src + ".import"), "%s: same import params" % twin)
