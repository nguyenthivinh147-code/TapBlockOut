extends RefCounted
## Mảnh UI dùng chung của các màn Leaderboard: huy hiệu league, hàng người chơi, podium, định dạng số.
## Hàng người chơi là dict của Game.lb_view / lb_world_view: {rank, name, avatar, frame, flag, points, me}.
## Prefab pieces (color-cube-match-puzzle): card() / fill_card() build PlayerLeaderboardItem rows, set_league_icon()
## puts a LeaderboardRankBadgesSO trophy on an Image. The older ThemeKit pieces below stay for other screens.

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Profile := preload("res://src/ui/profile.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const UImage := preload("res://src/ui/u_image.gd")

const ITEM := "PlayerLeaderboardItem"
## LeaderboardRankBadgesSO has Bronze, Silver, Gold, Platinum, Diamond. The game's 7 leagues reuse them; the three
## leagues Unity does not have get a tint so every league reads differently.
const LEAGUE_SPRITES := {
	"silver": ["ic_Silver", "ffffffff"], "gold": ["ic_Gold", "ffffffff"], "platinum": ["ic_Platinum", "ffffffff"],
	"emerald": ["ic_Platinum", "7ff0aaff"], "diamond": ["ic_Diamond", "ffffffff"],
	"immortal": ["ic_Platinum", "c9a6ffff"], "one_above_all": ["ic_Diamond", "ff9eb1ff"],
}
## UILeaderboardUserCard._imageStates (ImageStateKeeper): state 0 = my row, 1..3 = rank 1..3, 4 = others.
const ROW_BG := [29, 25, 26, 27, 28]
const ROW_POINTS := [19, 17, 16, 18, 19]
const ROW_MEDAL := [0, 14, 15, 24, 0]
const ATLAS := "UI_Leaderboard_Atlas:UI_Leaderboard_Atlas_%d"
const ATLAS_TEX := "res://assets/ui/cc/UI_Leaderboard_Atlas.png"
## Unity rects (x, y from top, w, h) and borders (l, t, r, b) of UI_Leaderboard_Atlas sprites that only
## ImageStateKeeper references; tools/unity_ui_export.mjs does not export them to _sprites.json.
const ATLAS_EXTRA := {
	25: [524, 930, 500, 94, 30, 30, 30, 30], 26: [523, 833, 500, 94, 30, 30, 30, 30],
	27: [524, 734, 500, 94, 30, 30, 30, 30], 29: [524, 539, 500, 94, 30, 30, 30, 30],
}
## Rank point icon: the game's piece (lb_piece) in place of Unity's UI_Maincenter_2.
const PIECE_ICON := "lb_piece"

## Màu nền huy hiệu theo league (chưa có ảnh cúp riêng cho từng league).
const LEAGUE_COLORS := {
	"silver": Color("AEB8CC"), "gold": Color("FFB82E"), "platinum": Color("6FCFE3"), "emerald": Color("2FBF71"),
	"diamond": Color("4E8DF5"), "immortal": Color("B05CF0"), "one_above_all": Color("F2456B"),
}
## Màu số hạng 1, 2, 3.
const MEDAL_COLORS := [Color("FFC933"), Color("C9D3E6"), Color("E8975A")]
const AVATAR_PX := 76


static func league_name(id: String) -> String:
	return TranslationServer.translate("lb_league_" + id)


static func league_color(id: String) -> Color:
	return LEAGUE_COLORS.get(id, ThemeKit.TEXT_DIM)


## Huy hiệu league: cúp của league (LeaderboardRankBadgesSO, xem LEAGUE_SPRITES), khung vuông px.
static func league_badge(id: String, px: float) -> Control:
	var p := Control.new()
	p.name = "LeagueBadge"
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var img := UImage.new()
	img.name = "Trophy"
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.preserve_aspect = true
	var sp := UnityUI.sprite_info(league_sprite(id))
	if not sp.is_empty():
		img.set_texture(sp.tex, sp.region)
	img.color = league_tint(id)
	p.add_child(img)
	return p


## Số hạng: 1-3 trong vòng màu huy chương, còn lại chữ mực.
static func rank_badge(rank: int, px: float = 64.0) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(px, px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rank >= 1 and rank <= 3:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxFlat.new()
		s.bg_color = MEDAL_COLORS[rank - 1]
		s.set_corner_radius_all(int(px * 0.5))
		s.set_border_width_all(3)
		s.border_color = Color(MEDAL_COLORS[rank - 1]).darkened(0.35)
		p.add_theme_stylebox_override("panel", s)
		p.custom_minimum_size = Vector2(px * 0.8, px * 0.8)
		var l := ThemeKit.make_label(str(rank), ThemeKit.FS_SMALL + 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		holder.add_child(p)
	else:
		var l := ThemeKit.ink_label(fmt_int(rank), ThemeKit.FS_SMALL + 2 if rank < 1000 else ThemeKit.FS_SMALL - 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(l)
	return holder


## Chip mã cờ (ví dụ "VN"); "" thì trả null.
static func flag_chip(code: String) -> Control:
	if code == "":
		return null
	var l := Label.new()
	l.text = code
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL - 6)
	l.add_theme_color_override("font_color", ThemeKit.TEXT)
	var s := StyleBoxFlat.new()
	s.bg_color = ThemeKit.INK_DIM
	s.set_corner_radius_all(8)
	s.content_margin_left = 6
	s.content_margin_right = 6
	l.add_theme_stylebox_override("normal", s)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## Mảnh + số điểm.
static func points_box(points: int, size: int = ThemeKit.FS_SMALL + 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ThemeKit.make_icon("lb_piece", 40))
	var l := ThemeKit.ink_label(fmt_int(points), size, ThemeKit.BROWN)
	l.name = "PointsLabel"
	l.custom_minimum_size.x = 72
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


static func display_name(row: Dictionary) -> String:
	return TranslationServer.translate("lb_you") if bool(row.get("me", false)) else str(row.get("name", ""))


## Nội dung một hàng (hạng, avatar, tên + cờ, điểm). `sub` là dòng nhỏ dưới tên ("" thì bỏ).
static func row_content(row: Dictionary, sub: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(rank_badge(int(row.get("rank", 0))))
	h.add_child(Profile.make_avatar(str(row.get("avatar", "")), str(row.get("frame", "")), AVATAR_PX))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(line)
	var n := ThemeKit.ink_label(display_name(row), ThemeKit.FS_SMALL + 2)
	n.name = "NameLabel"
	n.clip_text = true
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(n)
	var flag := flag_chip(str(row.get("flag", "")))
	if flag != null:
		line.add_child(flag)
	if sub != "":
		v.add_child(ThemeKit.ink_label(sub, ThemeKit.FS_SMALL - 4, ThemeKit.INK_DIM))
	h.add_child(points_box(int(row.get("points", 0))))
	return h


static func _row_box(me: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ThemeKit.WELL_HOT if me else ThemeKit.POPUP_CREAM
	s.set_corner_radius_all(18)
	if me:
		s.set_border_width_all(4)
		s.border_color = ThemeKit.WELL_HEADER
	s.content_margin_left = 12
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


## Hàng chỉ để xem (BXH League không tương tác).
static func row(row_view: Dictionary, sub: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Me" if bool(row_view.get("me", false)) else "Row_%d" % int(row_view.get("rank", 0))
	p.custom_minimum_size.y = 96
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_theme_stylebox_override("panel", _row_box(bool(row_view.get("me", false))))
	p.add_child(row_content(row_view, sub))
	return p


## Hàng bấm được (World Ranking: chạm để xem người chơi).
static func row_button(row_view: Dictionary) -> Button:
	var b := Button.new()
	b.name = "WorldRow_%d" % int(row_view.get("rank", 0))
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ThemeKit.MIN_BUTTON.x, 96)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := _row_box(bool(row_view.get("me", false)))
		if st == "pressed":
			s.bg_color = s.bg_color.darkened(0.08)
		b.add_theme_stylebox_override(st, s)
	var c := row_content(row_view)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 12
	c.offset_right = -14
	b.add_child(c)
	return b


## Podium 3 người đầu: thứ tự 2 - 1 - 3, bục giữa cao nhất.
static func podium(rows: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = "Podium"
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var by_rank := {}
	for r in rows:
		by_rank[int(r.get("rank", 0))] = r
	for rank in [2, 1, 3]:
		if by_rank.has(rank):
			h.add_child(_podium_column(by_rank[rank]))
	return h


static func _podium_column(r: Dictionary) -> VBoxContainer:
	var rank := int(r.get("rank", 0))
	var first := rank == 1
	var v := VBoxContainer.new()
	v.name = "Podium_%d" % rank
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.custom_minimum_size.x = 196
	v.add_child(rank_badge(rank, 56))
	var av := Profile.make_avatar(str(r.get("avatar", "")), str(r.get("frame", "")), 118 if first else 96)
	av.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(av)
	var plinth := PanelContainer.new()
	plinth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plinth.custom_minimum_size.y = [0, 116, 92, 76][rank]
	var s := StyleBoxFlat.new()
	s.bg_color = Color(MEDAL_COLORS[rank - 1]).darkened(0.05)
	s.corner_radius_top_left = 16
	s.corner_radius_top_right = 16
	s.border_width_top = 6
	s.border_color = Color(MEDAL_COLORS[rank - 1]).lightened(0.35)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 6
	plinth.add_theme_stylebox_override("panel", s)
	v.add_child(plinth)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plinth.add_child(inner)
	var n := ThemeKit.make_label(display_name(r), ThemeKit.FS_SMALL - 2)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	inner.add_child(n)
	var pts := points_box(int(r.get("points", 0)), ThemeKit.FS_SMALL + 2)
	pts.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(pts)
	return v


## 1234567 -> "1,234,567" (dấu nhóm theo ngôn ngữ, ThemeKit.thousands_sep: tiếng Việt "1.234.567").
static func fmt_int(n: int) -> String:
	var sep := ThemeKit.thousands_sep()
	var neg := n < 0
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = sep + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if neg else "") + digits + out


## 3725 -> "01:02:05".
static func fmt_clock(sec: int) -> String:
	sec = maxi(sec, 0)
	@warning_ignore("integer_division")
	return "%02d:%02d:%02d" % [sec / 3600, (sec % 3600) / 60, sec % 60]


# --- prefab pieces (unity_ui.gd) ---

static func league_sprite(id: String) -> String:
	return str((LEAGUE_SPRITES.get(id, LEAGUE_SPRITES.silver) as Array)[0])


static func league_tint(id: String) -> Color:
	return Color(str((LEAGUE_SPRITES.get(id, LEAGUE_SPRITES.silver) as Array)[1]))


## Trophy of a league on a built Image node; alpha (current league or not) is kept.
static func set_league_icon(node: Control, id: String) -> void:
	UnityUI.set_sprite(node, league_sprite(id))
	var img := UnityUI.image_of(node)
	if img != null:
		var c := league_tint(id)
		c.a = (img.color as Color).a
		img.call("set_color", c)


## UI_Leaderboard_Atlas sprite n on a built node, including the ones _sprites.json lacks (ATLAS_EXTRA).
static func set_atlas(node: Control, n: int) -> void:
	var key := ATLAS % n
	if not UnityUI.sprite_info(key).is_empty() or not ATLAS_EXTRA.has(n):
		UnityUI.set_sprite(node, key)
		return
	var img := UnityUI.image_of(node)
	var tex := load(ATLAS_TEX) as Texture2D
	if img == null or tex == null:
		return
	var a: Array = ATLAS_EXTRA[n]
	var k := float(tex.get_width()) / 1024.0
	var ppu := float((node.get_meta("u", {}) as Dictionary).get("img", {}).get("ppu", 1.0))
	img.call("set_texture", tex, Rect2(float(a[0]) * k, float(a[1]) * k, float(a[2]) * k, float(a[3]) * k),
		Vector4(float(a[4]), float(a[5]), float(a[6]), float(a[7])) * k, 1.0 / k / maxf(ppu, 0.0001))


## Game avatar and frame textures on an Avatar node of a prefab (frame without a real icon keeps the prefab ring).
static func set_avatar(avatar: Control, avatar_id: String, frame_id: String) -> void:
	if avatar == null:
		return
	if avatar_id != "":
		(UnityUI.image_of(avatar)).call("set_texture", ThemeKit.icon(avatar_id))
	var fr := avatar.get_node_or_null("Frame") as Control
	if fr != null and frame_id != "" and ThemeKit.has_real_icon(frame_id):
		(UnityUI.image_of(fr)).call("set_texture", ThemeKit.icon(frame_id))


## TMP auto size on a label that has none in the prefab (rank numbers like 12,345). The meta is copied first:
## it is the cached layout dict.
static func auto_size(l: Label, lo: float = 18.0) -> void:
	var t: Dictionary = (l.get_meta("u_txt", {}) as Dictionary).duplicate()
	if t.get("auto") == null:
		t["auto"] = [lo, float(t.get("fs", 36.0))]
		l.set_meta("u_txt", t)
		l.resized.connect(UnityUI.fit_text.bind(l))
	UnityUI.fit_text(l)


## A PlayerLeaderboardItem (800x150) under parent at rect (canvas units from the parent's top-left).
## button: the row is a Button tinting its BG (World rows open the player card). Returns the row's view.
static func card(parent: Control, row: Dictionary, rect: Rect2, sub: String = "", button: bool = false) -> RefCounted:
	var s := UnityKit.spec(ITEM, "")
	s.a = true
	if button:
		s["btn"] = {"tr": 1, "c": ["ffffffff", "f5f5f5ff", "c8c8c8ff", "c8c8c880"], "mult": 1, "dur": 0.1,
			"inter": true, "target": str((s.ch[0] as Dictionary).id)}
		s["snd"] = true
	var v: RefCounted = UnityKit.add(parent, s, rect)
	fill_card(v.root, row, sub)
	return v


## UILeaderboardUserCard.SetupCard on a built PlayerLeaderboardItem: rank (medal for 1-3), avatar and frame,
## name (+ an optional second line), flag code, points; BG and point pill by rank, arrow and green BG on my row.
## The Gift (weekly top-5 reward) is hidden: the game has no position rewards.
static func fill_card(root: Control, row: Dictionary, sub: String = "") -> void:
	var rank := int(row.get("rank", 0))
	var me := bool(row.get("me", false))
	var idx := rank if rank >= 1 and rank <= 3 else 4
	var st := 0 if me else idx
	set_atlas(root.get_node("BG"), ROW_BG[st])
	set_atlas(root.get_node("PointPanel"), ROW_POINTS[st])
	var medal := root.get_node("RankNumberTxt/Image") as Control
	medal.visible = idx <= 3
	if idx <= 3:
		set_atlas(medal, ROW_MEDAL[idx])
	(root.get_node("PlayerArrow") as Control).visible = me
	(root.get_node("Gift") as Control).visible = false
	var num := root.get_node("RankNumberTxt") as Label
	num.text = fmt_int(rank)
	auto_size(num)
	set_avatar(root.get_node("Avatar"), str(row.get("avatar", "")), str(row.get("frame", "")))
	var name_l := root.get_node("PlayerName") as Label
	UnityUI.set_text(name_l, display_name(row))
	(UnityUI.image_of(root.get_node("PointPanel/RankPointIcon"))).call("set_texture", ThemeKit.icon(PIECE_ICON))
	UnityUI.set_text(root.get_node("PointPanel/PointText") as Label, fmt_int(int(row.get("points", 0))))
	_sub_line(root, name_l, sub)
	_flag(root, str(row.get("flag", "")))


## Second line under the name (rank change, league): a copy of PlayerName at 30 units, the name moves up.
static func _sub_line(root: Control, name_l: Label, sub: String) -> void:
	var old := root.get_node_or_null("SubText")
	if old != null:
		root.remove_child(old)
		old.queue_free()
	var r: Dictionary = name_l.get_meta("u_rect")
	r.pos = Vector2((r.pos as Vector2).x, 18.0 if sub != "" else 0.0)
	r.size = Vector2((r.size as Vector2).x, 60.0 if sub != "" else 91.2)
	UnityUI.apply_rect(name_l)
	UnityUI.fit_text(name_l)
	if sub == "":
		return
	var s := UnityKit.spec(ITEM, "PlayerName")
	s.n = "SubText"
	s.txt.s = sub
	s.txt.fs = 30.0
	s.txt.auto = [18.0, 30.0]
	s.r = [0.5, 0.5, 0.5, 0.5, -181.4, -30.0, 295.4, 44.0, 0.0, 0.5]
	UnityKit.add(root, s)


## Country code next to the name, in the slot of the hidden Gift.
static func _flag(root: Control, code: String) -> void:
	var old := root.get_node_or_null("FlagText")
	if old != null:
		root.remove_child(old)
		old.queue_free()
	if code == "":
		return
	var s := UnityKit.spec(ITEM, "PlayerName")
	s.n = "FlagText"
	s.txt.s = code
	s.txt.fs = 32.0
	s.txt.auto = [18.0, 32.0]
	s.txt.h = 2
	s.r = [0.5, 0.5, 0.5, 0.5, 150.0, 0.0, 110.0, 50.0, 0.5, 0.5]
	UnityKit.add(root, s)


## Reward prefab items (icon + amount) for a game reward {coins, items, inf_min} into a layout parent:
## gold uses RewardItemSO's gold sprite, boosters the game's booster icons, unlimited lives the infinite heart.
static func reward_items(parent: Control, reward: Dictionary) -> Array:
	var out: Array = []
	var coins := int(reward.get("coins", 0))
	if coins > 0:
		out.append(_reward_item(parent, "Resources_moved_UI_Maincenter:UI_Maincenter_3", null, fmt_int(coins)))
	var items: Dictionary = reward.get("items", {})
	for kind in ["hint", "move", "smash"]:
		var n := int(items.get(kind, 0))
		if n > 0:
			out.append(_reward_item(parent, "", ThemeKit.icon("booster_" + kind),
				TranslationServer.translate("booster_count") % n))
	var inf := int(reward.get("inf_min", 0))
	if inf > 0:
		out.append(_reward_item(parent, "Resources_moved_UI_Maincenter:UI_Maincenter_16", null,
			TranslationServer.translate("weekly_reward_inf") % inf))
	return out


static func _reward_item(parent: Control, key: String, tex: Texture2D, amount: String) -> RefCounted:
	var s := UnityKit.spec("Reward", "")
	s.a = true
	var v: RefCounted = UnityKit.add(parent, s)
	if key != "":
		v.sprite("RewardIcon", key)
	else:
		v.texture("RewardIcon", tex)
	(v.image("RewardIcon")).set("preserve_aspect", true)
	v.text("RewardText", amount)
	return v
