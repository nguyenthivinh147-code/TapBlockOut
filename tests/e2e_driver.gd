extends RefCounted
## Driver E2E: mở main.tscn, chơi bằng solver qua block_tapped, bấm nút theo tên trong lớp popup.
## Không phải test (tên không bắt đầu bằng test_): test_e2e_demo.gd dùng nó.

const Solver := preload("res://src/core/solver.gd")
const BoardState := preload("res://src/core/board_state.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const Config := preload("res://src/config.gd")

const NOW := 1800000000
## Tăng tốc tween và timer để E2E gọn; begin() đặt, finish() trả về 1.
const SPEED := 5.0

var main: Control = null
var offers_seen: int = 0
var gifts_seen: int = 0


func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func game() -> Node:
	return tree().root.get_node("Game")


func plat() -> Node:
	return tree().root.get_node("Platform")


## Dựng môi trường sạch (save trống ở `dir`), mở main, đợi boot, đặt level, về Home.
## demo = true mô phỏng bản demo (dừng ở L20, Config.demo_override = 1); false là bản phát hành (override 0).
## finish() trả công tắc về -1.
func begin(dir: String, level: int = 1, coins: int = -1, gifted: bool = false, demo: bool = true) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var g := game()
	g.reset_for_test(dir + "/save.json")
	Config.demo_override = 1 if demo else 0
	g.test_now = NOW
	g.test_tz = 0
	var p := plat()
	p.ads.calls.clear()
	p.ads.set_ready(true, true)
	p.iap = MockIap.new()
	p.save.last_json = ""
	Engine.time_scale = SPEED
	offers_seen = 0
	gifts_seen = 0
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	tree().root.add_child(main)
	await wait_until(func() -> bool: return main.is_booted)
	g.s.level = level
	if coins >= 0:
		g.s.coins = coins
	if gifted:
		for k in ["hint", "move", "smash"]:
			g.s.gifted[k] = true
	main.go("home")
	await tree().process_frame


func finish() -> void:
	Engine.time_scale = 1.0
	Config.demo_override = -1
	if main != null and is_instance_valid(main):
		main.free()
	main = null


func wait_until(cond: Callable, ms: int = 10000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await tree().process_frame
	return cond.call()


## Popup còn sống trong lớp popup của main chứa node `node_name`; null nếu không có.
func popup(node_name: String) -> Node:
	for c in main.popup_layer.get_children():
		if c.is_queued_for_deletion():
			continue
		var n: Node = c.find_child(node_name, true, false)
		if n != null:
			return n
	return null


## Popup còn sống có thuộc tính `prop` (nhận diện popup theo script).
func popup_with(prop: String) -> Node:
	for c in main.popup_layer.get_children():
		if not c.is_queued_for_deletion() and prop in c:
			return c
	return null


func press(node_name: String) -> bool:
	var b := popup(node_name) as Button
	if b == null:
		return false
	b.pressed.emit()
	return true


func wait_popup(node_name: String, ms: int = 15000) -> bool:
	return await wait_until(func() -> bool:
		dismiss_strays(node_name)
		return popup(node_name) != null, ms)


## Đóng popup không liên quan tới kịch bản: hộp tặng booster, offer. `keep` là nút đang đợi.
func dismiss_strays(keep: String = "") -> void:
	if main == null or main.popup_layer == null:
		return
	for c in main.popup_layer.get_children():
		if c.is_queued_for_deletion():
			continue
		if keep != "" and c.find_child(keep, true, false) != null:
			continue
		var gift := c.find_child("GotItButton", true, false) as Button
		if gift != null:
			gifts_seen += 1
			gift.pressed.emit()
		elif "later_button" in c:
			offers_seen += 1
			(c.later_button as Button).pressed.emit()


func level_screen() -> Control:
	if main.current_name != "level" or not is_instance_valid(main.current_screen):
		return null
	return main.current_screen as Control


## Đợi màn level ở trạng thái playing (và đúng `level` nếu > 0), tự đóng hộp tặng booster và offer.
func wait_playing(level: int = 0, ms: int = 20000) -> bool:
	return await wait_until(func() -> bool:
		dismiss_strays()
		var lv := level_screen()
		if lv == null or lv.state != "playing":
			return false
		return level == 0 or int(lv.attempt.level) == level, ms)


## Home -> bấm Chơi -> vào level.
func play_from_home(level: int = 0) -> bool:
	if main.current_name != "home":
		return false
	main.current_screen.play_btn.pressed.emit()
	return await wait_playing(level)


## Chạm một nước theo solver từ trạng thái hiện tại.
func tap_next() -> bool:
	var lv := level_screen()
	if lv == null or lv.state != "playing":
		return false
	var r: Dictionary = Solver.solve_state(lv.board)
	if not bool(r.ok) or (r.order as Array).is_empty():
		return false
	lv.board_view.block_tapped.emit(str(r.order[0]))
	return true


## Giải hết level đang chơi bằng solver.
func solve_level() -> bool:
	var lv := level_screen()
	if lv == null:
		return false
	for i in 300:
		if lv.board.is_won():
			return true
		if not tap_next():
			return lv.board.is_won()
		await tree().process_frame
	return lv.board.is_won()


## Giải level rồi đợi thẻ thắng.
func win_level() -> bool:
	if not await solve_level():
		return false
	return await wait_popup("ContinueButton")


## Bấm Tiếp tục ở thẻ thắng, đợi level kế (next > 0) vào trạng thái playing.
func continue_to(next: int) -> bool:
	if not press("ContinueButton"):
		return false
	if await wait_playing(next, 600 + int(Config.CONTENT.hard_banner_sec * 1000.0)):
		return true
	# Vừa mở tính năng ở Home thì level đưa người chơi về Home (Game.next_after_win).
	if not await wait_until(func() -> bool: return main.current_name == "home" and main.popup_count() == 0, 2000):
		return false
	return await play_from_home(next)


## Level trong [from, to] có khối bị chặn ngay từ đầu: [level, id]; [0, ""] nếu không.
func blocked_level(from: int, to: int) -> Array:
	for lvn in range(from, to + 1):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/level_%04d.json" % lvn))
		if not (data is Dictionary):
			continue
		var b := BoardState.new(data)
		for id in b.block_ids():
			if b.peek(id) == "blocked":
				return [lvn, id]
	return [0, ""]


## Chạm khối `id` (khối bị chặn) tới khi hết MOVES.
func burn_moves(id: String) -> void:
	var lv := level_screen()
	for i in 60:
		if lv.board.moves_left() <= 0:
			return
		lv.board_view.block_tapped.emit(id)
		await tree().process_frame


func popup_title() -> String:
	var l := popup("TitleLabel") as Label
	return l.text if l != null else ""
