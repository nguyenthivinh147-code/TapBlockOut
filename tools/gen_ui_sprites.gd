extends SceneTree
## Cắt nút viên thuốc từ atlas Figma rồi thu về cao 96px để bo tròn đúng tỉ lệ khi 9-slice.
## Chạy: tools/godot.sh --headless --path . -s res://tools/gen_ui_sprites.gd; sau đó --import.

const ATLAS := "res://assets/ui/figma/atlas_main.png"
const OUT := "res://assets/ui/figma/pill/"
const HEIGHT := 96
const PILLS := {
	"pill_green": Rect2i(0, 816, 380, 168),
	"pill_red": Rect2i(0, 988, 380, 168),
	"pill_yellow": Rect2i(0, 1160, 380, 168),
	"pill_purple": Rect2i(384, 1160, 368, 168),
	"pill_blue": Rect2i(0, 1332, 380, 168),
	"pill_gray": Rect2i(384, 1554, 380, 168),
}


func _initialize() -> void:
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(ATLAS))
	if atlas == null or atlas.is_empty():
		push_error("Không đọc được " + ATLAS)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for pill_name in PILLS:
		var r: Rect2i = PILLS[pill_name]
		var img := atlas.get_region(r)
		var w := roundi(float(r.size.x) * HEIGHT / float(r.size.y))
		img.resize(w, HEIGHT, Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path("%s%s_%d.png" % [OUT, pill_name, HEIGHT]))
		print("%s -> %dx%d" % [pill_name, w, HEIGHT])
	quit(0)
