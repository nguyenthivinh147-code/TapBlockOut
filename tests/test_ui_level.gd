extends RefCounted
const T := preload("res://tests/t.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const BoardState := preload("res://src/core/board_state.gd")
const Config := preload("res://src/config.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")

const DIR := "user://test_ui_level"
const NOW := 1800000000


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _plat() -> Node:
	return _tree().root.get_node("Platform")


func _g(level: int = 1, gifted: bool = true) -> Node:
	DirAccess.make_dir_recursive_absolute(DIR)
	var g: Node = _tree().root.get_node("Game")
	g.reset_for_test(DIR + "/save.json")
	g.test_now = NOW
	var p := _plat()
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	p.save.last_json = ""
	g.s.level = level
	if gifted:
		for k in ["hint", "move", "smash"]:
			g.s.gifted[k] = true
	return g


func _mount() -> Control:
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(lv)
	lv.setup({})
	return lv


func _wait_until(cond: Callable, ms: int = 6000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await _tree().process_frame
	return cond.call()


func _playing(lv: Control) -> bool:
	return lv.state == "playing"


## Node tên `node_name` trong popup còn sống của màn level (lớp popup riêng khi chạy lẻ).
func _pop(lv: Control, node_name: String) -> Node:
	var ov := lv.get_node("LocalPopups")
	for c in ov.get_children():
		if c.is_queued_for_deletion():
			continue
		var n := c.find_child(node_name, true, false)
		if n != null:
			return n
	return null


func _has_pop(lv: Control, node_name: String) -> Callable:
	return func() -> bool: return _pop(lv, node_name) != null


func _press(lv: Control, node_name: String) -> void:
	(_pop(lv, node_name) as Button).pressed.emit()


## Chữ hiển thị của nút: nút prefab (unity_ui.gd) vẽ chữ bằng Label con, nút thường dùng Button.text.
func _btn_text(b: Button) -> String:
	if b.text != "":
		return b.text
	for l in b.find_children("*", "Label", true, false):
		if (l as Label).visible:
			return (l as Label).text
	return ""


func _solve(lv: Control) -> void:
	for i in 100:
		if lv.board.is_won():
			return
		var id: String = lv.board.hint()
		if id == "":
			return
		lv.board_view.block_tapped.emit(id)


## Level (2..9) có khối bị chặn ngay từ đầu: [level, id]; [0, ""] nếu không có.
func _blocked_level() -> Array:
	for lvn in range(2, 10):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level_%04d.json" % lvn))
		var b := BoardState.new(data)
		for id in b.block_ids():
			if b.peek(id) == "blocked":
				return [lvn, id]
	return [0, ""]


## Nền màn level: màu LEVEL_BG dưới cùng, ảnh bg_level trong suốt phủ lên, lớp dim phủ trên ảnh; giống nhau ở mọi độ khó.
func _check_bg(t: T, lv: Control, label: String) -> void:
	var bg := lv.get_node_or_null("Background")
	t.ok(bg != null and bg.get_index() == 0, "%s: nền nằm dưới cùng" % label)
	if bg == null:
		return
	var pic := bg.get_node_or_null("Image") as TextureRect
	t.ok(pic != null and pic.texture.resource_path == ThemeKit.LEVEL_BG_IMAGE, "%s: ảnh nền bg_level" % label)
	t.ok((bg as ColorRect).color == ThemeKit.LEVEL_BG, "%s: màu nền sau ảnh" % label)
	t.ok(pic != null and is_equal_approx(pic.modulate.a, ThemeKit.LEVEL_BG_IMAGE_ALPHA), "%s: ảnh nền trong suốt" % label)
	var dim := bg.get_node_or_null("Dim") as ColorRect
	t.ok(dim != null and dim.color == ThemeKit.LEVEL_BG_DIM, "%s: có lớp dim" % label)
	t.ok(pic != null and dim != null and dim.get_index() > pic.get_index(), "%s: dim phủ trên ảnh" % label)


func _burn_moves(lv: Control, id: String) -> void:
	for i in 40:
		if lv.board.moves_left() <= 0:
			return
		lv.board_view.block_tapped.emit(id)


func test_hud_level1(t: T) -> void:
	var g := _g(1)
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	t.eq(lv.state, "playing", "vào chơi")
	t.eq(_tree().root.get_node("Sfx").music_name, "bgm_level", "nhạc màn chơi")
	t.eq(lv.title_label.text, lv.tr("level_title") % 1, "tên level")
	t.eq(lv.moves_label.text, str(lv.board.moves_left()), "MOVES")
	t.ok(not lv.hard_badge.visible, "không HARD")
	_check_bg(t, lv, "L1")
	var toned: Array = lv.hud_toned()
	t.eq(toned.size(), 8, "restart, settings, 3 booster, khung MOVES, khung chip mảnh, pill HARD")
	t.ok(toned.has(lv.hard_badge), "pill HARD chỉnh tông")
	for c in toned:
		var m := (c as CanvasItem).material as ShaderMaterial
		t.ok(m != null and m.shader.resource_path == "res://src/ui/hud_tone.gdshader", "%s chỉnh tông" % c.name)
		if m != null:
			t.eq(m.get_shader_parameter("saturation"), Config.HUD_TONE_SAT, "saturation %s" % c.name)
			t.eq(m.get_shader_parameter("value"), Config.HUD_TONE_VAL, "value %s" % c.name)
			t.eq(m.get_shader_parameter("gloss_cut"), Config.HUD_TONE_GLOSS, "giảm bóng %s" % c.name)
	for k in ["hint", "move", "smash"]:
		t.ok(lv.booster_badges[k].material == null and lv.booster_locks[k].material == null,
				"nhãn số, ổ khoá booster %s giữ màu" % k)
	t.ok(lv.moves_label.material == null and lv.piece_label.material == null, "chữ MOVES, số mảnh giữ màu")
	for k in ["hint", "move", "smash"]:
		t.ok(lv.booster_buttons[k].get_parent().visible, "ô booster %s luôn hiện" % k)
		t.ok(lv.booster_locks[k].visible, "booster %s khoá ở L1" % k)
		t.ok(not lv.booster_badges[k].visible, "ô khoá không có nhãn số %s" % k)
		t.eq(lv.booster_caps[k].text, lv.tr("level_title") % int(Config.UNLOCK[k]), "ô khoá ghi level mở %s" % k)
	var inv_hint := int(g.s.inv.get("hint", 0))
	lv.booster_buttons.hint.pressed.emit()
	t.ok(lv.toast_label.visible, "chạm ô khoá hiện thông báo")
	t.eq(lv.toast_label.text, lv.tr("booster_locked") % int(Config.UNLOCK.hint), "báo level mở")
	t.eq(lv.state, "playing", "không mở hộp mua")
	t.eq(int(g.s.inv.get("hint", 0)), inv_hint, "không dùng booster")
	t.eq(lv.tut_label.text, lv.tr("tut_tap"), "hướng dẫn L1")
	t.eq(lv.board_view.highlighted_id(), lv.board.hint(), "chỉ khối đi được")
	t.eq(int(g.s.runs), 0, "chưa tính lượt")
	lv.free()


func test_win_l1_then_next_level(t: T) -> void:
	var g := _g(1)
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_solve(lv)
	t.ok(lv.board.is_won(), "thắng")
	t.ok(await _wait_until(_has_pop(lv, "ContinueButton")), "hiện thẻ thắng")
	t.eq(int(g.s.level), 2, "lên level 2")
	t.eq(int(g.s.coins), 1040 + 10 * int(lv.board.moves_left()), "+40 gold và 10 gold mỗi MOVES thừa")
	_press(lv, "ContinueButton")
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing" and int(lv.attempt.level) == 2), "sang level 2")
	t.eq(lv.title_label.text, lv.tr("level_title") % 2, "tên level 2")
	t.eq(int(g.s.runs), 1, "một lượt xong")
	lv.free()


## Thẻ thắng nạp nền từ lúc vào màn và hiện ngay khi khối cuối rời bàn, không nghỉ thêm nhịp nào.
func test_win_card_shows_right_after_the_last_block(t: T) -> void:
	_g(1)
	var lv := _mount()
	t.ok(ResourceLoader.load_threaded_get_status(lv.WIN_CARD) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
		"thẻ thắng nạp nền từ lúc vào màn")
	await _wait_until(_playing.bind(lv))
	_solve(lv)
	t.ok(await _wait_until(func() -> bool: return not lv.board_view.is_animating()), "khối cuối rời bàn")
	var t0 := Time.get_ticks_msec()
	t.ok(await _wait_until(_has_pop(lv, "ContinueButton"), 1000), "hiện thẻ thắng")
	t.ok(Time.get_ticks_msec() - t0 < 100, "không chờ thêm sau khi khối cuối rời bàn (%d ms)" % (Time.get_ticks_msec() - t0))
	lv.free()


func test_win_move_gold_flies_from_moves_chip(t: T) -> void:
	var g := _g(1)
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_solve(lv)
	var left: int = lv.board.moves_left()
	t.ok(left > 0, "dư MOVES")
	t.ok(await _wait_until(_has_pop(lv, "ContinueButton")), "hiện thẻ thắng")
	var reward := _pop(lv, "RewardLabel") as Label
	t.eq(reward.text, lv.tr("win_reward") % 40, "ô gold bắt đầu ở thưởng gốc")
	t.eq(lv.moves_label.text, str(left), "chip lượt chưa đổi")
	t.ok(await _wait_until(_has_pop(lv, "MoveGoldFx")), "gold bay từ chip lượt")
	t.ok(await _wait_until(func() -> bool: return reward.text == lv.tr("win_reward") % (40 + 10 * left)), "ô gold đếm lên đủ")
	t.eq(lv.moves_label.text, "0", "chip lượt về 0")
	t.eq(int(g.s.coins), 1040 + 10 * left, "ví chỉ cộng một lần")
	_press(lv, "ContinueButton")
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing" and int(lv.attempt.level) == 2), "sang level 2")
	t.eq(lv.moves_label.text, str(lv.board.moves_left()), "level 2 hiện đủ lượt")
	lv.free()


func test_win_move_gold_skipped_by_continue(t: T) -> void:
	var g := _g(1)
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_solve(lv)
	var left: int = lv.board.moves_left()
	t.ok(await _wait_until(_has_pop(lv, "ContinueButton")), "hiện thẻ thắng")
	var reward := _pop(lv, "RewardLabel") as Label
	t.ok(_pop(lv, "MoveGoldFx") == null, "gold chưa bay")
	_press(lv, "ContinueButton")
	t.eq(reward.text, lv.tr("win_reward") % (40 + 10 * left), "Tiếp tục ngay thì ô gold hiện đủ")
	t.eq(int(g.s.coins), 1040 + 10 * left, "ví chỉ cộng một lần")
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing" and int(lv.attempt.level) == 2), "sang level 2")
	t.eq(lv.moves_label.text, str(lv.board.moves_left()), "level 2 hiện đủ lượt, không trừ lượt đã đổi")
	lv.free()


func test_clap_after_long_think(t: T) -> void:
	_g(1)
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	t.ok(not lv.clap_label.visible, "chưa vỗ tay")
	for i in 3:
		await _tree().process_frame  # containers lay out the board holder before the player could tap
	lv.think_start_ms -= 20000
	lv.board_view.block_tapped.emit(lv.board.hint())
	t.ok(lv.clap_label.visible, "nghĩ lâu rồi đi đúng thì vỗ tay")
	# Lời khen ở trên khung, dưới hàng trên của HUD, không đè khung.
	var frame: Rect2 = lv.board_view.get_global_transform() * lv.board_view.frame_rect()
	var cl: Label = lv.clap_label
	var foot: Vector2 = cl.get_global_transform() * Vector2(cl.size.x * 0.5, cl.size.y)
	var row := lv.get_node("Margin/Column/TopBar/TopRow") as Control
	t.ok(foot.y <= frame.position.y, "đáy chữ khen trên mép khung (%.1f / %.1f)" % [foot.y, frame.position.y])
	t.ok(foot.y > row.get_global_rect().end.y, "chữ khen dưới hàng trên của HUD")
	t.ok(lv.get_node_or_null("Margin/Column/BoardHolder/PraiseFx") != null, "có hiệu ứng khen")
	lv.free()


func test_no_clap_when_quick(t: T) -> void:
	_g(1)
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	lv.board_view.block_tapped.emit(lv.board.hint())
	t.ok(not lv.clap_label.visible, "đi nhanh không vỗ tay")
	lv.free()


func test_rescue_need_coins_then_skip_to_lose(t: T) -> void:
	var bl := _blocked_level()
	t.ok(bl[0] > 0, "có level có khối bị chặn")
	var g := _g(bl[0])
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_burn_moves(lv, bl[1])
	t.eq(lv.board.moves_left(), 0, "hết MOVES")
	t.ok(await _wait_until(_has_pop(lv, "SkipButton")), "hiện popup cứu")
	t.eq((_pop(lv, "TitleLabel") as Label).text, lv.tr("rescue_title"), "là popup cứu")
	# thiếu gold: bấm mua mở shop mini, đóng thì quay lại popup
	_press(lv, "BuyButton")
	t.ok(await _wait_until(func() -> bool: return _shop_mini(lv) != null), "mở shop mini")
	_shop_mini(lv).close_button.pressed.emit()
	t.ok(await _wait_until(func() -> bool: return _shop_mini(lv) == null and _pop(lv, "SkipButton") != null), "quay lại popup")
	t.eq((_pop(lv, "TitleLabel") as Label).text, lv.tr("rescue_title"), "vẫn là popup cứu")
	t.ok(_pop(lv, "VideoButton") != null, "lần 1 có video")
	_press(lv, "SkipButton")  # dưới L10 không mất mạng nên không hỏi xác nhận
	t.ok(await _wait_until(_has_pop(lv, "RetryButton")), "hiện thẻ thua")
	t.eq(int(g.s.runs), 1, "thua tính một lượt")
	t.eq(int(g.s.lives.count), 10, "dưới L10 không mất mạng")
	_press(lv, "RetryButton")
	t.ok(await _wait_until(func() -> bool: return lv.state == "playing" and lv.board.moves_left() > 0), "chơi lại")
	t.eq(lv.board.remaining_count(), int(lv.attempt.count0), "bàn mới")
	lv.free()


func _offer_popup(lv: Control) -> Node:
	for c in lv.get_node("LocalPopups").get_children():
		if not c.is_queued_for_deletion() and "later_button" in c:
			return c
	return null


func _shop_mini(lv: Control) -> Node:
	var ov := lv.get_node("LocalPopups")
	for c in ov.get_children():
		if not c.is_queued_for_deletion() and "buy_buttons" in c and "close_button" in c and c.get_script().resource_path.ends_with("shop_mini.gd"):
			return c
	return null


func test_rescue_inventory(t: T) -> void:
	var bl := _blocked_level()
	var g := _g(bl[0])
	g.s.inv.move = 1
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_burn_moves(lv, bl[1])
	t.ok(await _wait_until(_has_pop(lv, "UseButton")), "có nút Dùng")
	_press(lv, "UseButton")
	t.ok(await _wait_until(_playing.bind(lv)), "chơi tiếp")
	t.eq(lv.board.moves_left(), 3, "+3 MOVES")
	t.eq(int(g.s.inv.move), 0, "trừ kho")
	t.eq(lv.moves_label.text, str(3), "HUD cập nhật")
	lv.free()


func test_rescue_gold(t: T) -> void:
	var bl := _blocked_level()
	var g := _g(bl[0])
	g.s.coins = 3000
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_burn_moves(lv, bl[1])
	await _wait_until(_has_pop(lv, "BuyButton"))
	_press(lv, "BuyButton")
	t.ok(await _wait_until(_playing.bind(lv)), "chơi tiếp sau khi mua")
	t.eq(int(g.s.coins), 1100, "trừ 1900 gold")
	t.eq(lv.board.moves_left(), 3, "+3 MOVES")
	# hết MOVES lần 2: giá 2200, mua đủ 4 lần thì lần 5 thua luôn
	var prices: Array = [2200, 2500, 2800]
	g.s.coins = 99999
	for i in prices.size():
		_burn_moves(lv, bl[1])
		t.ok(await _wait_until(_has_pop(lv, "BuyButton")), "popup lần %d" % (i + 2))
		t.eq(_btn_text(_pop(lv, "BuyButton") as Button), str(prices[i]), "giá lần %d" % (i + 2))
		var before: int = g.s.coins
		_press(lv, "BuyButton")
		t.ok(await _wait_until(_playing.bind(lv)), "chơi tiếp lần %d" % (i + 2))
		t.eq(before - int(g.s.coins), prices[i], "trừ đúng giá lần %d" % (i + 2))
	_burn_moves(lv, bl[1])
	t.ok(await _wait_until(_has_pop(lv, "RetryButton")), "quá 4 lần là thua luôn")
	t.ok(_pop(lv, "BuyButton") == null, "không còn popup cứu")
	lv.free()


func test_rescue_give_up_confirm_life(t: T) -> void:
	var bl := _blocked_level()
	var g := _g(bl[0])
	Config.LIVES.from_level = int(bl[0])
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_burn_moves(lv, bl[1])
	await _wait_until(_has_pop(lv, "SkipButton"))
	_press(lv, "SkipButton")
	t.ok(await _wait_until(_has_pop(lv, "ConfirmButton")), "hỏi xác nhận mất mạng")
	t.eq((_pop(lv, "TitleLabel") as Label).text, lv.tr("rescue_confirm_title"), "tiêu đề xác nhận")
	t.eq((_pop(lv, "BodyLabel") as Label).text, lv.tr("rescue_warn_life"), "nội dung xác nhận")
	t.eq(int(g.s.lives.count), 10, "chưa trừ mạng")
	_press(lv, "CancelButton")
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "TitleLabel") != null and (_pop(lv, "TitleLabel") as Label).text == lv.tr("rescue_title")), "huỷ thì quay lại popup cứu")
	t.eq(int(g.s.lives.count), 10, "huỷ không trừ mạng")
	_press(lv, "SkipButton")
	await _wait_until(_has_pop(lv, "ConfirmButton"))
	_press(lv, "ConfirmButton")
	t.ok(await _wait_until(_has_pop(lv, "RetryButton")), "hiện thẻ thua")
	t.eq(int(g.s.lives.count), 9, "mất 1 mạng")
	Config.reset()
	lv.free()


## Gốc popup (con của LocalPopups) chứa node `n`.
func _gift_root(n: Node) -> Control:
	while n != null and n.get_parent() != null and n.get_parent().name != "LocalPopups":
		n = n.get_parent()
	return n as Control


## "Chạm để tiếp tục": chạm đâu trên popup cũng đóng.
func _tap(pop: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	pop._gui_input(ev)


## Popup booster mới (scenes/booster_unlocked.tscn) đang mở, hoặc null.
func _gift_pop(lv: Control) -> Control:
	var tap := _pop(lv, "TapLabel")
	return null if tap == null else _gift_root(tap)


func test_booster_gift_and_hint(t: T) -> void:
	var g := _g(5, false)
	var lv := _mount()
	t.ok(await _wait_until(func() -> bool: return _gift_pop(lv) != null), "tặng booster ở L5 bằng popup booster mới")
	t.eq(lv.state, "intro", "chưa chơi khi đọc giới thiệu")
	t.eq(int(g.s.inv.hint), 1, "kho +1 gợi ý")
	var pop := _gift_pop(lv)
	const P := "GameObject/UnlockPanel/"
	t.eq(pop.ui.label(P + "BoosterName").text, lv.tr("booster_hint"), "tên booster")
	t.eq(pop.ui.label(P + "BoosterQuantity").text, lv.tr("booster_count") % 1, "số trong kho")
	t.eq(pop.ui.label(P + "BoosterDescription").text, lv.tr("tut_hint_gift"), "lời tặng")
	t.eq(pop.ui.image(P + "BoosterImage/Icon").get("tex"), ThemeKit.icon("booster_hint"), "icon booster")
	t.ok(not pop.ui.node(P + "ClaimButton").visible, "không có nút vàng: quà không bán kèm")
	t.eq((_pop(lv, "TapLabel") as Label).text, lv.tr("boot_tap_continue"), "dòng chạm để tiếp tục")
	_tap(pop)
	await _wait_until(_playing.bind(lv))
	t.ok(not lv.booster_locks.hint.visible, "gợi ý mở ở L5")
	t.eq(lv.booster_caps.hint.text, lv.tr("booster_hint"), "ô mở ghi tên booster")
	t.ok(lv.booster_locks.move.visible, "+3 Move chưa mở")
	t.eq(lv.booster_badges.hint.text, lv.tr("booster_count") % 1, "nhãn số còn lại")
	lv.booster_buttons.hint.pressed.emit()
	t.eq(int(g.s.inv.hint), 0, "dùng gợi ý")
	t.ok(lv.get_node_or_null("LocalPopups/HintFx") != null, "sao gợi ý bay từ nút")
	t.eq(lv.board_view.highlighted_id(), "", "chưa nháy khi sao còn bay")
	lv.booster_buttons.hint.pressed.emit()
	t.eq(int(g.s.inv.hint), 0, "bấm lại lúc sao bay không tốn thêm")
	var hint_id: String = lv.board.hint()
	t.ok(await _wait_until(func() -> bool: return lv.board_view.highlighted_id() == hint_id), "sao chạm thì nháy khối đi được")
	t.ok(await _wait_until(func() -> bool: return lv.get_node_or_null("LocalPopups/HintFx") == null), "hiệu ứng tự xoá")
	t.eq(lv.booster_badges.hint.text, "", "hết kho không ghi số")
	t.ok((lv.booster_badges.hint.get_theme_stylebox("normal") as StyleBoxTexture).texture.resource_path.ends_with("hud_badge_plus.png"), "hết kho hiện sprite dấu +")
	lv.free()


## Nhiều quà cùng lúc (L17 chưa nhận quà nào): popup booster mới hiện lần lượt theo Unlocks.GIFT_ORDER, không tốn gold.
func test_booster_gifts_in_order(t: T) -> void:
	var g := _g(17, false)
	var coins := int(g.s.coins)
	var lv := _mount()
	for kind in ["hint", "move", "smash"]:
		var shown := await _wait_until(func() -> bool:
			var p := _gift_pop(lv)
			return p != null and p.ui.label("GameObject/UnlockPanel/BoosterName").text == lv.tr("booster_" + kind))
		t.ok(shown, "popup quà " + kind)
		t.eq(lv.state, "intro", "chưa chơi khi còn popup quà " + kind)
		_tap(_gift_pop(lv))
	t.ok(await _wait_until(_playing.bind(lv)), "hết quà thì vào chơi")
	for kind in ["hint", "move", "smash"]:
		t.eq(int(g.s.inv[kind]), 1, "kho +1 " + kind)
	t.eq(int(g.s.coins), coins, "không trừ gold")
	lv.free()


## Level dạy cơ chế (L14 thùng sắt): popup booster mới giới thiệu cơ chế một lần, chơi lại không hiện nữa.
func test_mech_intro_popup(t: T) -> void:
	var g := _g(14)
	var inv: Dictionary = g.s.inv.duplicate()
	var lv := _mount()
	t.ok(await _wait_until(func() -> bool: return _gift_pop(lv) != null), "L14 mở popup cơ chế mới")
	t.eq(lv.state, "intro", "chưa chơi khi đọc giới thiệu")
	var pop := _gift_pop(lv)
	const P := "GameObject/UnlockPanel/"
	t.eq(pop.ui.label(P + "Image/txtHeader").text, lv.tr("mech_new_title"), "tiêu đề cơ chế mới")
	t.eq(pop.ui.label(P + "BoosterName").text, lv.tr("mech_stone"), "tên cơ chế")
	t.eq(pop.ui.label(P + "BoosterDescription").text, lv.tr("mech_stone_desc"), "luật cơ chế")
	t.eq(pop.ui.image(P + "BoosterImage/Icon").get("tex"), ThemeKit.icon("mech_stone"), "icon cơ chế")
	t.ok(not pop.ui.node(P + "BoosterQuantity").visible, "không có số lượng")
	t.ok(not pop.ui.node(P + "ClaimButton").visible, "không có nút vàng")
	t.eq((_pop(lv, "TapLabel") as Label).text, lv.tr("boot_tap_continue"), "dòng chạm để tiếp tục")
	t.eq(g.s.mech_seen, ["stone"], "đã ghi xem cơ chế")
	_tap(pop)
	t.ok(await _wait_until(_playing.bind(lv)), "chạm thì vào chơi")
	t.eq(lv.tut_label.text, "%s: %s" % [lv.tr("mech_stone"), lv.tr("mech_stone_desc")], "dòng luật vẫn ở đầu level")
	t.eq(g.s.inv, inv, "không tặng gì")
	lv.free()
	lv = _mount()
	t.ok(await _wait_until(_playing.bind(lv)), "chơi lại L14: vào chơi ngay, không hiện lại")
	t.eq(_gift_pop(lv), null, "không có popup")
	lv.free()


func test_booster_buy_move(t: T) -> void:
	var g := _g(12)
	g.s.coins = 2500
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	var before: int = lv.board.moves_left()
	lv.booster_buttons.move.pressed.emit()
	t.ok(await _wait_until(_has_pop(lv, "BuyButton")), "hộp mua booster")
	var buy := _pop(lv, "BuyButton") as Button
	t.eq(_btn_text(buy), "1900", "nút mua chỉ ghi giá")
	t.ok((UnityUI.image_of(buy).get("tex") as Texture2D).resource_path.ends_with("atlas_main.png"), "nút mua là pill vàng atlas_main")
	t.eq(buy.modulate.a, 1.0, "đủ gold thì không làm mờ")
	t.ok(_pop(lv, "VideoButton") == null, "đủ gold thì không mời video")
	_press(lv, "BuyButton")
	await _wait_until(func() -> bool: return int(g.s.coins) == 600)
	t.eq(int(g.s.coins), 600, "trừ 1900")
	t.ok(await _wait_until(_playing.bind(lv)), "quay lại chơi")
	t.eq(lv.board.moves_left(), before + 3, "+3 MOVES")
	lv.free()


func test_booster_free_video_repeat(t: T) -> void:
	var g := _g(12)
	g.s.coins = 0
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	var before: int = lv.board.moves_left()
	lv.booster_buttons.move.pressed.emit()
	t.ok(await _wait_until(_has_pop(lv, "VideoButton")), "thiếu gold thì mời video")
	t.ok((_pop(lv, "BuyButton") as Control).modulate.a < 1.0, "thiếu gold thì nút mua mờ")
	_press(lv, "VideoButton")
	t.ok(await _wait_until(func() -> bool: return lv.board.moves_left() == before + 3), "xem xong dùng luôn")
	t.eq(int(g.s.coins), 0, "không tốn gold")
	t.eq(int(g.s.inv.move), 0, "đã dùng hết")
	await _wait_until(_playing.bind(lv))
	lv.booster_buttons.move.pressed.emit()
	t.ok(await _wait_until(_has_pop(lv, "VideoButton")), "cùng lượt vẫn mời video lần hai")
	_press(lv, "VideoButton")
	t.ok(await _wait_until(func() -> bool: return lv.board.moves_left() == before + 6), "video lần hai dùng luôn")
	t.eq(int(g.s.inv.move), 0, "đã dùng hết")
	await _wait_until(_playing.bind(lv))
	lv.booster_buttons.hint.pressed.emit()
	t.ok(await _wait_until(_has_pop(lv, "VideoButton")), "booster khác cũng mời video")
	_press(lv, "CloseButton")
	t.ok(await _wait_until(_playing.bind(lv)), "đóng hộp thì chơi tiếp")
	lv.free()


func test_booster_video_closed_early(t: T) -> void:
	var g := _g(12)
	g.s.coins = 0
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_plat().ads.simulate("closed")
	lv.booster_buttons.move.pressed.emit()
	await _wait_until(_has_pop(lv, "VideoButton"))
	_press(lv, "VideoButton")
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "MessageLabel") != null and (_pop(lv, "MessageLabel") as Label).visible), "báo đóng sớm")
	t.eq(int(g.s.inv.move), 0, "không thưởng")
	_press(lv, "CloseButton")
	await _wait_until(_playing.bind(lv))
	lv.free()


func test_booster_smash(t: T) -> void:
	var g := _g(17)
	g.s.inv.smash = 1
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	var n: int = lv.board.remaining_count()
	lv.booster_buttons.smash.pressed.emit()
	t.ok(lv.smash_label.visible, "báo chọn khối để phá")
	t.ok(not lv.tut_label.visible, "chữ hướng dẫn nhường chỗ cho nhãn Phá khối")
	t.eq(int(g.s.inv.smash), 1, "chưa trừ kho tới khi chọn")
	lv.booster_buttons.smash.pressed.emit()
	t.ok(not lv.smash_label.visible, "bấm lại thì huỷ")
	t.eq(lv.tut_label.visible, lv.tut_label.text != "", "huỷ thì chữ hướng dẫn hiện lại (không có chữ thì ẩn khung)")
	lv.booster_buttons.smash.pressed.emit()
	lv.board_view.block_tapped.emit(lv.board.block_ids()[0])
	t.eq(lv.board.remaining_count(), n - 1, "khối bị phá")
	t.eq(int(g.s.inv.smash), 0, "trừ kho")
	t.ok(not lv.smash_label.visible, "thoát chế độ phá")
	lv.free()


func test_hint_none_does_not_consume(t: T) -> void:
	var g := _g(4)
	g.s.inv.hint = 1
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_solve(lv)  # bàn trống: hint rỗng
	await _wait_until(func() -> bool: return lv.state != "playing")
	lv.free()
	t.eq(int(g.s.inv.hint), 1, "không dùng khi bàn xong")


func _exit_count(lv: Control) -> int:
	var n := 0
	for id in lv.board.block_ids():
		if lv.board.can_exit(id):
			n += 1
	return n


func _idle_away(lv: Control) -> void:
	lv.idle_start_ms -= int(Config.CONTENT.idle_hint_sec) * 1000 + 100


## Treo máy: nút Gợi ý lắc, bóng đèn vàng phủ lên, bong bóng ghi số khối thoát được rồi tự tắt.
func test_idle_hint_nudge(t: T) -> void:
	_g(6)
	Config.CONTENT.idle_hint_show_sec = 0.3
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	var bulb := lv.get_node("%BoosterNudge_hint") as TextureRect
	await _tree().process_frame
	t.ok(not lv.idle_tip.visible and not bulb.visible, "chưa treo thì chưa nhắc")
	_idle_away(lv)
	t.ok(await _wait_until(func() -> bool: return bulb.visible), "treo đủ lâu thì bóng đèn vàng hiện")
	t.ok(await _wait_until(func() -> bool: return lv.idle_tip.visible), "lắc xong hiện bong bóng")
	t.eq((lv.get_node("%IdleTipLabel") as Label).text, lv.tr("level_idle_blocks"), "chữ bong bóng")
	t.eq((lv.get_node("%IdleTipCount") as Label).text, str(_exit_count(lv)), "số khối thoát được")
	var r: Rect2 = lv.booster_buttons.hint.get_global_rect()
	t.ok(r.grow(8).has_point(lv.idle_tip.get_global_rect().position), "đuôi bong bóng chỉ vào nút Gợi ý")
	t.ok(await _wait_until(func() -> bool: return not lv.idle_tip.visible, 3000), "tự tắt")
	t.ok(not bulb.visible, "bóng đèn về như cũ")
	t.eq(lv.booster_buttons.hint.rotation, 0.0, "nút hết lắc")
	t.eq(lv.state, "playing", "vẫn đang chơi")
	Config.reset()
	lv.free()


func test_idle_hint_touch_closes(t: T) -> void:
	var g := _g(6)
	g.s.inv.hint = 2
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_idle_away(lv)
	t.ok(await _wait_until(func() -> bool: return lv.idle_tip.visible), "hiện bong bóng nhắc")
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	lv._input(ev)
	t.ok(not lv.idle_tip.visible, "chạm màn hình thì tắt ngay")
	t.ok(not (lv.get_node("%BoosterNudge_hint") as TextureRect).visible, "bóng đèn về như cũ")
	for i in 5:
		await _tree().process_frame
	t.ok(not lv.idle_tip.visible, "chạm tính lại thời gian treo")
	# Lời nhắc không chặn chạm: chạm nút Gợi ý lúc đang nhắc vẫn dùng booster.
	_idle_away(lv)
	await _wait_until(func() -> bool: return lv.idle_tip.visible)
	lv._input(ev)
	lv.booster_buttons.hint.pressed.emit()
	t.eq(int(g.s.inv.hint), 1, "chạm nút Gợi ý vẫn dùng booster")
	lv.free()


func test_idle_hint_not_when_locked_or_busy(t: T) -> void:
	_g(3)
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	_idle_away(lv)
	for i in 10:
		await _tree().process_frame
	t.ok(not lv.idle_tip.visible, "Gợi ý chưa mở thì không nhắc")
	lv.free()
	_g(6)
	lv = _mount()
	await _wait_until(_playing.bind(lv))
	lv.settings_button.pressed.emit()
	await _wait_until(_has_pop(lv, "CloseX"))
	_idle_away(lv)
	for i in 10:
		await _tree().process_frame
	t.ok(not lv.idle_tip.visible, "có popup thì không nhắc")
	(_pop(lv, "CloseX") as Button).pressed.emit()
	await _wait_until(_playing.bind(lv))
	for i in 10:
		await _tree().process_frame
	t.ok(not lv.idle_tip.visible, "đóng popup thì đếm lại từ đầu")
	lv.free()


func test_restart_free_before_l10(t: T) -> void:
	var g := _g(3)
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	lv.board_view.block_tapped.emit(lv.board.hint())
	lv.restart_button.pressed.emit()
	await _wait_until(func() -> bool: return lv.state == "playing" and lv.board.remaining_count() == int(lv.attempt.count0))
	t.ok(_pop(lv, "ConfirmButton") == null, "dưới L10 không hỏi")
	t.eq(int(g.s.lives.count), 10, "không mất mạng")
	t.eq(lv.board.remaining_count(), int(lv.attempt.count0), "bàn mới")
	lv.free()


func test_restart_confirm_costs_life_from_l10(t: T) -> void:
	var g := _g(10)
	var lv := _mount()
	await _wait_until(_playing.bind(lv))
	# chưa chạm: có hỏi nhưng miễn phí
	lv.restart_button.pressed.emit()
	t.ok(await _wait_until(_has_pop(lv, "ConfirmButton")), "từ L10 có xác nhận")
	t.eq((_pop(lv, "BodyLabel") as Label).text, lv.tr("level_restart_confirm_free"), "chưa chạm thì miễn phí")
	_press(lv, "CancelButton")
	t.ok(await _wait_until(_playing.bind(lv)), "huỷ thì chơi tiếp")
	t.eq(int(g.s.lives.count), 10, "huỷ không mất mạng")
	# đã chạm
	lv.board_view.block_tapped.emit(lv.board.hint())
	lv.restart_button.pressed.emit()
	await _wait_until(_has_pop(lv, "ConfirmButton"))
	t.eq((_pop(lv, "BodyLabel") as Label).text, lv.tr("level_restart_confirm_life"), "đã chạm thì tốn mạng")
	_press(lv, "ConfirmButton")
	await _wait_until(func() -> bool: return lv.state == "playing" and int(lv.attempt.taps) == 0)
	t.eq(int(g.s.lives.count), 9, "mất 1 mạng")
	lv.free()


func test_restart_last_life_goes_no_lives(t: T) -> void:
	var g := _g(10)
	g.s.lives.count = 1
	g.s.lives.next_at = NOW + 900
	var lv := _mount()
	var st := {}
	lv.closed.connect(func(r: Variant) -> void: st["r"] = r)
	await _wait_until(_playing.bind(lv))
	lv.board_view.block_tapped.emit(lv.board.hint())
	lv.restart_button.pressed.emit()
	await _wait_until(_has_pop(lv, "ConfirmButton"))
	_press(lv, "ConfirmButton")
	await _wait_until(func() -> bool: return st.has("r"))
	t.eq(st.get("r"), {"action": "no_lives"}, "hết mạng thì sang màn no_lives")
	lv.free()


func test_home_button(t: T) -> void:
	var g := _g(10)
	var lv := _mount()
	var st := {}
	lv.closed.connect(func(r: Variant) -> void: st["r"] = r)
	await _wait_until(_playing.bind(lv))
	lv.board_view.block_tapped.emit(lv.board.hint())
	lv.on_back()
	await _wait_until(_has_pop(lv, "ConfirmButton"))
	t.eq((_pop(lv, "BodyLabel") as Label).text, lv.tr("rescue_warn_life"), "cảnh báo mất mạng")
	_press(lv, "CancelButton")
	await _wait_until(_playing.bind(lv))
	t.ok(not st.has("r"), "huỷ thì ở lại")
	lv.on_back()
	await _wait_until(_has_pop(lv, "ConfirmButton"))
	_press(lv, "ConfirmButton")
	await _wait_until(func() -> bool: return st.has("r"))
	t.eq(st.get("r"), {"action": "home"}, "về Home")
	t.eq(int(g.s.lives.count), 9, "bỏ giữa chừng mất 1 mạng")
	lv.free()


func test_settings_popup_home_and_retry(t: T) -> void:
	var g := _g(10)
	var lv := _mount()
	var st := {}
	lv.closed.connect(func(r: Variant) -> void: st["r"] = r)
	await _wait_until(_playing.bind(lv))
	# đóng bằng X: chơi tiếp
	lv.settings_button.pressed.emit()
	await _wait_until(_has_pop(lv, "RetryButton"))
	(_pop(lv, "CloseX") as Button).pressed.emit()
	await _wait_until(_playing.bind(lv))
	t.ok(not st.has("r"), "X thì ở lại")
	# Retry khi đã chạm: qua hỏi xác nhận mất mạng
	lv.board_view.block_tapped.emit(lv.board.hint())
	lv.settings_button.pressed.emit()
	await _wait_until(_has_pop(lv, "RetryButton"))
	_press(lv, "RetryButton")
	t.ok(await _wait_until(_has_pop(lv, "ConfirmButton")), "Retry hỏi xác nhận")
	_press(lv, "CancelButton")
	await _wait_until(_playing.bind(lv))
	# Home qua popup cài đặt
	lv.settings_button.pressed.emit()
	await _wait_until(_has_pop(lv, "HomeButton"))
	_press(lv, "HomeButton")
	await _wait_until(_has_pop(lv, "ConfirmButton"))
	_press(lv, "ConfirmButton")
	await _wait_until(func() -> bool: return st.has("r"))
	t.eq(st.get("r"), {"action": "home"}, "về Home")
	t.eq(int(g.s.lives.count), 9, "bỏ giữa chừng mất 1 mạng")
	lv.free()


func test_demo_end_returns_home(t: T) -> void:
	var g := _g(20)
	Config.demo_override = 1
	var lv := _mount()
	var st := {}
	lv.closed.connect(func(r: Variant) -> void: st["r"] = r)
	await _wait_until(_playing.bind(lv))
	_solve(lv)
	await _wait_until(_has_pop(lv, "ContinueButton"))
	_press(lv, "ContinueButton")
	t.ok(await _wait_until(func() -> bool: return _pop(lv, "OkButton") != null or _offer_popup(lv) != null), "báo hết level hoặc offer")
	if _offer_popup(lv) != null:
		_offer_popup(lv).later_button.pressed.emit()
	t.ok(await _wait_until(_has_pop(lv, "OkButton")), "báo hết level")
	t.eq(int(g.s.level), 21, "đã lên L21")
	_press(lv, "OkButton")
	await _wait_until(func() -> bool: return st.has("r"))
	t.eq(st.get("r"), {"action": "home"}, "về Home")
	lv.free()
	Config.demo_override = -1


## Bản phát hành (override 0): thắng L20 thì đi tiếp L21, không có hộp báo hết level.
func test_release_continues_after_l20(t: T) -> void:
	var g := _g(20)
	Config.demo_override = 0
	var lv := _mount()
	var st := {}
	lv.closed.connect(func(r: Variant) -> void: st["r"] = r)
	await _wait_until(_playing.bind(lv))
	_solve(lv)
	await _wait_until(_has_pop(lv, "ContinueButton"))
	_press(lv, "ContinueButton")
	t.ok(await _wait_until(func() -> bool:
		if _offer_popup(lv) != null:
			_offer_popup(lv).later_button.pressed.emit()
		return _playing(lv) and int(lv.attempt.level) == 21), "vào thẳng L21")
	t.ok(_pop(lv, "OkButton") == null, "không có hộp báo hết level")
	t.ok(not st.has("r"), "chưa rời màn level")
	t.eq(int(g.s.level), 21, "đã lên L21")
	lv.free()
	Config.demo_override = -1


## Level HARD/VERY HARD hiện dải cảnh báo rồi tự vào chơi; chơi lại không hiện lại.
func test_hard_warning(t: T) -> void:
	_g(23)
	var lv := _mount()
	t.ok(await _wait_until(func() -> bool: return lv.find_child("DifficultyBanner", true, false) != null), "L23 có dải cảnh báo")
	t.ok(not _playing(lv), "chưa chơi khi đang cảnh báo")
	t.eq(lv.hard_badge.text, lv.tr("level_hard"), "huy hiệu KHÓ")
	t.eq((lv.find_child("Text", true, false) as Label).text, lv.tr("level_hard"), "dải ghi KHÓ")
	_check_bg(t, lv, "L23 (Hard)")
	t.ok(await _wait_until(_playing.bind(lv)), "tự vào chơi")
	lv.free()
	_g(33)
	lv = _mount()
	t.ok(await _wait_until(func() -> bool: return lv.find_child("DifficultyBanner", true, false) != null), "L33 (VeryHard) có dải cảnh báo")
	t.eq(lv.hard_badge.text, lv.tr("level_very_hard"), "huy hiệu RẤT KHÓ")
	_check_bg(t, lv, "L33 (VeryHard)")
	t.ok(await _wait_until(_playing.bind(lv)), "L33 tự vào chơi")
	lv._on_restart_pressed()
	await _wait_until(func() -> bool: return _pop(lv, "ConfirmButton") != null or _playing(lv))
	if _pop(lv, "ConfirmButton") != null:
		_press(lv, "ConfirmButton")
	await _wait_until(_playing.bind(lv))
	t.ok(lv.find_child("DifficultyBanner", true, false) == null, "chơi lại không cảnh báo")
	lv.free()


# --- main ---

func _main() -> Control:
	var m := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	_tree().root.add_child(m)
	return m


func test_main_navigation(t: T) -> void:
	var g := _g(1)
	var m := _main()
	var curtained := [false]
	t.ok(await _wait_until(func() -> bool:
		curtained[0] = curtained[0] or m.curtain != null
		return m.is_booted), "boot xong")
	t.eq(m.current_name, "level", "mở game vào thẳng level")
	t.ok(not curtained[0], "mở game không chạy màn chuyển cảnh")
	t.eq(int(g.s.meta.sessions), 1, "Game.boot đã chạy")
	t.eq(_tree().root.get_node("Sfx").music_name, "bgm_level", "nhạc level")
	await _wait_until(func() -> bool: return m.current_screen.state == "playing")
	m.current_screen.on_back()
	await _wait_until(func() -> bool: return m.current_name == "home")
	t.eq(m.current_name, "home", "level đầu phiên -> Home")
	m.current_screen.find_child("PlayButton", true, false).pressed.emit()
	t.ok(m.curtain != null, "Chơi mở màn chuyển cảnh")
	t.eq(str(m.curtain.name), "CandyCurtain", "Chơi dùng màn kẹo rơi")
	t.eq(m.current_name, "home", "Home còn đó tới khi kẹo phủ kín")
	t.ok(await _wait_until(func() -> bool: return m.current_name == "level" and m.curtain == null), "Chơi -> level")
	await _wait_until(func() -> bool: return m.current_screen.state == "playing")
	m.current_screen.on_back()
	await _wait_until(func() -> bool: return m.current_name == "home")
	t.eq(m.current_name, "home", "Home từ level")
	# popup settings, Back đóng
	m.current_screen.find_child("SettingsButton", true, false).pressed.emit()
	t.eq(m.popup_count(), 1, "mở Settings")
	m._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	t.eq(m.popup_count(), 0, "Back đóng popup")
	# quà chưa mở ở L1 nên bỏ qua; profile
	m.current_screen.find_child("ProfileButton", true, false).pressed.emit()
	t.eq(m.current_name, "profile", "Profile")
	m.current_screen.closed.emit({"action": "back"})
	t.eq(m.current_name, "home", "Profile -> Home")
	# no_lives
	g.s.level = 10
	g.s.lives.count = 0
	g.s.lives.next_at = NOW + 900
	m.go("home")
	m.current_screen.find_child("PlayButton", true, false).pressed.emit()
	t.eq(m.current_name, "no_lives", "hết mạng -> no_lives")
	m.current_screen.closed.emit("home")
	t.eq(m.current_name, "home", "no_lives -> Home")
	m.current_screen.closed.emit({"action": "challenge"})
	t.eq(m.current_name, "home", "challenge đang khoá")
	m.free()


## Mở game khi không bắt đầu level được thì vào Home: hết mạng (như Chơi ở Home), hoặc demo đã hết level.
func test_main_boot_home_when_cannot_play(t: T) -> void:
	var g := _g(10)
	g.s.lives.count = 0
	g.s.lives.next_at = NOW + 900
	g.save_now()
	var m := _main()
	t.ok(await _wait_until(func() -> bool: return m.is_booted), "boot xong")
	t.eq(int(g.s.level), 10, "boot nạp bản lưu")
	t.eq(m.current_name, "home", "hết mạng: vào Home")
	t.eq(m.curtain, null, "không màn chuyển cảnh")
	g.s.lives.count = 1
	t.ok(m.boot_to_level(), "còn mạng: vào level")
	Config.demo_override = 1
	g.s.level = int(Config.CONTENT.demo_max_level) + 1
	t.ok(not m.boot_to_level(), "demo hết level: vào Home")
	Config.demo_override = -1
	m.free()


func test_main_routes_challenge_action(t: T) -> void:
	var g := _g(60)
	var m := _main()
	t.ok(await _wait_until(func() -> bool: return m.is_booted), "boot xong")
	g.s.level = 60
	m.go("home")
	m.current_screen.closed.emit({"action": "challenge"})
	t.eq(m.current_name, "home", "Daily Challenge tắt (Config.FEATURES): ở lại Home")
	Config.FEATURES.challenge = true
	m.go("home")
	m.current_screen.closed.emit({"action": "challenge"})
	t.eq(m.current_name, "challenge", "Home phát challenge -> màn challenge")
	t.ok(g.in_level, "challenge tính là đang chơi")
	m.go("home")
	t.ok(not g.in_level, "về Home thì hết in_level")
	m.free()


func test_main_level_routes_use_main_popups(t: T) -> void:
	var bl := _blocked_level()
	var g := _g(bl[0])
	var m := _main()
	await _wait_until(func() -> bool: return m.is_booted)
	g.s.level = bl[0]
	g.s.coins = 5000
	m.go("level")
	var lv: Control = m.current_screen
	await _wait_until(_playing.bind(lv))
	_burn_moves(lv, bl[1])
	t.ok(await _wait_until(func() -> bool: return m.popup_count() == 1), "popup cứu nằm trong lớp popup của main")
	m._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)  # Back = bỏ qua (dưới L10 không hỏi xác nhận)
	t.ok(await _wait_until(func() -> bool: return m.popup_count() == 1 and lv.state == "over"), "sang thẻ thua")
	t.eq(lv.get_node("LocalPopups").get_child_count(), 0, "không dùng lớp riêng")
	m.free()


# --- bố cục thật: bàn nằm trọn, căn giữa trong BoardHolder ---

func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _check_fit(t: T, lv: Control, tag: String) -> void:
	var holder := lv.find_child("BoardHolder", true, false) as Control
	var bv: Control = lv.board_view
	var hs := holder.size
	t.ok(hs.x > 100.0 and hs.y > 100.0, "%s: holder có kích thước (%s)" % [tag, str(hs)])
	t.ok(bv.size.is_equal_approx(hs), "%s: BoardView = holder (%s vs %s)" % [tag, str(bv.size), str(hs)])
	t.ok(bv.position.length() <= 1.0, "%s: BoardView ở góc holder (%s)" % [tag, str(bv.position)])
	var br: Rect2 = bv.board_rect()
	t.ok(Rect2(Vector2.ZERO, hs).grow(1.5).encloses(bv.frame_rect()), "%s: bàn cùng cổng nằm trọn holder (%s trong %s)" % [tag, str(br), str(hs)])
	var off := (br.get_center() - hs * 0.5).abs()
	t.ok(off.x <= 2.0 and off.y <= 2.0, "%s: căn giữa (lệch %s)" % [tag, str(off)])
	t.near(br.size.x / br.size.y, Config.BOARD_AREA.x / Config.BOARD_AREA.y, 0.01, "%s: khung giữ tỉ lệ ảnh ref" % tag)
	t.ok(br.encloses(bv.content_rect()), "%s: hình nằm trong khung" % tag)
	var coff: Vector2 = (bv.content_rect().get_center() - br.get_center()).abs()
	t.ok(coff.x <= 1.0 and coff.y <= 1.0, "%s: hình ở giữa khung (lệch %s)" % [tag, str(coff)])
	var ids: Array[String] = lv.board.block_ids()
	if not ids.is_empty():
		var n: Control = bv.block_node(ids[0])
		t.ok(n != null and bv.block_at(bv.cell_center(n.cells[0])) == ids[0], "%s: vùng chạm đúng ô khối" % tag)


func _fit_level(t: T, level: int) -> void:
	_g(level)
	var host := Control.new()
	host.size = Config.BOARD_SCREEN
	_tree().root.add_child(host)
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	host.add_child(lv)
	lv.setup({})
	await _wait_until(_playing.bind(lv))
	await _frames(4)
	var bv: Control = lv.board_view
	var vp: Vector2 = bv.get_viewport_rect().size
	var s := minf(vp.x / Config.BOARD_SCREEN.x, vp.y / Config.BOARD_SCREEN.y)
	_check_fit(t, lv, "L%d 886x1920" % level)
	t.ok(bv.board_rect().size.is_equal_approx(Config.BOARD_AREA * s), "L%d 886x1920: khung đúng cỡ chuẩn (%s)" % [level, str(bv.board_rect().size)])
	t.ok(bv.cell_size() <= Config.BOARD_CELL_MAX * s, "L%d 886x1920: ô không quá cỡ khối trong ảnh ref" % level)
	var cell: float = bv.cell_size()
	# màn logic của game luôn từ 886x1920 trở lên (stretch expand); 720x1280 là vùng nhỏ hơn chuẩn mà HUD vẫn chừa chỗ cho bàn
	host.size = Vector2(720, 1280)
	await _frames(4)
	_check_fit(t, lv, "L%d 720x1280" % level)
	t.ok(bv.board_rect().size.x < Config.BOARD_AREA.x * s, "L%d 720x1280: khung co lại" % level)
	host.size = Config.BOARD_SCREEN
	await _frames(4)
	_check_fit(t, lv, "L%d về 886x1920" % level)
	t.near(bv.cell_size(), cell, 0.001, "L%d về 886x1920: ô như lúc đầu" % level)
	host.free()


## Khung đứng cùng một chỗ ở mọi level, kể cả L1 chưa mở booster và level có badge HARD.
func test_board_same_place_across_levels(t: T) -> void:
	var rects: Array[Rect2] = []
	for level in [1, 8, 21]:
		_g(level)
		var host := Control.new()
		host.size = Vector2(720, 1280)
		_tree().root.add_child(host)
		var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
		host.add_child(lv)
		lv.setup({})
		await _wait_until(_playing.bind(lv))
		await _frames(4)
		var bv: Control = lv.board_view
		rects.append(Rect2(bv.global_position + bv.frame_rect().position, bv.frame_rect().size))
		host.free()
	for i in range(1, rects.size()):
		t.ok(rects[i].is_equal_approx(rects[0]), "khung trùng nhau: %s và %s" % [str(rects[0]), str(rects[i])])


func test_board_fits_holder_l1(t: T) -> void:
	await _fit_level(t, 1)


func test_board_fits_holder_l8(t: T) -> void:
	await _fit_level(t, 8)


func test_board_fits_holder_l14(t: T) -> void:
	await _fit_level(t, 14)


func test_board_fits_holder_l20(t: T) -> void:
	await _fit_level(t, 20)


## Dòng chú thích (hướng dẫn cơ chế L14, xuống hai dòng; chữ chọn khối để đập) nằm trong khung bong bóng ngay trên mép
## khung bàn, không đè thanh trên, cả khi khung bàn đổi chỗ theo cỡ màn. Dòng ngắn thì bong bóng ôm chữ, dòng dài thì
## rộng bằng khung bàn; không có chữ thì ẩn bong bóng.
func test_caption_above_frame(t: T) -> void:
	var g := _g(14)
	g.s.mech_seen = ["stone"]
	var host := Control.new()
	host.size = Config.BOARD_SCREEN
	_tree().root.add_child(host)
	var lv := (load("res://scenes/level.tscn") as PackedScene).instantiate() as Control
	host.add_child(lv)
	lv.setup({})
	await _wait_until(_playing.bind(lv))
	await _frames(4)
	var tut: Label = lv.tut_label
	var smash: Label = lv.smash_label
	t.ok(tut.text != "", "L14 có hướng dẫn cơ chế")
	t.ok(tut.visible, "hướng dẫn hiện")
	t.ok(tut.get_line_count() >= 2, "hướng dẫn xuống dòng (%d dòng)" % tut.get_line_count())
	for l: Label in [tut, smash]:
		t.ok(l.get_theme_stylebox("normal") is StyleBoxFlat, "%s có khung bong bóng" % l.name)
	var top_bar := lv.find_child("TopBar", true, false) as Control
	for sz in [Config.BOARD_SCREEN, Vector2(886, 2200), Vector2(720, 1280)]:
		host.size = sz
		await _frames(4)
		var bv: Control = lv.board_view
		var frame := Rect2(bv.global_position + bv.frame_rect().position, bv.frame_rect().size)
		for l: Label in [tut, smash]:
			var r := l.get_global_rect()
			t.ok(r.end.y <= frame.position.y + 0.5, "%s %s: đáy khung chữ %.1f trên mép khung bàn %.1f" % [l.name, str(sz), r.end.y, frame.position.y])
			t.ok(r.end.y >= frame.position.y - Config.BOARD_CAPTION_GAP - 1.0, "%s %s: sát khung bàn (%.1f, %.1f)" % [l.name, str(sz), r.end.y, frame.position.y])
			t.ok(r.size.x <= frame.size.x + 1.0, "%s %s: không rộng hơn khung bàn (%.1f / %.1f)" % [l.name, str(sz), r.size.x, frame.size.x])
			t.near(r.get_center().x, frame.get_center().x, 1.0, "%s %s: giữa khung bàn" % [l.name, str(sz)])
		t.ok(smash.size.x < frame.size.x * 0.9, "%s: chữ đập một dòng, bong bóng ôm chữ (%.1f)" % [str(sz), smash.size.x])
		if sz.y >= Config.BOARD_SCREEN.y:
			var tr_rect := tut.get_global_rect()
			t.ok(tr_rect.position.y >= top_bar.get_global_rect().end.y, "%s: hướng dẫn không đè HUD (%.1f)" % [str(sz), tr_rect.position.y])
	lv._set_smash_mode(true)
	t.ok(smash.visible and not tut.visible, "chế độ đập: chữ đập thay chỗ hướng dẫn")
	lv._set_smash_mode(false)
	t.ok(tut.visible and not smash.visible, "hết chế độ đập: hướng dẫn hiện lại")
	lv._set_tut("")
	t.ok(not tut.visible, "không có chữ thì ẩn bong bóng")
	host.free()
