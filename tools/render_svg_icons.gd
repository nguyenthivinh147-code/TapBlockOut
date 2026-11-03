extends SceneTree
## Rasterizes hand-drawn SVG icons (art/images/<name>.svg, 512x512 viewBox) to PNG in assets/ui/.
## Run: tools/godot.sh --headless --path . -s res://tools/render_svg_icons.gd -- [--size=256] [--out=<dir>] [name ...]
## No names = every booster icon. --out writes previews elsewhere (absolute path) instead of assets/ui/.

const SRC_DIR := "res://art/images/"
const OUT_DIR := "res://assets/ui/"
const VIEWBOX := 512.0
const NAMES := ["booster_hint", "booster_move", "booster_smash"]


func _initialize() -> void:
	var size := 256
	var out := OUT_DIR
	var names: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			size = int(a.substr(7))
		elif a.begins_with("--out="):
			out = a.substr(6)
		else:
			names.append(a)
	if names.is_empty():
		names = NAMES.duplicate()
	if not out.ends_with("/"):
		out += "/"
	var failed := 0
	for n in names:
		var svg: String = FileAccess.get_file_as_string(SRC_DIR + n + ".svg")
		if svg == "":
			push_error("Không đọc được %s%s.svg" % [SRC_DIR, n])
			failed += 1
			continue
		var img := Image.new()
		if img.load_svg_from_string(svg, size / VIEWBOX) != OK:
			push_error("SVG lỗi: " + n)
			failed += 1
			continue
		var path: String = out + n + ".png"
		if img.save_png(path) != OK:
			push_error("Không ghi được " + path)
			failed += 1
			continue
		print("%s %dx%d" % [path, img.get_width(), img.get_height()])
	quit(1 if failed > 0 else 0)
