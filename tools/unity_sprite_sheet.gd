extends SceneTree
## Contact sheet of the sprites in data/ui_unity/_sprites.json, each tile labelled with its key, for picking
## sprites when a screen has no prefab. Needs a window (not --headless):
## tools/godot.sh --path . --resolution 1600x1600 -s res://tools/unity_sprite_sheet.gd -- [--filter=UI_Maincenter] [--out=res://tests/shots/sprites.png]

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UImage := preload("res://src/ui/u_image.gd")
const TILE := Vector2(190, 170)
const COLS := 8


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var filter := ""
	var out := "res://tests/shots/sprites.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.substr(9)
		elif a.begins_with("--out="):
			out = a.substr(6)
	var f := FileAccess.open("res://data/ui_unity/_sprites.json", FileAccess.READ)
	var table: Dictionary = JSON.parse_string(f.get_as_text())
	var keys: Array = table.keys().filter(func(k: String) -> bool: return filter == "" or k.contains(filter))
	keys.sort()
	var vp := SubViewport.new()
	vp.size = Vector2i(int(TILE.x) * COLS, int(TILE.y) * ceili(keys.size() / float(COLS)))
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("3a3a48")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	for i in keys.size():
		var cell := Vector2(i % COLS, i / COLS) * TILE
		var s := UnityUI.sprite_info(str(keys[i]))
		if not s.is_empty():
			var img := UImage.new()
			img.position = cell + Vector2(10, 6)
			img.size = Vector2(TILE.x - 20, TILE.y - 46)
			img.preserve_aspect = true
			img.set_texture(s.tex, s.region)
			vp.add_child(img)
		var l := Label.new()
		l.text = str(keys[i]).replace("Resources_moved_UI_Maincenter:", "m:").replace("Resources_UI_Maincenter:", "r:")
		l.position = cell + Vector2(4, TILE.y - 40)
		l.size = Vector2(TILE.x - 8, 38)
		l.add_theme_font_size_override("font_size", 14)
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		vp.add_child(l)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("sheet: %d sprite -> %s" % [keys.size(), out])
	quit(0)
