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


func test_ranking_tab_unlock(t: T) -> void:
	_g(5)
	var home := _mount("home")
	t.ok(home.find_child("RankingTab", true, false).disabled, "L5 chưa mở Ranking")
	home.free()
	_g(8)
	home = _mount("home")
	t.ok(not home.find_child("RankingTab", true, false).disabled, "L8 mở Ranking")
	home.free()


func test_league_tab(t: T) -> void:
	var g := _g()
	g.lb_claim()
	var node := _mount("leaderboard")
	t.ok(node.find_child("LeagueCard", true, false) != null, "thẻ league")
	t.ok(node.find_child("Podium", true, false) != null, "podium top 3")
	t.ok(node.find_child("MeRow", true, false) != null, "hàng người chơi ghim dưới")
	var rows := node.find_child("Rows", true, false)
	t.ok(rows.get_child_count() <= 1 + 50, "tối đa 50 người quanh người chơi (+ podium)")
	var league := node.find_child("LeagueLabel", true, false) as Label
	t.eq(league.text, node.tr("lb_league") % node.tr("lb_league_silver"), "tên league")
	var pct := node.find_child("TopPercentLabel", true, false) as Label
	t.eq(pct.text, node.tr("lb_top_percent") % Leaderboard.top_percent(g.s), "Top %")
	t.ok((node.find_child("CountdownLabel", true, false) as Label).text != "", "đếm ngược lần cập nhật")
	_check_ui(t, node, "leaderboard")
	t.eq(Leaderboard.seen_rank(g.s), Leaderboard.rank(g.s), "ghi hạng đã xem")
	var got: Array = []
	node.closed.connect(func(r: Variant) -> void: got.append(r))
	(node.find_child("PlayButton", true, false) as Button).pressed.emit()
	t.eq(got, [{"action": "play"}], "PLAY vào level")
	node.free()


func test_world_tab_and_player(t: T) -> void:
	var g := _g()
	g.lb_claim()
	var node := _mount("leaderboard", {"tab": "world"})
	t.ok(node.find_child("WorldCard", true, false) != null, "thẻ World")
	var row := node.find_child("WorldRow_4", true, false) as Button
	t.ok(row != null, "hàng World bấm được")
	_check_ui(t, node, "leaderboard world")
	row.pressed.emit()
	var pop := node.find_child("PopupLbPlayer", true, false)
	t.ok(pop != null, "chạm hàng mở thẻ người chơi")
	if pop != null:
		_check_ui(t, pop, "popup_lb_player")
	(node.find_child("Tab_league", true, false) as Button).pressed.emit()
	t.ok(node.find_child("LeagueCard", true, false) != null, "đổi về tab League")
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
	var pts := card.find_child("LbPointsLabel", true, false) as Label
	var want := card.tr("lb_win_points") % int(res.lb.added)
	t.ok(await _wait_until(func() -> bool: return pts.text == want), "điểm đếm tới +%d" % int(res.lb.added))
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
		t.ok(lv.board_view.is_special(str(id)), "khối %s có huy hiệu" % id)
	lv._do_smash(str(sp[0]))
	t.eq(int(lv.attempt.pieces), 1, "phá khối đặc biệt được 1 mảnh")
	t.eq(lv.piece_label.text, "1/%d" % sp.size(), "HUD cập nhật")
	t.ok(lv.find_child("FlyingPiece", true, false) != null, "mảnh bay về chip")
	lv.free()
	_g(5)
	lv = (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing"), "vào chơi L5")
	t.ok(not lv.piece_chip.visible, "chưa mở leaderboard thì không có chip")
	lv.free()
