extends RefCounted
## Màn Leaderboard và popup: dựng từ Game, nút đủ cỡ, không lộ khoá dịch, tab World, popup lên giải,
## khối đặc biệt trên HUD level, hàng leaderboard trên thẻ thắng.
const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const Leaderboard := preload("res://src/meta/leaderboard.gd")
const BoardState := preload("res://src/core/board_state.gd")

const DIR := "user://test_ui_leaderboard"
const NOW := 1_800_000_000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _g(level: int = 30) -> Node:
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
	_g(5)
	var home := _mount("home")
	t.ok(home.find_child("LeaderboardButton", true, false).disabled, "L5 chưa mở Ranking")
	home.free()
	_g(8)
	home = _mount("home")
	t.ok(not home.find_child("LeaderboardButton", true, false).disabled, "L8 mở Ranking")
	home.free()


func test_hub_top_hides_profile_and_settings(t: T) -> void:
	_g()
	for scene in ["shop", "leaderboard"]:
		var n := _mount(scene, {"source": "test"} if scene == "shop" else {})
		var top: Control = n.find_child("HubTop", true, false)
		t.ok(not top.profile_btn.visible, scene + ": ẩn avatar")
		t.ok(not top.settings_btn.visible, scene + ": ẩn settings")
		t.ok(top.gold_label.is_visible_in_tree(), scene + ": còn vàng")
		n.free()
	var home := _mount("home")
	t.ok(home.profile_btn.visible and home.settings_btn.visible, "Home giữ avatar, settings")
	home.free()


func _shown(node: Node, n: String) -> bool:
	var c := node.find_child(n, true, false) as Control
	return c != null and c.is_visible_in_tree()


## Tab League theo wireframe: banner (giải, đếm ngược, "i"), khung thưởng thăng hạng, podium, hàng ghim, thanh tab dưới.
func test_league_tab(t: T) -> void:
	var g := _g()
	g.lb_claim()
	var node := _mount("leaderboard")
	var silver := node.tr("lb_league_silver")
	t.eq((node.find_child("BannerLeague", true, false) as Label).text, silver, "banner: tên giải")
	var tab_l := node.find_child("Tab_league", true, false)
	t.eq((tab_l.get_node("Text (TMP)") as Label).text, silver, "tab League mang tên giải hiện tại")
	t.ok(_shown(node, "TabLeagueIcon") and _shown(node, "TabWorldIcon"), "tab có icon")
	t.ok(_shown(node, "CountdownPill") and _shown(node, "InfoButton"), "banner: đếm ngược và nút i")
	t.ok(not _shown(node, "RewardToggle"), "nút Phần thưởng chỉ ở tab World")
	t.ok((node.find_child("CountdownLabel", true, false) as Label).text != "", "đếm ngược lần cập nhật")
	t.ok(_shown(node, "PromoBox"), "khung thưởng thăng hạng")
	t.eq((node.find_child("PromoTitle", true, false) as Label).text,
		node.tr("lb_promo_title") % (node.tr("lb_league") % node.tr("lb_league_gold")), "thưởng của giải kế")
	t.eq((node.find_child("PromoRewards", true, false) as Node).get_child_count(), 2, "Gold: 300 gold, 1 Hint")
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
	node.free()


func test_league_tab_top_league(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 1000)
	g.lb_claim()
	var node := _mount("leaderboard")
	t.eq((node.find_child("BannerLeague", true, false) as Label).text, node.tr("lb_league_one_above_all"), "giải cuối")
	t.ok(not _shown(node, "PromoBox"), "giải cao nhất: ẩn khung thưởng thăng hạng")
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


## Tab World theo wireframe: thẻ người chơi, thang 7 giải từ cao xuống thấp, nút đổi sang thưởng của từng giải.
func test_world_tab_ladder(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 35)
	g.lb_claim()
	var node := _mount("leaderboard", {"tab": "world"})
	t.ok(_shown(node, "PlayerCard"), "thẻ người chơi")
	t.eq((node.find_child("CardTop", true, false) as Label).text, node.tr("lb_top_percent") % Leaderboard.top_percent(g.s),
		"Top %")
	t.ok(not _shown(node, "CountdownPill") and not _shown(node, "InfoButton"), "đếm ngược, i chỉ ở tab League")
	t.ok(_shown(node, "RewardToggle"), "nút Phần thưởng trên banner")
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
	(node.find_child("RewardToggle", true, false) as Button).pressed.emit()
	t.eq((node.find_child("RewardToggleLabel", true, false) as Label).text, node.tr("lb_btn_info"), "nút đổi thành Thông tin")
	var rw := ladder.get_node_or_null("League_platinum/Rewards")
	t.ok(rw != null and rw.get_child_count() == 2, "chế độ Phần thưởng: Platinum 500 gold, 1 Move")
	t.ok(ladder.get_node_or_null("League_gold/Players") == null, "ẩn số người")
	_check_ui(t, node, "leaderboard world rewards")
	(node.find_child("Tab_league", true, false) as Button).pressed.emit()
	t.ok(_shown(node, "PromoBox") and not _shown(node, "PlayerCard"), "đổi về tab League")
	node.free()


func test_pending_popup_on_open(t: T) -> void:
	var g := _g()
	t.ok(not g.lb_pending_view().is_empty(), "mới mở khoá: chờ thưởng Silver")
	var coins := int(g.s.coins)
	var node := _mount("leaderboard")
	var found := func() -> bool: return node.find_child("ClaimButton", true, false) != null
	t.ok(await _wait_until(found), "tự mở popup nhận thưởng")
	_check_ui(t, node.find_child("PopupLbResult", true, false), "popup_lb_result")
	(node.find_child("ClaimButton", true, false) as Button).pressed.emit()
	t.eq(int(g.s.coins), coins + 100, "+100 gold thưởng Silver")
	t.eq(g.lb_pending_view(), {}, "hết chờ")
	node.free()


func test_result_close_still_claims(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 30)
	var coins := int(g.s.coins)
	var node := _mount("popup_lb_result")
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	# LeaderboardWeeklyResultLayer has no X: tapping anywhere (the dim, ClaimButton) is the only way to close.
	var dim := node.find_child("ClaimButton", true, false) as Button
	dim.pressed.emit()
	dim.pressed.emit()
	t.eq(int(g.s.coins), coins + 400, "chạm để đóng vẫn nhận thưởng Silver + Gold")
	t.eq(int(g.s.inv.hint), 1, "+1 hint của Gold")
	t.eq(got.size(), 1, "phát closed một lần")
	node.free()


func test_leagues_popup(t: T) -> void:
	var g := _g()
	Leaderboard.add_points(g.s, 35)
	var node := _mount("popup_leagues")
	for id in ["silver", "gold", "platinum", "emerald", "diamond", "immortal", "one_above_all"]:
		t.ok(node.find_child("League_" + id, true, false) != null, "có league " + id)
	var texts: Array = []
	_texts(node, texts)
	t.ok(texts.has(node.tr("lb_current")), "đánh dấu league hiện tại")
	t.ok(texts.has(node.tr("lb_reached")), "đánh dấu league đã qua")
	t.ok(texts.has(node.tr("lb_league_range_top") % 1000), "league cuối không có trần")
	_check_ui(t, node, "popup_leagues")
	node.free()
	var how := _mount("popup_lb_howto")
	_check_ui(t, how, "popup_lb_howto")
	how.free()


func test_win_card_lb_row(t: T) -> void:
	var g := _g(8)
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
	var g := _g(9)
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
