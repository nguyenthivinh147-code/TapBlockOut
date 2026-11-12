extends SceneTree
## Builds an MSDF FontFile from the TextMeshPro font asset "Baloo Bhaijaan Regular 400 SDF" (color-cube-match-puzzle);
## that project lacks the source TTF, only the baked SDF atlas and glyph table remain.
## Only Latin, Vietnamese and Cyrillic glyphs are kept: the atlas also holds stray Devanagari, kana, kanji and Hangul
## glyphs from Unity's dynamic atlas, which would mix with the fallbacks inside one word and skip Hindi shaping. The
## kept glyphs (about a fifth of the 1024x2048 TMP atlas) are copied into a smaller packed atlas.
## Those scripts come from FALLBACKS, also written here: MSDF FontFiles that embed the OFL TTFs of art/fonts/ (not
## imported), with the atlas' pixel range and size so tmp_text.gdshader draws them alike, and with Baloo's ascent and
## descent, because Font.get_height() takes the tallest font of the chain and UnityUI lays text out at Baloo's height.
## Jua and M PLUS Rounded come from art/fonts/subset/ (tools/node/subset_fonts.mjs, run it first when texts change).
## Run: tools/godot.sh --headless --path . -s res://tools/gen_baloo_font.gd [-- --src=<path to .asset>]

const SRC := "E:/PROJECT HORUS/color-cube-match-puzzle/Assets/_Game/Resources_moved/Fonts/Baloo Bhaijaan Regular 400 SDF.asset"
const OUT := "res://assets/fonts/baloo.res"
## TMP atlas: single-channel SDF, padding 6, GradientScale 7 -> values 0..1 span 14 texels.
const PIXEL_RANGE := 14
const PADDING := 6
## Packed atlas width, and empty texels between glyphs: the TMP underlay samples up to 1.3 texels (plus half a texel
## of filtering) outside a glyph, which must land on empty space, not on a neighbour.
const ATLAS_WIDTH := 1024
const GAP := 2
## Baloo 2 (same design; Devanagari and missing punctuation), Jua (Hangul), M PLUS Rounded 1c (kana, kanji).
## lang: language the TextServer prefers the font for when several fallbacks have the glyph.
## Baloo 2 is the ExtraBold (wght 800) static instance of the variable art/fonts/Baloo2.ttf: at Regular the thin
## Devanagari strokes vanish under the TMP outline, which straddles the glyph edge (2026-11-12). Remake it with
## `uv run --with fonttools python -c "from fontTools.ttLib import TTFont; from fontTools.varLib import instancer;
## instancer.instantiateVariableFont(TTFont('art/fonts/Baloo2.ttf'), {'wght': 800}, updateFontNames=True)
## .save('art/fonts/Baloo2-ExtraBold.ttf')"`.
const FALLBACKS: Array[Dictionary] = [
	{"src": "res://art/fonts/Baloo2-ExtraBold.ttf", "out": "res://assets/fonts/baloo2.res", "lang": "hi"},
	{"src": "res://art/fonts/subset/Jua-Regular.ttf", "out": "res://assets/fonts/jua.res", "lang": "ko"},
	{"src": "res://art/fonts/subset/MPLUSRounded1c-Bold.ttf", "out": "res://assets/fonts/mplus_rounded.res", "lang": "ja"},
]


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
	if font.fallbacks.size() != FALLBACKS.size():
		quit(1)
		return
	var err := ResourceSaver.save(font, OUT)
	print("baloo: %d ký tự, lưu %s (err %d)" % [chars.size(), OUT, err])
	quit(0 if err == OK else 1)


## Glyph id = Unicode code point: without face data the TextServer looks glyphs up by character code.
func _build(atlas: Image, face: Dictionary, glyphs: Dictionary, chars: Dictionary) -> FontFile:
	var size := int(face.get("m_PointSize", "32"))
	var key := Vector2i(size, 0)
	var h := atlas.get_height()
	var font := FontFile.new()
	font.font_name = "Baloo"
	font.multichannel_signed_distance_field = true
	font.msdf_pixel_range = PIXEL_RANGE
	font.msdf_size = size
	font.set_cache_ascent(0, size, float(face.get("m_AscentLine", size)))
	font.set_cache_descent(0, size, -float(face.get("m_DescentLine", -12)))
	font.set_cache_underline_position(0, size, -float(face.get("m_UnderlineOffset", -8)))
	font.set_cache_underline_thickness(0, size, float(face.get("m_UnderlineThickness", 2)))
	var fallbacks: Array[Font] = []
	for def in FALLBACKS:
		var fb := _fallback(def, size, font.get_cache_ascent(0, size), font.get_cache_descent(0, size))
		if fb != null:
			fallbacks.append(fb)
	font.fallbacks = fallbacks
	# TMP glyph index -> its rect in the TMP atlas, padding included; character -> glyph index.
	var src := {}
	var kept := {}
	for uc in chars:
		var g: Dictionary = glyphs.get(chars[uc], {})
		if uc < 32 or g.is_empty() or _fallback_script(uc):
			continue
		font.set_glyph_advance(0, size, uc, Vector2(g["m_Metrics.m_HorizontalAdvance"], 0.0))
		if g["m_Metrics.m_Width"] <= 0.0:
			continue
		var w := int(g["m_GlyphRect.m_Width"])
		var gh := int(g["m_GlyphRect.m_Height"])
		var top := h - int(g["m_GlyphRect.m_Y"]) - gh
		src[chars[uc]] = Rect2i(int(g["m_GlyphRect.m_X"]) - PADDING, top - PADDING, w + 2 * PADDING, gh + 2 * PADDING)
		kept[uc] = chars[uc]
		font.set_glyph_offset(0, key, uc, Vector2(g["m_Metrics.m_HorizontalBearingX"] - PADDING, -g["m_Metrics.m_HorizontalBearingY"] - PADDING))
		font.set_glyph_size(0, key, uc, Vector2(w + 2 * PADDING, gh + 2 * PADDING))
		font.set_glyph_texture_idx(0, key, uc, 0)
	var packing := _pack(src)
	var pos: Dictionary = packing[0]
	var packed := Image.create_empty(ATLAS_WIDTH, packing[1], false, Image.FORMAT_L8)
	for gi in src:
		packed.blit_rect(atlas, src[gi], pos[gi])
	font.set_texture_image(0, key, 0, packed)
	for uc in kept:
		font.set_glyph_uv_rect(0, key, uc, Rect2(Vector2(pos[kept[uc]]), Vector2(src[kept[uc]].size)))
	print("baloo atlas: %dx%d -> %dx%d, %d glyphs" % [atlas.get_width(), h, ATLAS_WIDTH, packing[1], src.size()])
	return font


## Shelf packing, tallest first, GAP texels apart: [glyph index -> top-left in the packed atlas, atlas height].
static func _pack(rects: Dictionary) -> Array:
	var order: Array = rects.keys()
	order.sort_custom(func(a: int, b: int) -> bool:
		var ha: int = rects[a].size.y
		var hb: int = rects[b].size.y
		return ha > hb or (ha == hb and a < b))
	var pos := {}
	var x := GAP
	var y := GAP
	var shelf := 0
	for gi in order:
		var s: Vector2i = rects[gi].size
		if x + s.x + GAP > ATLAS_WIDTH:
			x = GAP
			y += shelf + GAP
			shelf = 0
		pos[gi] = Vector2i(x, y)
		x += s.x + GAP
		shelf = maxi(shelf, s.y)
	return [pos, y + shelf + GAP]


## Saves def.src as an MSDF FontFile at def.out (so baloo.res links it) with the given line metrics at msdf size.
static func _fallback(def: Dictionary, size: int, ascent: float, descent: float) -> FontFile:
	var data := FileAccess.get_file_as_bytes(str(def.src))
	if data.is_empty():
		push_error("Không đọc được font fallback " + str(def.src))
		return null
	var f := FontFile.new()
	f.data = data
	f.multichannel_signed_distance_field = true
	f.msdf_pixel_range = PIXEL_RANGE
	f.msdf_size = size
	f.set_language_support_override(str(def.lang), true)
	f.set_cache_ascent(0, size, ascent)
	f.set_cache_descent(0, size, descent)
	var err := ResourceSaver.save(f, str(def.out))
	if err != OK:
		push_error("Không lưu được %s (err %d)" % [def.out, err])
		return null
	f.take_over_path(str(def.out))
	print("fallback: %s -> %s" % [def.src, def.out])
	return f


## Devanagari up to Hangul Jamo, and CJK punctuation, kana, Hangul syllables, kanji, fullwidth forms.
static func _fallback_script(uc: int) -> bool:
	return (uc >= 0x0900 and uc < 0x1E00) or uc >= 0x2E80
