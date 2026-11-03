extends SceneTree
## Builds an MSDF FontFile from the TextMeshPro font asset "Baloo Bhaijaan Regular 400 SDF" (color-cube-match-puzzle);
## that project lacks the source TTF, only the baked SDF atlas and glyph table remain.
## Run: tools/godot.sh --headless --path . -s res://tools/gen_baloo_font.gd [-- --src=<path to .asset>]

const SRC := "E:/PROJECT HORUS/color-cube-match-puzzle/Assets/_Game/Resources_moved/Fonts/Baloo Bhaijaan Regular 400 SDF.asset"
const OUT := "res://assets/fonts/baloo.res"
## TMP atlas: single-channel SDF, padding 6, GradientScale 7 -> values 0..1 span 14 texels.
const PIXEL_RANGE := 14
const PADDING := 6


func _initialize() -> void:
	var src := SRC
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.substr(6)
	var f := FileAccess.open(src, FileAccess.READ)
	if f == null:
		push_error("Không đọc được " + src)
		quit(1)
		return
	var tex := {}
	var face := {}
	var glyphs := {}
	var chars := {}
	var table := ""
	var sub := ""
	var cur := {}
	var hex := ""
	while not f.eof_reached():
		var line := f.get_line()
		var t := line.strip_edges()
		var indent := line.length() - line.lstrip(" ").length()
		if t.begins_with("--- "):
			table = ""
			continue
		if indent == 2 and not t.begins_with("- "):
			table = ""
			if t.begins_with("_typelessdata: "):
				hex = t.substr(15)
			elif t.begins_with("m_Width: ") or t.begins_with("m_Height: "):
				var kv := t.split(": ")
				tex[kv[0]] = int(kv[1])
			elif t == "m_GlyphTable:" or t == "m_CharacterTable:":
				table = t
		elif indent == 4 and table == "" and line.begins_with("    m_") and t.contains(": "):
			var kv := t.split(": ")
			face[kv[0]] = kv[1]
		if table == "m_GlyphTable:":
			if t.begins_with("- m_Index: "):
				cur = {}
				glyphs[int(t.substr(11))] = cur
			elif t == "m_Metrics:" or t == "m_GlyphRect:":
				sub = t.trim_suffix(":")
			elif indent == 6 and t.contains(": "):
				var kv := t.split(": ")
				cur[sub + "." + kv[0]] = float(kv[1])
		elif table == "m_CharacterTable:":
			if t.begins_with("- m_ElementType"):
				cur = {}
			elif t.begins_with("m_Unicode: "):
				cur["unicode"] = int(t.substr(11))
			elif t.begins_with("m_GlyphIndex: "):
				chars[cur["unicode"]] = int(t.substr(14))
	if hex.is_empty() or chars.is_empty():
		push_error("Thiếu atlas hoặc bảng ký tự trong " + src)
		quit(1)
		return
	# TMP stores Alpha8 bottom-up; flip to Godot top-left origin.
	var atlas := Image.create_from_data(tex["m_Width"], tex["m_Height"], false, Image.FORMAT_L8, hex.hex_decode())
	atlas.flip_y()
	var font := _build(atlas, face, glyphs, chars)
	var err := ResourceSaver.save(font, OUT)
	print("baloo: %d ký tự, lưu %s (err %d)" % [chars.size(), OUT, err])
	quit(0 if err == OK else 1)


## Glyph id = Unicode code point: without face data the TextServer looks glyphs up by character code.
func _build(atlas: Image, face: Dictionary, glyphs: Dictionary, chars: Dictionary) -> FontFile:
	var size := int(face.get("m_PointSize", "32"))
	var key := Vector2i(size, 0)
	var h := float(atlas.get_height())
	var p := float(PADDING)
	var font := FontFile.new()
	font.font_name = "Baloo"
	font.multichannel_signed_distance_field = true
	font.msdf_pixel_range = PIXEL_RANGE
	font.msdf_size = size
	font.set_texture_image(0, key, 0, atlas)
	font.set_cache_ascent(0, size, float(face.get("m_AscentLine", size)))
	font.set_cache_descent(0, size, -float(face.get("m_DescentLine", -12)))
	font.set_cache_underline_position(0, size, -float(face.get("m_UnderlineOffset", -8)))
	font.set_cache_underline_thickness(0, size, float(face.get("m_UnderlineThickness", 2)))
	for uc in chars:
		var g: Dictionary = glyphs.get(chars[uc], {})
		if uc < 32 or g.is_empty():
			continue
		font.set_glyph_advance(0, size, uc, Vector2(g["m_Metrics.m_HorizontalAdvance"], 0.0))
		var w: float = g["m_GlyphRect.m_Width"]
		var gh: float = g["m_GlyphRect.m_Height"]
		if g["m_Metrics.m_Width"] <= 0.0:
			continue
		var top: float = h - g["m_GlyphRect.m_Y"] - gh
		font.set_glyph_offset(0, key, uc, Vector2(g["m_Metrics.m_HorizontalBearingX"] - p, -g["m_Metrics.m_HorizontalBearingY"] - p))
		font.set_glyph_size(0, key, uc, Vector2(w + 2.0 * p, gh + 2.0 * p))
		font.set_glyph_uv_rect(0, key, uc, Rect2(g["m_GlyphRect.m_X"] - p, top - p, w + 2.0 * p, gh + 2.0 * p))
		font.set_glyph_texture_idx(0, key, uc, 0)
	return font
