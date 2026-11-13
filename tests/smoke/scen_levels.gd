extends RefCounted
## Kịch bản V (quét level): chơi liền level `from`–`to` (mặc định 1–500) bằng solver và chạm thật, như người chơi đi
## hết đường level. Gọi qua scenarios.gd SCEN_FILES; trên máy thật chạy theo đợt (tools/device_smoke.sh, skill
## /device-test). Mỗi level in một dòng:
##   SMOKE LEVEL <n> ok taps=<chạm> moves=<còn>/<đầu> board=<cột>x<hàng>   (hỏng: SMOKE LEVEL FAIL L<n>: <lý do>)
## cộng SMOKE FRAMES L<n> và SMOKE SOLVER L<n> của runner. Kiểm: vào được level, hình nằm trong khung cổng và khung cổng
## nằm trong màn, thắng trong số MOVES (hết MOVES là hỏng), không lỗi script hay engine. Level hỏng hoặc chuyển level
## hỏng thì ghi lại, mở save mới ở level kế và chạy tiếp; cuối cùng SMOKE LEVELS <từ>-<tới> ok=<n> fail=<n>.

const Scen := preload("res://tests/smoke/scenarios.gd")
const Saves := preload("res://tests/smoke/smoke_saves.gd")

## Số vòng tối đa của một level (mỗi vòng một lần chạm hoặc một lần đóng popup).
const MAX_ROUNDS := 900


static func run(r, scen: String) -> bool:
	if scen == "V":
		return await scen_v(r)
	return r.fail("không có kịch bản %s" % scen)


static func scen_v(r) -> bool:
	var from := maxi(1, int(r.args.get("from", "1")))
	var to := maxi(from, int(r.args.get("to", "500")))
	var bad: Array[String] = []
	var ok_count := 0
	var next := from
	while next <= to:
		var start := next
		# From the special level's unlock the game opens on Home: Play enters the level.
		if not await r.open_game("V", func(g: Node) -> void: _prepare(g, start)) \
				or not await Scen.ensure_playing(r, start):
			bad.append(_take_fail(r, "L%d" % next, "không mở được game"))
			next += 1
			continue
		while next <= to:
			if not await _play_one(r, next):
				bad.append(_take_fail(r, "L%d" % next, "level hỏng"))
				next += 1
				break
			ok_count += 1
			if next == to:
				next += 1
				break
			# Chuyển level hỏng: ghi lại rồi mở save mới ở level kế, level kế vẫn được chơi.
			if not await _to_next(r, next):
				bad.append(_take_fail(r, "sau L%d" % next, "không sang được L%d" % (next + 1)))
				next += 1
				break
			next += 1
	print("SMOKE LEVELS %d-%d ok=%d fail=%d" % [from, to, ok_count, bad.size()])
	if not bad.is_empty():
		return r.fail("%d level hỏng: %s" % [bad.size(), "; ".join(bad.slice(0, 10))])
	return await Scen.verify_saved(r)


## Save ở level `level`: như người chơi đã qua các level trước (đã xem giới thiệu cơ chế trước đó, đã nhận quà booster),
## đủ mạng, gold và booster để popup mua không chặn đường.
static func _prepare(g: Node, level: int) -> void:
	Saves._at_level(g, level, false)
	g.s.coins = 5000
	for k in ["hint", "move", "smash"]:
		g.s.inv[k] = 3


## Lấy lý do hỏng của runner rồi xoá, để kịch bản chạy tiếp level sau. `label`: "L12" hoặc "sau L12".
static func _take_fail(r, label: String, fallback: String) -> String:
	var why := str(r.failed_reason)
	r.failed_reason = ""
	if why.is_empty():
		why = fallback
	print("SMOKE LEVEL FAIL %s: %s" % [label, why])
	return "%s: %s" % [label, why]


## Chơi level `n` đang mở tới khi thắng.
static func _play_one(r, n: int) -> bool:
	if not await Scen.wait_for(r, func() -> bool: return Scen._playing(r) == n, 20000):
		return r.fail("không vào trạng thái chơi của L%d (%s)" % [n, r.describe()])
	var lv: Control = r.level_screen()
	var bv: Control = lv.board_view
	var box: Rect2i = bv.content_box()
	if not bv.board_rect().grow(1.0).encloses(bv.content_rect()):
		return r.fail("L%d: hình %s ra ngoài khung cổng %s" % [n, str(bv.content_rect()), str(bv.board_rect())])
	var xf: Transform2D = bv.get_global_transform_with_canvas()
	var fr: Rect2 = bv.frame_rect()
	var frame := Rect2(xf * fr.position, xf.basis_xform(fr.size)).abs()
	if not r.view_rect().grow(2.0).encloses(frame):
		return r.fail("L%d: khung cổng %s ra ngoài màn %s" % [n, str(frame), str(r.view_rect())])
	# pace=<giây>: nghỉ giữa hai lần chạm như người chơi (đo khung hình); mặc định 2 khung, chạm liên tục.
	var pace := float(r.args.get("pace", "0"))
	var moves0: int = lv.board.moves_left()
	var taps := 0
	var misses := 0
	r.begin_phase("L%d" % n)
	for i in MAX_ROUNDS:
		if not r.failed_reason.is_empty():
			return false
		lv = r.level_screen()
		if lv == null or lv.board.is_won():
			break
		if lv.board.is_out_of_moves() or r.popup_script("popup_rescue.gd") != null:
			r.end_phase()
			return r.fail("L%d: hết MOVES sau %d lần chạm theo solver (MOVES đầu %d)" % [n, taps, moves0])
		if str(lv.state) != "playing":
			await Scen.settle(r)
			await r.wait_frames(1)
			continue
		if await r.tap_next_move():
			taps += 1
			misses = 0
		else:
			misses += 1
			if misses > 5:
				r.end_phase()
				return r.fail("L%d: 5 lần chạm liền không đi được (solver không có nước hoặc chạm trượt)" % n)
		if pace > 0.0:
			await r.wait_sec(pace)
		else:
			await r.wait_frames(2)
	r.end_phase()
	lv = r.level_screen()
	if lv != null and not lv.board.is_won():
		return r.fail("L%d chưa thắng sau %d vòng" % [n, MAX_ROUNDS])
	var left: int = lv.board.moves_left() if lv != null else -1
	print("SMOKE LEVEL %d ok taps=%d moves=%d/%d board=%dx%d" % [n, taps, left, moves0, box.size.x, box.size.y])
	return true


## Sau khi thắng L`n`: qua thẻ thắng (nếu có), đóng popup lạc; về Home thì bấm Chơi. Đạt khi L`n+1` đang mở.
static func _to_next(r, n: int) -> bool:
	if not await Scen.after_win(r, n):
		return false
	if r.screen_name() == "home":
		await Scen.settle_all(r)
		if not await Scen.tap_named(r, "PlayButton", r.main.current_screen):
			return false
	return true
