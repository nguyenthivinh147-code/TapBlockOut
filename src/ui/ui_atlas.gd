extends RefCounted
## Sprite không chữ cắt từ các atlas Figma (page "02 · Foundations" > Components) và vài atlas Unity.
## Dùng: const UiAtlas := preload("res://src/ui/ui_atlas.gd"); UiAtlas.tex("pill_green"); UiAtlas.box("pill_green", Vector4i(...)).
## Toạ độ lấy từ bounds node trong Figma; sửa atlas thì cập nhật bảng REGIONS.

const DIR := "res://assets/ui/figma/"
## Tên file trong DIR, hoặc đường dẫn res:// đầy đủ cho atlas nằm ngoài DIR.
const SHEETS := {
	"main": "atlas_main.png",
	"popup": "atlas_popup.png",
	"winlose": "atlas_winlose.png",
	"shop": "atlas_shop.png",
	"winstreak": "res://assets/ui/cc/UI_Winstreak_Atlas.png",
	"maincenter": "res://assets/ui/cc/Resources_moved_UI_Maincenter.png",
}

## tên -> [sheet, Rect2(x, y, w, h)]
const REGIONS := {
	# nút viên thuốc
	"pill_green": ["main", Rect2(0, 816, 380, 168)],
	"pill_green_white": ["main", Rect2(384, 816, 368, 168)],
	"pill_red": ["main", Rect2(0, 988, 380, 168)],
	"pill_red_white": ["main", Rect2(384, 988, 368, 168)],
	"pill_yellow": ["main", Rect2(0, 1160, 380, 168)],
	"pill_purple": ["main", Rect2(384, 1160, 368, 168)],
	"pill_blue": ["main", Rect2(0, 1332, 380, 168)],
	"pill_cyan": ["main", Rect2(0, 1504, 380, 120)],
	"pill_gray": ["main", Rect2(384, 1554, 380, 168)],
	"pill_violet": ["main", Rect2(384, 1731, 380, 144)],
	# tab hai nửa (Profile: Avatar | Frame); _l bo góc trái, _r bo góc phải
	"tab_l_off": ["main", Rect2(0, 1628, 358, 102)],
	"tab_l_on": ["main", Rect2(0, 1734, 358, 102)],
	"tab_r_off": ["main", Rect2(0, 1840, 358, 102)],
	"tab_r_on": ["main", Rect2(0, 1946, 358, 102)],
	# icon bật tắt trong Settings: bật màu xanh lá, tắt xám gạch chéo
	"tog_sound_on": ["main", Rect2(200, 628, 96, 80)],
	"tog_sound_off": ["main", Rect2(300, 624, 96, 84)],
	"tog_vibrance_on": ["main", Rect2(0, 721, 96, 88)],
	"tog_vibrance_off": ["main", Rect2(100, 721, 96, 88)],
	"tog_music_on": ["main", Rect2(200, 720, 96, 88)],
	"tog_music_off": ["main", Rect2(300, 720, 96, 88)],
	# tiêu đề, panel nhỏ
	"label_purple": ["main", Rect2(384, 1332, 368, 108)],
	"label_yellow": ["main", Rect2(384, 1444, 368, 106)],
	"panel_cream_tall": ["main", Rect2(1168, 524, 185, 285)],
	"panel_purple_star": ["main", Rect2(937, 524, 226, 144)],
	"panel_yellow_star": ["main", Rect2(937, 672, 226, 140)],
	"tile_white": ["main", Rect2(756, 1160, 168, 168)],
	"tile_lavender": ["main", Rect2(928, 1160, 168, 168)],
	"tile_gray": ["main", Rect2(1100, 1174, 168, 140)],
	"tile_green": ["main", Rect2(1100, 1579, 168, 140)],
	"tile_purple": ["main", Rect2(756, 1332, 168, 152)],
	"tile_brown": ["main", Rect2(928, 1332, 168, 152)],
	"tile_blue": ["main", Rect2(1100, 1332, 168, 152)],
	"frame_orange": ["main", Rect2(756, 816, 168, 168)],
	"frame_pink": ["main", Rect2(928, 816, 168, 168)],
	"frame_cyan": ["main", Rect2(756, 988, 168, 168)],
	"frame_green": ["main", Rect2(928, 988, 168, 168)],
	"bar_rainbow": ["main", Rect2(1496, 524, 552, 124)],
	"bar_green": ["main", Rect2(768, 1488, 500, 60)],
	"ribbon_pink_horns": ["main", Rect2(1358, 652, 690, 260)],
	"bubble_cream": ["main", Rect2(938, 1765, 168, 116)],
	"hand_tap": ["main", Rect2(768, 1565, 168, 168)],
	# mốc level (kim cương)
	"node_gray": ["main", Rect2(1511, 1831, 216, 216)],
	"node_green": ["main", Rect2(1749, 1751, 282, 282)],
	# icon lớn
	"big_house": ["main", Rect2(0, 0, 256, 256)],
	"big_shop": ["main", Rect2(260, 0, 256, 256)],
	"big_trophy": ["main", Rect2(520, 0, 256, 256)],
	"big_coin": ["main", Rect2(780, 0, 256, 256)],
	"big_settings": ["main", Rect2(1040, 0, 256, 256)],
	"big_tv": ["main", Rect2(1300, 0, 256, 256)],
	"big_calendar": ["main", Rect2(1560, 0, 256, 256)],
	"big_clock": ["main", Rect2(1824, 16, 224, 224)],
	"big_heart_inf": ["main", Rect2(0, 260, 256, 256)],
	"big_heart": ["main", Rect2(260, 260, 256, 256)],
	"big_heart_broken": ["main", Rect2(520, 260, 256, 256)],
	"big_noads": ["main", Rect2(780, 260, 256, 256)],
	"hex_green": ["main", Rect2(1040, 288, 201, 200)],
	"hex_blue": ["main", Rect2(1242, 288, 200, 200)],
	"hex_gray": ["main", Rect2(1443, 288, 201, 200)],
	"hex_red": ["main", Rect2(1645, 288, 200, 200)],
	"hex_purple": ["main", Rect2(1847, 288, 201, 200)],
	# ribbon, sao, kèn (kết quả thắng/thua)
	"ribbon_red": ["winlose", Rect2(0, 0, 556, 140)],
	"ribbon_blue": ["winlose", Rect2(0, 142, 556, 140)],
	"ribbon_orange": ["winlose", Rect2(0, 520, 646, 130)],
	"star_gold": ["winlose", Rect2(10, 302, 180, 180)],
	"star_gray": ["winlose", Rect2(216, 302, 180, 180)],
	"horn_gold": ["winlose", Rect2(418, 310, 192, 170)],
	"leaf_green": ["winlose", Rect2(606, 0, 106, 140)],
	# shop
	"frame_shop_orange": ["shop", Rect2(8, 10, 495, 260)],
	"frame_shop_blue": ["shop", Rect2(10, 296, 192, 258)],
	"strip_blue": ["shop", Rect2(514, 0, 510, 90)],
	"strip_yellow": ["shop", Rect2(514, 90, 510, 90)],
	"banner_coins": ["shop", Rect2(424, 448, 600, 336)],
	"awning": ["shop", Rect2(0, 806, 1024, 218)],
	# popup atlas
	"paper_rings": ["popup", Rect2(424, 722, 232, 300)],
	# hộp quà Road Trip (đỏ nhỏ, xanh vừa, tím lớn): ô vuông ôm sát từng hộp, đo theo alpha, không có trong
	# _sprites.json (Unity chỉ xuất hộp tím, UI_Winstreak_Atlas_6, ô 200x200 rộng hơn)
	"gift_red": ["winstreak", Rect2(26, 874, 149, 149)],
	"gift_blue": ["winstreak", Rect2(224, 856, 161, 161)],
	"gift_purple": ["winstreak", Rect2(418, 839, 181, 181)],
	# Unity atlas: blue tile with a flat top and a rounded lip at the bottom (bounds measured by alpha).
	# Road Trip chip turns it with box_cw so the flat edge sits on the screen's right edge.
	"tile_blue_mc": ["maincenter", Rect2(1100, 1332, 168, 150)],
}

static var _sheet_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}


static func has(region: String) -> bool:
	return REGIONS.has(region)


static func _sheet(sheet: String) -> Texture2D:
	if not _sheet_cache.has(sheet):
		var file := str(SHEETS[sheet])
		_sheet_cache[sheet] = load(file if file.begins_with("res://") else DIR + file) as Texture2D
	return _sheet_cache[sheet]


## Sprite theo tên, hoặc null khi tên sai hoặc atlas chưa nạp được.
static func tex(region: String) -> Texture2D:
	if _tex_cache.has(region):
		return _tex_cache[region]
	if not REGIONS.has(region):
		return null
	var r: Array = REGIONS[region]
	var sheet := _sheet(str(r[0]))
	if sheet == null:
		return null
	var t := AtlasTexture.new()
	t.atlas = sheet
	t.region = r[1]
	_tex_cache[region] = t
	return t


static func size_of(region: String) -> Vector2:
	if not REGIONS.has(region):
		return Vector2.ZERO
	return (REGIONS[region] as Array)[1].size


## Whole sheet of a sprite and its rect in it, for u_image.gd's set_texture (it draws a region of a whole texture).
static func sheet_of(region: String) -> Texture2D:
	if not REGIONS.has(region):
		return null
	return _sheet(str((REGIONS[region] as Array)[0]))


static func rect_of(region: String) -> Rect2:
	if not REGIONS.has(region):
		return Rect2()
	return (REGIONS[region] as Array)[1]


## 9-slice từ sprite. margin = (trái, trên, phải, dưới) tính theo pixel gốc của sprite; content = lề nội dung.
static func box(region: String, margin: Vector4, content: Vector4 = Vector4(-1, -1, -1, -1)) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	var r: Array = REGIONS.get(region, [])
	if r.is_empty():
		return s
	s.texture = _sheet(str(r[0]))
	s.region_rect = r[1]
	s.texture_margin_left = margin.x
	s.texture_margin_top = margin.y
	s.texture_margin_right = margin.z
	s.texture_margin_bottom = margin.w
	if content.x >= 0.0:
		s.content_margin_left = content.x
		s.content_margin_top = content.y
		s.content_margin_right = content.z
		s.content_margin_bottom = content.w
	return s


## 9-slice from a sprite turned 90° clockwise (the sprite's top edge ends up on the right).
## margin = (left, top, right, bottom) in the turned sprite's pixels. If the atlas pixels can't be read
## (e.g. a renderer that keeps no images), falls back to the unturned sprite with the margins mapped back.
static func box_cw(region: String, margin: Vector4) -> StyleBoxTexture:
	var key := region + "@cw"
	var t: Texture2D = _tex_cache.get(key)
	if t == null:
		var img := _region_image(region)
		if img == null:
			return box(region, Vector4(margin.y, margin.z, margin.w, margin.x))
		img.rotate_90(CLOCKWISE)
		t = ImageTexture.create_from_image(img)
		_tex_cache[key] = t
	var s := StyleBoxTexture.new()
	s.texture = t
	s.texture_margin_left = margin.x
	s.texture_margin_top = margin.y
	s.texture_margin_right = margin.z
	s.texture_margin_bottom = margin.w
	return s


## Decompressed copy of a sprite's pixels, or null when the name is wrong or the atlas can't be read.
static func _region_image(region: String) -> Image:
	var r: Array = REGIONS.get(region, [])
	if r.is_empty():
		return null
	var sheet := _sheet(str(r[0]))
	if sheet == null:
		return null
	var full := sheet.get_image()
	if full == null or full.is_empty():
		return null
	if full.is_compressed():
		full.decompress()
	return full.get_region(Rect2i(r[1]))


static func clear_cache() -> void:
	_sheet_cache.clear()
	_tex_cache.clear()
