extends RefCounted
## Màn Leaderboard và popup: dựng từ Game, nút đủ cỡ, không lộ khoá dịch, tab World, popup lên giải,
## khối đặc biệt trên HUD level, hàng leaderboard trên thẻ thắng.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const Leaderboard := preload("res://src/meta/leaderboard.gd")
const LbKit := preload("res://src/ui/lb_kit.gd")
const LbUI := preload("res://src/ui/leaderboard.gd")
const BoardState := preload("res://src/core/board_state.gd")

const DIR := "user://test_ui_leaderboard"
const NOW := 1_800_000_000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _g(level: int = 80) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	g.s.level = level
	for k in ["hint", "move", "smash"]:
		g.s.gifted[k] = true
	g.lb_refresh()
	return g


func _mount(scene: String, args: Dictionary = {}) -> Control:
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate() as Control
	_tree().root.add_child(node)
	node.call("setup", args)
	return node


func _wait_until(cond: Callable, ms: int = 4000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)


## Chữ trông như khoá dịch chưa dịch, và nút thấp hơn 96.
func _check_ui(t: T, node: Node, what: String) -> void:
	var re := RegEx.create_from_string("^[a-z]+_[a-z0-9_]+$")
	var texts: Array = []
	_texts(node, texts)
	var raw: Array = []
	for x in texts:
		if re.search(str(x)) != null:
			raw.append(x)
	t.eq(raw, [], what + " không lộ khoá dịch")
	for b in node.find_children("*", "Button", true, false):
		var btn := b as Button
		# Prefab buttons (unity_ui.gd) keep the Unity art size and grow only their hit area.
		var h: float = (btn.call("hit_size") as Vector2).y if btn.has_method("hit_size") else btn.custom_minimum_size.y
		t.ok(h >= 96 - 0.01, "%s/%s cao >= 96" % [what, b.name])


## Bảng xếp hạng là icon ở cột trái Home (không còn là tab của thanh dưới).
func test_ranking_icon_unlock(t: T) -> void:
	_g(69)
	var home := _mount("home")
	t.ok(home.find_child("LeaderboardButton", true, false).disabled, "L69 chưa mở Ranking")
	home.free()
	var g := _g(70)
	home = _mount("home")
	t.ok(not home.find_child("LeaderboardButton", true, false).disabled, "L70 mở Ranking")
	t.ok(not _shown(home, "LeaderboardDot"), "không có gì chờ: không chấm đỏ")
	home.free()
	Leaderboard.add_points(g.s, 10)
	g.test_now = NOW + 7 * 86400
	g.lb_refresh()
	home = _mount("home")
	t.ok(_shown(home, "LeaderboardDot"), "kết quả tuần chờ xem: chấm đỏ")
	home.free()


func test_hub_top_hides_profile_and_settings(t: T) -> void:
	_g()
	var n := _mount("shop", {"source": "test"})
	var top: Control = n.find_child("HubTop", true, false)
	t.ok(not top.profile_btn.visible, "shop: ẩn avatar")
	t.ok(not top.settings_btn.visible, "shop: ẩn settings")
	t.ok(top.gold_label.is_visible_in_tree(), "shop: còn vàng")
	n.free()
	var home := _mount("home")
	t.ok(home.profile_btn.visible and home.settings_btn.visible, "Home giữ avatar, settings")
	home.free()


func _shown(node: Node, n: String) -> bool:
	var c := node.find_child(n, true, false) as Control
	return c != null and c.is_visible_in_tree()


func _bubble_items(node: Node) -> int:
	var b := node.find_child("RewardBubble", true, false) as Control
	if b == null or not b.visible:
		return 0
	return b.get_children().filter(func(c: Node) -> bool:
		return str(c.name).begins_with("ItemReward") and (c as Control).visible).size()


func _bubble_caption(node: Node) -> String:
	return (node.find_child("RewardBubble", true, false).find_child("Caption", true, false) as Label).text


## Popup Leaderboard, tab League: khung popup (tiêu đề, X, nút i ở góc trái), không còn thanh trên, thanh dưới, banner;
## PromoBox (huy hiệu giải hiện tại, tên giải, đếm ngược tới hết tuần), chạm huy hiệu thì bong bóng thưởng của giải kế;
## podium, hàng ghim, thanh tab ở đáy.
func test_league_tab(t: T) -> void:
	var g := _g()
	var node := _mount("leaderboard")
	# The info button follows the frame's X after layout (deferred).
	await _wait_until(func() -> bool: return false, 100)
	var silver := node.tr("lb_league_silver")
	for gone in ["HubTop", "HubNav", "Banner", "BannerLeague", "RewardToggle", "PromoRewards"]:
		t.ok(node.find_child(gone, true, false) == null, "popup không còn " + gone)
	var x := node.find_child("btnTurnOff", true, false) as Control
	var info := node.find_child("InfoButton", true, false) as Control
	t.ok(x != null and x.is_visible_in_tree(), "có nút X")
	t.ok(info.is_visible_in_tree(), "có nút i")
	# Prefab buttons grow their hit area around the art: compare centres.
	var ic := info.get_global_rect().get_center()
	var xc := x.get_global_rect().get_center()
	var panel := (node.find_child("FrameCanvas", true, false) as Node).find_child("Panel", true, false) as Control
	var pc := panel.get_global_rect().get_center()
	t.ok(absf(ic.y - xc.y) < 2.0 and absf((pc.x - ic.x) - (xc.x - pc.x)) < 12.0, "nút i đối xứng với X ở đầu khung")
	var tab_l := node.find_child("Tab_league", true, false)
	t.eq((tab_l.get_node("Text (TMP)") as Label).text, silver, "tab League mang tên giải hiện tại")
	t.ok(_shown(node, "TabLeagueIcon") and _shown(node, "TabWorldIcon"), "tab có icon")
	t.ok(_shown(node, "PromoBox") and _shown(node, "PromoBadge") and _shown(node, "CountdownPill"), "PromoBox: huy hiệu, đếm ngược")
	t.eq((node.find_child("PromoTitle", true, false) as Label).text, node.tr("lb_league") % silver, "PromoBox: tên giải hiện tại")
	var left := Leaderboard.week_len()
	var want := [node.tr("lb_ends_in") % LbKit.fmt_week(left), node.tr("lb_ends_in") % LbKit.fmt_week(left - 1)]
	t.ok(want.has((node.find_child("CountdownLabel", true, false) as Label).text), "đếm ngược tới hết tuần")
	t.eq(_bubble_items(node), 0, "bong bóng ẩn")
	var badge := node.find_child("PromoBadge", true, false) as Button
	badge.pressed.emit()
	t.eq(_bubble_items(node), 2, "chạm huy hiệu: thưởng Gold (300 gold, 1 Hint)")
	t.eq(_bubble_caption(node), node.tr("lb_reward_next") % (node.tr("lb_league") % node.tr("lb_league_gold")), "thưởng của giải kế")
	var bubble := node.find_child("RewardBubble", true, false) as Control
	t.ok(bubble.get_global_rect().position.y >= badge.get_global_rect().end.y - 1.0, "bong bóng dưới huy hiệu")
	badge.pressed.emit()
	t.eq(_bubble_items(node), 0, "chạm lần nữa thì ẩn")
	t.ok(node.find_child("Podium", true, false) != null, "podium top 3")
	t.ok(node.find_child("MeRow", true, false) != null, "hàng người chơi ghim")
	var rows := node.find_child("Rows", true, false)
	t.ok(rows.get_child_count() <= 1 + 50, "tối đa 50 người quanh người chơi (+ podium)")
	for gone in ["PlayButton", "LeagueProgress", "FlagText", "WorldRow_4"]:
		t.ok(node.find_child(gone, true, false) == null, "không còn " + gone)
	var tabs_y := (tab_l as Control).get_global_rect().position.y
	t.ok(tabs_y > (node.find_child("Rows", true, false) as Control).get_parent().get_global_rect().end.y - 1.0,
		"thanh tab nằm dưới danh sách")
	_check_ui(t, node, "leaderboard")
	t.eq(Leaderboard.seen_rank(g.s), Leaderboard.rank(g.s), "ghi hạng đã xem")
	(node.find_child("InfoButton", true, false) as Button).pressed.emit()
	t.ok(node.find_child("PopupLbHowto", true, false) != null, "nút i mở Cách hoạt động")
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	(x as Button).pressed.emit()
	t.eq(got, [null], "X đóng popup")
	node.free()


func test_league_tab_top_league(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 1000)
	g.lb_claim()
	var node := _mount("leaderboard")
	var top := node.tr("lb_league") % node.tr("lb_league_one_above_all")
	t.eq((node.find_child("PromoTitle", true, false) as Label).text, top, "giải cuối")
	t.ok(_shown(node, "PromoBox") and _shown(node, "CountdownPill"), "giải cao nhất vẫn có PromoBox và đếm ngược")
	(node.find_child("PromoBadge", true, false) as Button).pressed.emit()
	t.eq(_bubble_items(node), 6, "thưởng của chính giải cuối: gold, 3 booster, mạng vô hạn, avatar/khung (còn 5 món)")
	t.eq(_bubble_caption(node), node.tr("lb_reward_claimed"), "đánh dấu đã nhận")
	node.free()


## Khung popup nằm sẵn trong scene (2026-11-10): lòng khung InnerMask (nền BG_Winstreak) phủ phần kem của Popup2 nên
## không còn dải kem dưới ribbon, không lấn viền tím; nội dung bắt đầu dưới ribbon, sát hai bên và đáy lòng khung.
## Thanh tab: Line của prefab ở trên, tab treo dưới Line (nền lật, cạnh hở quay lên), TabBand từ Line tới đáy lòng
## khung. Danh sách và thang mờ dần ở hai mép; hàng ghim nằm ngoài vùng mờ.
func test_popup_frame_layout(t: T) -> void:
	_g(int(Config.UNLOCK.get("leaderboard", 8)))
	var node := _mount("leaderboard")
	await _wait_until(func() -> bool: return false, 100)
	var fc := node.get_node_or_null("FrameCanvas") as Control
	t.ok(fc != null and fc.scene_file_path.ends_with("PopupOkLayer.tscn"), "khung PopupOkLayer nằm sẵn trong scene")
	var panel := fc.get_node("PopupOkLayer/Panel") as Control
	var s := panel.get_global_transform().get_scale().x
	var pr := panel.get_global_rect()
	var mask := node.find_child("InnerMask", true, false) as Control
	var mr := mask.get_global_rect()
	var near := func(a: float, b: float) -> bool: return absf(a - b) <= 1.0
	t.ok(near.call(mr.position.x, pr.position.x + LbUI.BORDER * s) and near.call(mr.end.x, pr.end.x - LbUI.BORDER * s)
		and near.call(mr.position.y, pr.position.y + LbUI.BORDER * s)
		and near.call(mr.end.y, pr.end.y - LbUI.BORDER_BOTTOM * s), "lòng khung trùng phần kem của Popup2")
	t.ok(mask.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "lòng khung cắt con theo góc bo")
	t.eq((node.find_child("InnerBg", true, false) as Control).get_global_rect(), mr, "nền BG_Winstreak phủ cả lòng khung")
	var cr := (node.get_node("Canvas") as Control).get_global_rect()
	t.ok(near.call(cr.position.x, mr.position.x) and near.call(cr.end.x, mr.end.x) and near.call(cr.end.y, mr.end.y),
		"nội dung sát hai bên và đáy lòng khung")
	var ribbon := fc.get_node("PopupOkLayer/Panel/Image") as Control
	var ribbon_end: Vector2 = ribbon.get_global_transform() * (ribbon.call("drawn_rect") as Rect2).end
	t.ok(cr.position.y >= ribbon_end.y - 1.0 and cr.position.y < ribbon_end.y + 30.0 * s, "nội dung bắt đầu ngay dưới ribbon")
	var line := node.get_node("Canvas/LeaderboardLayer/BG/Line") as Control
	var lr := line.get_global_rect()
	var br := (node.find_child("TabBand", true, false) as Control).get_global_rect()
	t.ok(line.is_visible_in_tree() and near.call(br.position.y, lr.position.y) and near.call(br.end.y, mr.end.y)
		and near.call(lr.position.x, mr.position.x) and near.call(lr.end.x, mr.end.x), "Line và TabBand làm thanh tab")
	for id in ["league", "world"]:
		var tab := node.find_child("Tab_" + id, true, false) as Control
		var tab_r := tab.get_global_rect()
		t.ok(tab_r.position.y > lr.position.y and tab_r.position.y < lr.end.y and tab_r.end.y < br.end.y,
			"tab %s treo dưới Line" % id)
		t.ok((tab.get_node("Background") as Control).scale.y < 0.0, "nền tab %s lật, cạnh hở quay lên" % id)
	var vp := (node.find_child("Rows", true, false) as Control).get_parent() as Control
	t.ok(vp.get("tex") is GradientTexture2D and vp.clip_children == CanvasItem.CLIP_CHILDREN_ONLY, "danh sách mờ dần ở mép")
	t.ok((node.find_child("MeRow", true, false) as Control).get_parent() != vp, "hàng ghim ngoài vùng mờ")
	node.free()


## Chạm thật (sự kiện chuột vào viewport, không phải pressed.emit) vào thanh tab khi danh sách còn hàng cuộn xuống
## dưới mép: trước đây các hàng đó (vẫn nhận chạm dù đã bị cắt hình) nuốt cú chạm nên không đổi được sang World.
func test_tabs_take_real_taps_over_scrolled_list(t: T) -> void:
	var g := _g()
	g.lb_claim()
	Leaderboard.add_points(g.s, 14)
	var node := _mount("leaderboard")
	await _wait_until(func() -> bool: return false, 300)
	var vp := node.get_viewport()
	for id in ["world", "league"]:
		var tab := node.find_child("Tab_" + id, true, false) as Control
		var p := tab.get_global_rect().get_center()
		if id == "world":
			var rows := node.find_child("Rows", true, false) as Control
			t.ok(rows.get_global_rect().has_point(p), "danh sách tràn xuống dưới thanh tab (điều kiện của test)")
		var mv := InputEventMouseMotion.new()
		mv.position = p
		vp.push_input(mv, true)
		await _tree().process_frame
		var hit := vp.gui_get_hovered_control()
		t.ok(hit != null and (hit == tab or tab.is_ancestor_of(hit)), "chạm trúng tab %s, không trúng hàng BXH" % id)
		for down in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = down
			e.position = p
			vp.push_input(e, true)
			await _tree().process_frame
		t.eq(node.get("tab"), id, "chạm tab %s thì đổi tab" % id)
	node.free()


func _tap(c: Control) -> void:
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.global_position = c.get_global_rect().get_center()
		c.gui_input.emit(e)


## Tab World theo wireframe: thẻ người chơi, thang 7 giải từ cao xuống thấp; chạm huy hiệu một giải thì bong bóng
## thưởng của giải đó.
func test_world_tab_ladder(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 160)
	g.lb_claim()
	var node := _mount("leaderboard", {"tab": "world"})
	t.ok(_shown(node, "PlayerCard"), "thẻ người chơi")
	t.eq((node.find_child("CardTop", true, false) as Label).text, node.tr("lb_top_percent") % Leaderboard.top_percent(g.s),
		"Top %")
	t.ok(not _shown(node, "CountdownPill") and _shown(node, "InfoButton"), "đếm ngược chỉ ở tab League, nút i ở cả hai tab")
	var ladder := node.find_child("Ladder", true, false)
	var ids: Array = []
	for c in ladder.get_children():
		if str(c.name).begins_with("League_"):
			ids.append(str(c.name).trim_prefix("League_"))
	t.eq(ids, ["one_above_all", "immortal", "diamond", "emerald", "platinum", "gold", "silver"], "thang: cao xuống thấp")
	var cur := ladder.get_node("League_gold") as Control
	t.ok(cur.get_node_or_null("Avatar") != null and cur.get_node_or_null("Glow") != null, "giải hiện tại có avatar, quầng sáng")
	t.ok(ladder.get_node("League_silver").get_node_or_null("Avatar") == null, "giải đã qua không có avatar")
	t.ok(absf((ladder.get_node("League_platinum") as Control).modulate.a - 0.6) < 0.001, "giải chưa tới mờ")
	t.eq((ladder.get_node("League_silver") as Control).modulate.a, 1.0, "giải đã qua rõ")
	t.eq((ladder.get_node("League_silver/Players") as Label).text, "48K", "số người chơi mô phỏng")
	_check_ui(t, node, "leaderboard world")
	_tap(ladder.get_node("League_platinum/LeagueIcon"))
	t.eq(_bubble_items(node), 3, "chạm Platinum: 500 gold, 1 Move, avatar/khung ngẫu nhiên")
	var bubble := node.find_child("RewardBubble", true, false) as Control
	t.eq(bubble.find_children("CosIcon", "", true, false).size(), 1, "ô avatar/khung ngẫu nhiên có ảnh avatar trong khung")
	t.eq(bubble.find_children("RandomMark", "", true, false).size(), 1, "ô ngẫu nhiên có dấu ?")
	var bt: Array = []
	_texts(bubble, bt)
	t.eq(bt.count(node.tr("booster_count") % 1), 2, "Move và ô ngẫu nhiên ghi x1")
	t.eq(_bubble_caption(node), node.tr("lb_reward_next") % (node.tr("lb_league") % node.tr("lb_league_platinum")),
		"giải chưa tới")
	var next_cap := node.tr("lb_reward_next") % (node.tr("lb_league") % node.tr("lb_league_platinum"))
	_tap(ladder.get_node("League_gold/LeagueIcon"))
	t.eq(_bubble_caption(node), next_cap, "cúp giải hiện tại: thưởng của giải kế")
	t.eq(_bubble_items(node), 3, "cúp giải hiện tại: thưởng Platinum")
	_tap(ladder.get_node("League_gold/LeagueIcon"))
	t.eq(_bubble_items(node), 0, "chạm lần nữa thì ẩn")
	_tap(node.find_child("CardLeagueIcon", true, false))
	t.eq(_bubble_caption(node), next_cap, "icon giải trên thẻ người chơi: thưởng của giải kế")
	t.eq(_bubble_items(node), 3, "icon thẻ người chơi: thưởng Platinum")
	_tap(node.find_child("CardLeagueIcon", true, false))
	t.eq(_bubble_items(node), 0, "icon thẻ người chơi: chạm lần nữa thì ẩn")
	_tap(ladder.get_node("League_silver/LeagueIcon"))
	t.eq(_bubble_items(node), 0, "Silver không có thưởng")
	t.ok(ladder.get_node_or_null("League_platinum/Players") != null, "luôn ghi số người chơi")
	(node.find_child("Tab_league", true, false) as Button).pressed.emit()
	t.ok(_shown(node, "PromoBox") and not _shown(node, "PlayerCard"), "đổi về tab League")
	node.free()


## Giải cao nhất không có giải kế: icon giải của người chơi (thẻ, cúp hiện tại) hiện thưởng của chính nó, "Đã nhận";
## cúp giải đã qua cũng "Đã nhận"; bong bóng dùng lại bỏ ô avatar/khung của lần trước.
func test_world_icons_top_league(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 1000)
	g.lb_claim()
	var node := _mount("leaderboard", {"tab": "world"})
	var claimed := node.tr("lb_reward_claimed")
	_tap(node.find_child("CardLeagueIcon", true, false))
	t.eq(_bubble_caption(node), claimed, "icon thẻ người chơi ở giải cuối: đã nhận")
	t.eq(_bubble_items(node), 6, "thưởng của chính giải cuối")
	var ladder := node.find_child("Ladder", true, false)
	_tap(ladder.get_node("League_one_above_all/LeagueIcon"))
	t.eq(_bubble_caption(node), claimed, "cúp giải cuối: đã nhận")
	t.eq(_bubble_items(node), 6, "cúp giải cuối: thưởng của chính nó")
	_tap(ladder.get_node("League_diamond/LeagueIcon"))
	var bubble := node.find_child("RewardBubble", true, false) as Control
	t.eq(_bubble_caption(node), claimed, "giải đã qua: đã nhận")
	t.eq(bubble.find_children("CosIcon", "", true, false).size(), 1, "Diamond có ô avatar/khung")
	_tap(ladder.get_node("League_gold/LeagueIcon"))
	t.eq(_bubble_caption(node), claimed, "Gold đã qua: đã nhận")
	t.eq(bubble.find_children("CosIcon", "", true, false).size(), 0, "bong bóng dùng lại: bỏ ô avatar/khung cũ")
	node.free()


func test_pending_popup_on_open(t: T) -> void:
	var g := _g()
	t.eq(g.lb_pending_view(), {}, "mới mở khoá: Silver không có thưởng")
	t.ok(not g.lb_badge(), "không chấm đỏ")
	Leaderboard.add_points(g.s, 150)
	t.ok(g.lb_badge(), "lên Gold: chấm đỏ")
	var coins := int(g.s.coins)
	var node := _mount("leaderboard")
	var found := func() -> bool: return node.find_child("ClaimButton", true, false) != null
	t.ok(await _wait_until(found), "tự mở popup nhận thưởng")
	_check_ui(t, node.find_child("PopupLbResult", true, false), "popup_lb_result")
	t.ok(not _shown(node, "WeekCard"), "popup lên giải không có thẻ hạng tuần")
	(node.find_child("ClaimButton", true, false) as Button).pressed.emit()
	t.eq(int(g.s.coins), coins + 300, "+300 gold thưởng Gold")
	t.eq(g.lb_pending_view(), {}, "hết chờ")
	t.ok(not g.lb_badge(), "hết chấm đỏ")
	node.free()


## Tuần đã hết lúc mở: popup kết quả tuần (hạng, điểm, giải cuối tuần, tuần mới từ Silver, thưởng còn chờ).
func test_week_result_popup_on_open(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 160)
	g.test_now = NOW + 7 * 86400
	g.lb_refresh()
	t.ok(g.lb_badge(), "kết quả tuần: chấm đỏ")
	var coins := int(g.s.coins)
	var node := _mount("leaderboard")
	var found := func() -> bool: return node.find_child("WeekCard", true, false) != null
	t.ok(await _wait_until(found), "tự mở popup kết quả tuần")
	var pop := node.find_child("PopupLbResult", true, false)
	_check_ui(t, pop, "popup kết quả tuần")
	var texts: Array = []
	_texts(pop, texts)
	t.ok(texts.has(node.tr("lb_week_title")), "tiêu đề Kết quả tuần")
	t.ok(texts.has(node.tr("lb_week_restart") % (node.tr("lb_league") % node.tr("lb_league_silver"))), "tuần mới từ Silver")
	t.ok(texts.has("160"), "điểm của tuần")
	t.eq((node.find_child("PromoTitle", true, false) as Label).text, node.tr("lb_league") % node.tr("lb_league_silver"),
		"BXH đã về Silver")
	(pop.find_child("ClaimButton", true, false) as Button).pressed.emit()
	t.eq(int(g.s.coins), coins + 300, "thưởng Gold còn chờ được nhận")
	t.eq(g.lb_week_result_view(), {}, "hết kết quả")
	t.ok(not g.lb_badge(), "hết chấm đỏ")
	await _tree().process_frame
	t.ok(node.find_child("PopupLbResult", true, false) == null or node.find_child("PopupLbResult", true, false).is_queued_for_deletion(),
		"không mở thêm popup")
	node.free()


func test_result_close_still_claims(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 150)
	var coins := int(g.s.coins)
	var node := _mount("popup_lb_result")
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	# LeaderboardWeeklyResultLayer has no X: tapping anywhere (the dim, ClaimButton) is the only way to close.
	var dim := node.find_child("ClaimButton", true, false) as Button
	dim.pressed.emit()
	dim.pressed.emit()
	t.eq(int(g.s.coins), coins + 300, "chạm để đóng vẫn nhận thưởng Gold")
	t.eq(int(g.s.inv.hint), 1, "+1 hint của Gold")
	t.eq(got.size(), 1, "phát closed một lần")
	node.free()


## Từ Platinum: popup Lên giải có ô avatar/khung (món đã chọn, avatar trong khung), chạm nhận thì vào đồ đã có.
func test_promo_popup_shows_cosmetic(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 300)
	var cos: Array = g.lb_pending_view().reward.cos
	t.eq(cos.size(), 1, "Platinum: 1 món")
	var node := _mount("popup_lb_result")
	t.eq(node.find_children("CosIcon", "", true, false).size(), 1, "một ô avatar/khung")
	var texts: Array = []
	_texts(node, texts)
	var key := "lb_reward_frame" if str(cos[0]).begins_with("frame_") else "lb_reward_avatar"
	t.ok(texts.has(node.tr(key)), "chữ dưới ô: " + node.tr(key))
	_check_ui(t, node, "popup_lb_result có avatar/khung")
	(node.find_child("ClaimButton", true, false) as Button).pressed.emit()
	t.ok((g.s.cos.owned as Array).has(cos[0]), "nhận: món vào đồ đã có")
	node.free()


func test_leagues_popup(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 160)
	var node := _mount("popup_leagues")
	for id in ["silver", "gold", "platinum", "emerald", "diamond", "immortal", "one_above_all"]:
		t.ok(node.find_child("League_" + id, true, false) != null, "có league " + id)
	var texts: Array = []
	_texts(node, texts)
	t.ok(texts.has(node.tr("lb_current")), "đánh dấu league hiện tại")
	t.ok(texts.has(node.tr("lb_reached")), "đánh dấu league đã qua")
	t.ok(texts.has(node.tr("lb_league_range_top") % 950), "league cuối không có trần")
	_check_ui(t, node, "popup_leagues")
	node.free()
	var how := _mount("popup_lb_howto")
	_check_ui(t, how, "popup_lb_howto")
	for i in 3:
		var tex: Texture2D = how.ui.node("Panel/LeaguesDesc/Step%d" % (i + 1)).get("tex")
		t.eq(tex.resource_path if tex != null else "", "res://assets/ui/lb_howto_%d.png" % (i + 1),
			"bước %d dùng ảnh vẽ từ UI game" % (i + 1))
	how.free()


func test_win_card_lb_row(t: T) -> void:
	var g := _g(70)
	var a: Dictionary = g.start_attempt()
	for id in (a.board as BoardState).block_ids():
		g.smash_block(a, id)
	var res: Dictionary = g.on_level_won(a)
	var card := _mount("win_card", res)
	t.ok(card.find_child("LbRow", true, false) != null, "thẻ thắng có hàng leaderboard")
	# Dải phần thưởng chỉ có gold: không có ô "+N điểm xếp hạng" và icon của nó.
	var rewards := card.find_child("Rewards", true, false) as Control
	t.ok(rewards != null, "có dải phần thưởng")
	t.eq(rewards.get_children().filter(func(c: Node) -> bool: return c is CanvasItem and (c as CanvasItem).visible).size(), 1, "dải phần thưởng chỉ có ô gold")
	t.ok(card.find_child("LbPointReward", true, false) == null, "không có ô điểm xếp hạng")
	var texts: Array = []
	_texts(card, texts)
	t.ok(not texts.has(card.tr("lb_win_points") % int(res.lb.added)), "không hiện +%d điểm xếp hạng" % int(res.lb.added))
	# EndGameUILayer: hạng là số trên huy chương của thẻ người chơi (UILeaderboardUserCard), tổng điểm ở ô điểm.
	var rank := card.find_child("LbRankLabel", true, false) as Label
	var want_rank := str(int(res.lb.rank_after))
	t.ok(await _wait_until(func() -> bool: return rank.text == want_rank), "hạng đếm tới hạng mới")
	var total := card.find_child("LbTotalLabel", true, false) as Label
	t.ok(await _wait_until(func() -> bool: return total.text == str(int(res.lb.after))), "tổng điểm đếm tới điểm mới")
	card.free()
	g.s.level = 3
	var a3: Dictionary = g.start_attempt()
	card = _mount("win_card", g.on_level_won(a3))
	t.ok(card.find_child("LbRow", true, false) == null, "level không có mảnh thì không hiện")
	card.free()


func test_level_hud_and_piece(t: T) -> void:
	var g := _g(71)
	g.s.inv["smash"] = 3
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi")
	var sp: Array = lv.attempt.specials
	t.ok(not sp.is_empty(), "level có khối đặc biệt")
	t.ok(lv.piece_chip.visible, "HUD có chip mảnh")
	t.ok(lv.find_child("TopBar", true, false).is_ancestor_of(lv.piece_chip), "chip mảnh nằm ở thanh trên")
	await _tree().process_frame  # container xếp chỗ ở cuối khung
	t.ok(lv.piece_chip.get_global_rect().end.y <= lv.board_view.get_global_rect().position.y, "chip mảnh ở trên bàn")
	t.eq(lv.piece_label.text, "0/%d" % sp.size(), "chưa nhặt")
	for id in sp:
		t.ok(lv.board_view.is_special(str(id)), "khối %s là khối crystal" % id)
	lv._do_smash(str(sp[0]))
	t.eq(int(lv.attempt.pieces), 1, "phá khối đặc biệt được 1 mảnh")
	t.eq(lv.piece_label.text, "0/%d" % sp.size(), "số trên chip đợi crystal bay tới")
	t.ok(await _wait_until(func() -> bool: return lv.find_child("FlyingPiece", true, false) != null), "búa gõ xong thì crystal bay về chip")
	t.ok(await _wait_until(func() -> bool: return lv.piece_label.text == "1/%d" % sp.size()), "crystal chạm chip thì số tăng")
	t.ok(await _wait_until(func() -> bool: return lv.find_child("FlyingPiece", true, false) == null), "hiệu ứng tự xoá")
	lv.free()
	_g(5)
	lv = (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi L5")
	t.ok(not lv.piece_chip.visible, "chưa mở leaderboard thì không có chip")
	lv.free()


func _mount_level() -> Control:
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	return lv


## Popup Cách hoạt động đang mở trên màn level, hoặc null.
func _howto_in(lv: Control) -> Control:
	for c in lv.get_node("LocalPopups").get_children():
		if not c.is_queued_for_deletion() and c.name == "PopupLbHowto":
			return c
	return null


## Level có khối crystal đầu tiên (L70, lúc mở Leaderboard): vào màn thì hiện popup Cách hoạt động một lần.
func test_first_crystal_level_shows_howto(t: T) -> void:
	var g := _g(5)
	g.s.lb["guide"] = false
	var lv := _mount_level()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "L5 vào chơi ngay")
	t.eq(_howto_in(lv), null, "chưa mở Leaderboard: không có popup")
	t.eq(bool(g.s.lb.guide), false, "chưa đánh dấu đã xem")
	lv.free()
	g = _g(70)
	g.s.lb["guide"] = false
	lv = _mount_level()
	t.ok(await _wait_until(func() -> bool: return _howto_in(lv) != null), "L70 mở popup Cách hoạt động")
	t.ok(not (lv.attempt.specials as Array).is_empty(), "level có khối crystal")
	t.eq(lv.state, "intro", "chưa chơi khi đọc hướng dẫn")
	t.eq(bool(g.s.lb.guide), true, "đã ghi xem hướng dẫn")
	var how := _howto_in(lv)
	t.eq(how.ui.label("Panel/LeaguesDesc/txtHeader").text, lv.tr("lb_howto_title"), "tiêu đề Cách hoạt động")
	_check_ui(t, how, "popup_lb_howto trong level")
	(how.find_child("OkButton", true, false) as Button).pressed.emit()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "chạm thì vào chơi")
	t.eq(_howto_in(lv), null, "popup đã đóng")
	lv.free()
	lv = _mount_level()
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "chơi lại L70: vào chơi ngay")
	t.eq(_howto_in(lv), null, "không hiện lại")
	lv.free()
