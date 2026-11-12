extends Node
## UI art theme (autoload ThemeAssets, first game autoload). A texture res://assets/<path> that has a twin
## res://assets/themes/<theme>/<path> is drawn with the twin on every screen; files without a twin keep the base art.
## The theme is Config.UI_THEME; debug builds take the user arg --theme=<name> (--theme= gives the base art).
## Code colours of the theme (ThemeKit, scene gradients) live on the branch, not here.

const Config := preload("res://src/config.gd")
const Loader := preload("res://src/ui/theme_loader.gd")
const ROOT := "res://assets/"
const THEMES := "res://assets/themes/"

var theme := ""
var _loader: ResourceFormatLoader = null


func _init() -> void:
	theme = Config.UI_THEME
	if OS.is_debug_build():
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--theme="):
				theme = a.substr(8)
	var map := twins(theme)
	if map.is_empty():
		return
	_loader = Loader.new(map)
	ResourceLoader.add_resource_format_loader(_loader, true)


func _exit_tree() -> void:
	if _loader != null:
		ResourceLoader.remove_resource_format_loader(_loader)
		_loader = null


## Original path -> twin path for every texture of a theme ({} for "" or a missing theme).
static func twins(theme_name: String) -> Dictionary:
	var out := {}
	if theme_name == "":
		return out
	_scan(THEMES + theme_name + "/", "", out)
	return out


static func _scan(base: String, rel: String, out: Dictionary) -> void:
	var dir := base + rel
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		# Exported builds list "x.png.import" instead of "x.png".
		var name := f.trim_suffix(".import").trim_suffix(".remap")
		if not Loader.EXTS.has(name.get_extension().to_lower()):
			continue
		# A twin not imported yet (fresh clone before the editor ran) keeps the base art instead of failing to load.
		if ResourceLoader.exists(dir + name):
			out[ROOT + rel + name] = dir + name
	for d in DirAccess.get_directories_at(dir):
		_scan(base, rel + d + "/", out)
