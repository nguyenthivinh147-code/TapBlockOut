extends RefCounted
## Assets trimmed for the APK size: subset CJK fonts and the boot splash.
const T := preload("res://tests/t.gd")

## Same scan as tools/node/subset_fonts.mjs (SOURCES, EXTENSIONS); ASCII is always kept there.
const SOURCES: Array[String] = ["res://i18n", "res://scenes", "res://data", "res://src"]
const EXTENSIONS: Array[String] = ["csv", "tscn", "tres", "json", "gd"]
## Shipped subset font -> full OFL font it was cut from.
const SUBSETS := {
	"res://assets/fonts/jua.res": "res://art/fonts/Jua-Regular.ttf",
	"res://assets/fonts/mplus_rounded.res": "res://art/fonts/MPLUSRounded1c-Bold.ttf",
}


## Code point -> first file using it, for every non-ASCII character in the sources.
func _scan(dir_path: String, re: RegEx, into: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan(dir_path + "/" + sub, re, into)
	for fname in dir.get_files():
		if not fname.get_extension() in EXTENSIONS:
			continue
		for m in re.search_all(FileAccess.get_file_as_string(dir_path + "/" + fname)):
			for c in m.get_string():
				if not into.has(c.unicode_at(0)):
					into[c.unicode_at(0)] = dir_path.path_join(fname)


## A text using a character the full font has but the subset lacks would fall back to the system font.
## Fix: node tools/node/subset_fonts.mjs, then tools/godot.sh --headless --path . -s res://tools/gen_baloo_font.gd
func test_subset_fonts_keep_used_chars(t: T) -> void:
	var used := {}
	_scan_all(used)
	t.ok(used.size() > 500, "quét được ký tự ngoài ASCII (%d)" % used.size())
	for shipped_path: String in SUBSETS:
		var shipped: FontFile = load(shipped_path)
		var full := FontFile.new()
		full.data = FileAccess.get_file_as_bytes(SUBSETS[shipped_path])
		t.ok(full.data.size() > shipped.data.size(), shipped_path.get_file() + " là bản subset")
		var missing: Array[String] = []
		for c: int in used:
			if full.has_char(c) and not shipped.has_char(c):
				missing.append("U+%04X %s (%s)" % [c, String.chr(c), used[c]])
		t.eq(missing, [], shipped_path.get_file() + " có mọi ký tự text dùng")


func _scan_all(used: Dictionary) -> void:
	var re := RegEx.create_from_string("[^\u0001-\u007F]+")
	for d in SOURCES:
		_scan(d, re, used)


## Godot loads the boot splash before the WebP/JPG loaders exist: anything but PNG shows the default splash.
## It is stored raw by the export, so importing it as a texture would only add an unused .ctex.
func test_boot_splash_png_not_imported(t: T) -> void:
	var path := str(ProjectSettings.get_setting("application/boot_splash/image", ""))
	t.ok(path.ends_with(".png"), "boot splash là PNG: " + path)
	t.ok(FileAccess.file_exists(path), "file boot splash tồn tại")
	var cfg := ConfigFile.new()
	t.eq(cfg.load(path + ".import"), OK, "có file .import")
	t.eq(cfg.get_value("remap", "importer", ""), "skip", "boot splash không import thành texture")
