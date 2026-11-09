extends RefCounted
## Màn đặc biệt: bộ sinh bàn, đặt bom (src/core/special_board.gd) và vé (src/meta/special_bomb.gd).

const T := preload("res://tests/t.gd")
const Config := preload("res://src/config.gd")
const SpecialBoard := preload("res://src/core/special_board.gd")
const SpecialBomb := preload("res://src/meta/special_bomb.gd")
const SaveSchema := preload("res://src/meta/save_schema.gd")
const BoardState := preload("res://src/core/board_state.gd")
const LevelData := preload("res://src/core/level_data.gd")
const Solver := preload("res://src/core/solver.gd")


func _board_ok(t: T, d: Dictionary, tag: String) -> void:
	var sp: Dictionary = Config.SPECIAL
	t.ok(LevelData.validate(d).is_empty(), "%s hợp lệ" % tag)
	var rect: Array = d.get("rect", [])
	t.eq(rect.size(), 4, "%s có rect" % tag)
	if rect.size() != 4:
		return
	var rw := int(rect[2])
	var rh := int(rect[3])
	t.ok(rw >= int(sp.rect_w_min) and rw <= int(sp.rect_w_max), "%s rộng %d" % [tag, rw])
	t.ok(rh >= int(sp.rect_h_min) and rh <= int(sp.rect_h_max), "%s cao %d" % [tag, rh])
	var seen := {}
	for b in d.blocks:
		t.ok(LevelData.COLORS.has(str(b.color)), "%s màu %s" % [tag, b.color])
		t.ok((b.cells as Array).size() <= Config.BLOCK_MAX_CELLS, "%s khối tối đa %d ô" % [tag, Config.BLOCK_MAX_CELLS])
		t.ok(int(b.ice) == 0 and str(b.chained_by) == "" and str(b.inner_color) == "" and not bool(b.fog),
			"%s không cơ chế" % tag)
		for raw in b.cells:
			var c := LevelData.cell_of(raw)
			t.ok(c.x >= int(rect[0]) and c.x < int(rect[0]) + rw and c.y >= int(rect[1]) and c.y < int(rect[1]) + rh,
				"%s ô trong rect" % tag)
			seen[c] = true
	t.eq(seen.size(), rw * rh, "%s lát kín" % tag)
	var n: int = (d.blocks as Array).size()
	t.eq(int(d.min_taps), n, "%s min_taps = số khối" % tag)
	var slack := int(d.moves) - n
	t.ok(slack >= int(sp.slack) and slack <= int(sp.slack) + 2, "%s dư %d" % [tag, slack])
	t.ok(bool(Solver.solve(d).get("ok", false)), "%s giải được" % tag)
	t.ok(Solver.immediate_exit_exists(d), "%s có khối thoát ngay" % tag)


func test_generate(t: T) -> void:
	for i in [1, 2, 3, 57]:
		var d := SpecialBoard.generate(i, i * 1000)
		t.ok(not d.is_empty(), "sinh bàn %d" % i)
		if d.is_empty():
			continue
		_board_ok(t, d, "bàn %d" % i)
		var n: int = (d.blocks as Array).size()
		var want := roundi(n * float(Config.SPECIAL.rounds_share))
		t.ok(absi(int(d.rounds) - want) <= maxi(Config.LEVEL_ROUNDS_TOL_MIN, roundi(want * Config.LEVEL_ROUNDS_TOL)),
			"bàn %d lượt dọn bàn %d ~ %d" % [i, int(d.rounds), want])
	t.eq(SpecialBoard.generate(5, 77), SpecialBoard.generate(5, 77), "cùng seed cùng bàn")


func test_bomb_count(t: T) -> void:
	t.eq(SpecialBoard.bomb_count(0), 1, "0 thắng")
	t.eq(SpecialBoard.bomb_count(19), 1, "19 thắng")
	t.eq(SpecialBoard.bomb_count(20), 2, "20 thắng")
	t.eq(SpecialBoard.bomb_count(59), 3, "59 thắng")
	t.eq(SpecialBoard.bomb_count(100), 6, "100 thắng: trần")
	t.eq(SpecialBoard.bomb_count(500), 6, "500 thắng: trần")


## Gỡ bom theo thứ tự kế hoạch, mỗi lần chạm một khối cần thiết: quả thứ k gỡ xong ở lần chạm |union 1..k| và còn
## đúng bomb_base_sec giây dư (nhịp 1 lần chạm mỗi giây).
func test_bomb_plan(t: T) -> void:
	var sp: Dictionary = Config.SPECIAL
	for i in [1, 2, 9]:
		var d := SpecialBoard.generate(i, i * 1000)
		var n: int = (d.blocks as Array).size()
		var taps := SpecialBoard.taps_to_free(d)
		for count in [1, 2, 3, 6]:
			var plan := SpecialBoard.bomb_plan(d, count, 42)
			t.eq(plan.size(), count, "bàn %d: %d bom" % [i, count])
			t.eq(plan, SpecialBoard.bomb_plan(d, count, 42), "cùng seed cùng bom")
			var ids := {}
			var last_sec := 0
			for b in plan:
				ids[b.id] = true
				t.eq(int(b.taps), int(taps[b.id]), "taps khớp")
				t.ok(int(b.taps) >= int(sp.bomb_min_taps) and int(b.taps) <= maxi(int(sp.bomb_min_taps),
					floori(n * float(sp.bomb_max_share))), "taps trong khoảng")
				t.ok(int(b.seconds) >= int(sp.bomb_base_sec) + int(b.taps), "đủ giây cho riêng quả này")
				t.ok(int(b.seconds) >= last_sec, "giây tăng dần")
				last_sec = int(b.seconds)
				var on_block := false
				for blk in d.blocks:
					if str(blk.id) == str(b.id):
						for raw in blk.cells:
							on_block = on_block or LevelData.cell_of(raw) == b.cell
				t.ok(on_block, "ô bom thuộc khối")
			t.eq(ids.size(), plan.size(), "bom khác khối")
			_check_feasible(t, d, plan, "bàn %d %d bom" % [i, count])
	var one := SpecialBoard.bomb_plan(SpecialBoard.generate(1, 1000), 1, 3)
	t.eq(int(one[0].seconds), int(sp.bomb_base_sec) + int(one[0].taps), "1 bom: 19 + số lần chạm")


func _check_feasible(t: T, d: Dictionary, plan: Array, tag: String) -> void:
	var board := BoardState.new(d)
	board.add_moves(10000)
	var used := 0
	for b in plan:
		var guard := 0
		while board.block_view(b.id).size() > 0 and guard < 500:
			guard += 1
			var pick := SpecialBoard.urgent_hint(board, [b.id])
			if pick == "":
				t.fail("%s: kẹt khi gỡ %s" % [tag, b.id])
				return
			board.tap(pick)
			used += 1
		t.ok(used + int(Config.SPECIAL.bomb_base_sec) <= int(b.seconds), "%s: %s kịp (%d lần chạm, %d giây)" % [
			tag, b.id, used, int(b.seconds)])


func test_urgent_hint(t: T) -> void:
	var d := SpecialBoard.generate(3, 3000)
	var plan := SpecialBoard.bomb_plan(d, 2, 1)
	var board := BoardState.new(d)
	var ids: Array = plan.map(func(b: Dictionary) -> String: return str(b.id))
	var h := SpecialBoard.urgent_hint(board, ids)
	t.ok(h != "" and board.can_exit(h), "gợi ý thoát được")
	t.eq(SpecialBoard.urgent_hint(board, []), "", "không bom: rỗng")


func _fresh() -> Dictionary:
	return SaveSchema.defaults()


func test_tickets(t: T) -> void:
	var s := _fresh()
	var t0 := 1_800_000_000
	var wait := int(Config.SPECIAL.timer_sec)
	t.eq(SpecialBomb.tickets(s, t0), 1, "mở ra có sẵn 1 vé chờ")
	t.eq(SpecialBomb.consume(s, t0), "timer", "dùng vé chờ")
	t.eq(SpecialBomb.tickets(s, t0), 0, "hết vé")
	t.eq(SpecialBomb.consume(s, t0), "", "hết vé thì không dùng được")
	t.eq(SpecialBomb.wait_left(s, t0 + 60), wait - 60, "đếm ngược")
	t.eq(SpecialBomb.tickets(s, t0 + wait * 5), 1, "chờ lâu vẫn chỉ 1 vé chờ")
	t.eq(SpecialBomb.add_bonus(s, SpecialBomb.tickets_for("hard")), 1, "Hard +1")
	t.eq(SpecialBomb.add_bonus(s, SpecialBomb.tickets_for("very_hard")), 1, "VeryHard +1")
	t.eq(SpecialBomb.tickets_for(""), 0, "level thường 0")
	t.eq(SpecialBomb.bonus(s), 2, "ngăn thưởng 2")
	t.eq(SpecialBomb.consume(s, t0 + wait), "timer", "ngăn chờ trước")
	t.eq(SpecialBomb.bonus(s), 2, "ngăn thưởng giữ nguyên")
	t.eq(SpecialBomb.consume(s, t0 + wait + 1), "bonus", "rồi ngăn thưởng")
	t.eq(SpecialBomb.wait_left(s, t0 + wait + 1), wait - 1, "vé thưởng không đổi đồng hồ")
	# Giờ máy lùi một ngày: thời gian chờ không quá timer_sec.
	SpecialBomb.normalize(s, t0 - 86400)
	t.eq(SpecialBomb.wait_left(s, t0 - 86400), wait, "giờ lùi: chờ tối đa timer_sec")


func test_bonus_cap(t: T) -> void:
	var s := _fresh()
	t.eq(SpecialBomb.add_bonus(s, 50), 50, "mặc định không giới hạn")
	Config.SPECIAL["bonus_cap"] = 3
	var s2 := _fresh()
	t.eq(SpecialBomb.add_bonus(s2, 5), 3, "trần 3")
	t.eq(SpecialBomb.add_bonus(s2, 1), 0, "đã đầy")
	Config.reset()


func test_progress(t: T) -> void:
	var s := _fresh()
	t.eq(SpecialBomb.board(s), 1, "bàn 1")
	t.eq(SpecialBomb.bomb_count(s), 1, "1 bom")
	var seed0 := SpecialBomb.bomb_seed(s)
	t.eq(SpecialBomb.bomb_seed(s), seed0, "thua chơi lại: cùng seed")
	for i in 20:
		SpecialBomb.win(s)
	t.eq(SpecialBomb.wins(s), 20, "20 thắng")
	t.eq(SpecialBomb.board(s), 21, "bàn 21")
	t.eq(SpecialBomb.bomb_count(s), 2, "2 bom")
	var boards := int(Config.SPECIAL.boards)
	t.eq(SpecialBomb.board_file(boards), boards, "bàn cuối")
	t.eq(SpecialBomb.board_file(boards + 1), 1, "hết thì quay lại bàn 1")
	for k in 30:
		t.ok(Config.SPECIAL.reward_kinds.has(SpecialBomb.pick_reward(k)), "thưởng trong danh sách")


func test_shipped_boards(t: T) -> void:
	var n := int(Config.SPECIAL.boards)
	for i in range(1, n + 1):
		var path := SpecialBoard.path_of(i)
		if not FileAccess.file_exists(path):
			t.fail("thiếu %s" % path)
			continue
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		t.ok(d is Dictionary, "%s đọc được" % path)
		if d is Dictionary:
			_board_ok(t, d, "sp %d" % i)
			t.eq(SpecialBoard.bomb_plan(d, int(Config.SPECIAL.bombs_max), 1).size(), int(Config.SPECIAL.bombs_max),
				"sp %d đủ chỗ cho %d bom" % [i, int(Config.SPECIAL.bombs_max)])
