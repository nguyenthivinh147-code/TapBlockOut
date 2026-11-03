extends RefCounted
## Mảnh UI dùng chung của các màn Leaderboard: huy hiệu league, hàng người chơi, podium, định dạng số.
## Hàng người chơi là dict của Game.lb_view / lb_world_view: {rank, name, avatar, frame, flag, points, me}.

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Profile := preload("res://src/ui/profile.gd")

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


## Huy hiệu league: vòng tròn màu league có cúp ở giữa.
static func league_badge(id: String, px: float) -> Control:
	var p := PanelContainer.new()
	p.name = "LeagueBadge"
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s := StyleBoxFlat.new()
	s.bg_color = league_color(id)
	s.set_corner_radius_all(int(px * 0.5))
	s.set_border_width_all(maxi(3, int(px * 0.05)))
	s.border_color = league_color(id).lightened(0.45)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 3)
	p.add_theme_stylebox_override("panel", s)
	p.add_child(ThemeKit.make_icon("ui_leaderboard", px * 0.72))
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


## 1234567 -> "1,234,567" (tiếng Việt: "1.234.567").
static func fmt_int(n: int) -> String:
	var sep := "." if TranslationServer.get_locale().begins_with("vi") else ","
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
