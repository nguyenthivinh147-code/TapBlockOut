extends SceneTree
## Smoke: mở scenes/main.tscn như game thật và bấm bằng input thật (push_input vào toạ độ, có hit-test), theo kịch
## bản trong scenarios.gd (docs/TESTING.md "Tầng 2"). Gọi qua tools/smoke.sh. Tham số sau "--":
##   scen=<A..S> out=<thư mục tuyệt đối> speed=<time_scale> seed=<n> taps=<n> window=<0|1> max=<giây>
## Dòng log: SMOKE STEP, SMOKE SHOT, SMOKE CENSUS, SMOKE WARN, SMOKE FRAMES, SMOKE HITCH, SMOKE MEM, SMOKE INVARIANT,
## SMOKE REAL INPUT, SMOKE ERRORS script=<n> engine=<n>, cuối cùng SMOKE OK hoặc SMOKE FAILED <lý do>.

const Scenarios := preload("res://tests/smoke/scenarios.gd")
const Saves := preload("res://tests/smoke/smoke_saves.gd")
const Solver := preload("res://src/core/solver.gd")
const MockIap := preload("res://src/platform/mock_iap.gd")
const UiTween := preload("res://src/ui/ui_tween.gd")
const Config := preload("res://src/config.gd")

## Giờ giả lập cố định để lịch quà, mạng, offer ra cùng kết quả mỗi lần chạy.
const NOW := 1800000000
const ALLOW_PATH := "res://tests/allow_errors.txt"
const HITCH_MS := 33.0
const INVARIANT_EVERY := 30
const INVARIANT_STRIKES := 3
const RAW_KEY := "^[a-z][a-z0-9]*(_[a-z0-9]+)+$"


## Đếm lỗi script và lỗi engine (không đếm warning), giữ nội dung để in và so allowlist.
class SmokeLog:
	extends Logger
	var items: Array[Dictionary] = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		var what := rationale if not rationale.is_empty() else code
		mutex.lock()
		items.append({"script": error_type == ERROR_TYPE_SCRIPT,
			"text": "%s (%s:%d %s)" % [what, file.get_file(), line, function]})
		mutex.unlock()

	func take() -> Array[Dictionary]:
		mutex.lock()
		var out := items.duplicate()
		items.clear()
		mutex.unlock()
		return out


## Ghi lại input không do smoke đẩy vào (người đụng chuột, phím khi chạy có cửa sổ).
class Guard:
	extends Node
	var injecting := false
	var seen := ""

	func _input(event: InputEvent) -> void:
		if injecting or not seen.is_empty():
			return
		if event is InputEventMouse or event is InputEventKey or event is InputEventScreenTouch:
			seen = event.as_text()


var args := {}
var out_dir := ""
var window := false
var main: Control = null
var game: Node = null
var plat: Node = null
var shots := 0
var failed_reason := ""

var _log := SmokeLog.new()
var _guard := Guard.new()
var _allow: Array[String] = []
var _script_errors := 0
var _engine_errors := 0
var _phase := ""
var _phase_times: PackedFloat32Array = []
var _last_usec := 0
var _frame_no := 0
var _strikes := {}
var _reported := {}
var _invariants_on := false
var _ended := false


func _initialize() -> void:
	OS.add_logger(_log)
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	out_dir = str(args.get("out", ProjectSettings.globalize_path("user://smoke_out")))
	window = str(args.get("window", "0")) == "1"
	_load_allow()
	_run.call_deferred()


func _run() -> void:
	await process_frame
	game = root.get_node("Game")
	plat = root.get_node("Platform")
	root.add_child(_guard)
	if window:
		root.mouse_passthrough = true
	process_frame.connect(_on_frame)
	var limit := float(args.get("max", "870"))
	create_timer(limit, true, false, true).timeout.connect(func() -> void:
		fail("quá %d giây" % int(limit))
		_end())
	var scen := str(args.get("scen", "B"))
	print("SMOKE START scen=%s window=%s speed=%s seed=%s" % [scen, window, args.get("speed", "1"), args.get("seed", "1")])
	var ok: bool = await Scenarios.run(self, scen)
	if not ok and failed_reason.is_empty():
		fail("kịch bản %s dừng giữa chừng" % scen)
	_end()


# ---------------------------------------------------------------- vòng đời

## Dựng môi trường: save riêng user://smoke_<tên>/, giờ cố định, ads và mua hàng giả, mở main, đợi boot.
## `prepare` (nếu có) nhận Game trước khi main boot, dùng để dựng save (smoke_saves.gd).
func open_game(name: String, prepare: Callable = Callable(), shot_splash: bool = false) -> bool:
	close_game()
	var dir := "user://smoke_%s" % name
	DirAccess.make_dir_recursive_absolute(dir)
	game.reset_for_test(dir + "/save.json")
	_release_env(NOW)
	if prepare.is_valid():
		prepare.call(game)
	game.save_now()
	return await _boot_main(name, shot_splash)


## Mở lại save user://smoke_<tên>/save.json đã có như lần mở app sau: không reset_for_test, không dựng save, giờ
## giả muộn hơn một phút. Kịch bản G2 dùng, trong tiến trình Godot riêng (autoload Game chưa boot).
func reopen_game(name: String) -> bool:
	close_game()
	var path := "user://smoke_%s/save.json" % name
	if not FileAccess.file_exists(path):
		return fail("không có save %s" % path)
	game.save_path = path
	game.test_online = 1
	_release_env(NOW + 60)
	return await _boot_main(name, false)


## Như bản phát hành: không demo, không UI gallery, không công cụ sửa tài khoản (smoke chạy bằng Godot editor nên
## OS.is_debug_build() luôn true); giờ cố định, ads và mua hàng giả.
func _release_env(now: int) -> void:
	Config.demo_override = 0
	Config.ui_preview_override = 0
	Config.account_tool_override = 0
	game.test_now = now
	game.test_tz = 0
	plat.ads.calls.clear()
	plat.ads.set_ready(true, true)
	plat.iap = MockIap.new()


func _boot_main(name: String, shot_splash: bool) -> bool:
	Engine.time_scale = float(args.get("speed", "1"))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Control
	root.add_child(main)
	if shot_splash:
		await wait_frames(4)
		await shot("splash")
	if not await wait_until(func() -> bool: return bool(main.is_booted), 30000):
		return fail("main không boot xong")
	_invariants_on = true
	step("mở game với save %s, level %d" % [name, int(game.s.level)])
	return true


func close_game() -> void:
	_invariants_on = false
	if main != null and is_instance_valid(main):
		main.free()
	main = null


func fail(reason: String) -> bool:
	if failed_reason.is_empty():
		failed_reason = reason
	print("SMOKE WARN %s" % reason)
	print("SMOKE STATE %s" % describe())
	return false


## Trạng thái hiện tại để đọc log khi kịch bản dừng: màn, popup, level, curtain.
func describe() -> String:
	if main == null or not is_instance_valid(main):
		return "chưa mở game"
	var pops: PackedStringArray = []
	for c in main.popup_layer.get_children():
		var s := c.get_script() as Script
		pops.append("%s%s" % [s.resource_path.get_file() if s != null else str(c.name),
			" (đang đóng)" if UiTween.closing(c) else ""])
	var lv := level_screen()
	var lv_text := ""
	if lv != null:
		lv_text = " level=%d state=%s moves=%d" % [int(lv.attempt.level), str(lv.state), lv.board.moves_left()]
	return "màn=%s popup=[%s]%s curtain=%s" % [screen_name(), ", ".join(pops), lv_text, str(main.curtain != null)]


func _end() -> void:
	if _ended:
		return
	_ended = true
	if _phase != "":
		end_phase()
	_invariants_on = false
	_count_errors()
	print("SMOKE ERRORS script=%d engine=%d" % [_script_errors, _engine_errors])
	if not _guard.seen.is_empty():
		print("SMOKE REAL INPUT %s" % _guard.seen)
	var ok := failed_reason.is_empty() and _script_errors == 0 and _engine_errors == 0
	if ok:
		print("SMOKE OK")
	else:
		var why := failed_reason
		if why.is_empty():
			why = "có lỗi script hoặc engine"
		print("SMOKE FAILED %s" % why)
	Engine.time_scale = 1.0
	Config.demo_override = -1
	Config.ui_preview_override = -1
	Config.account_tool_override = -1
	close_game()
	OS.remove_logger(_log)
	quit(0 if ok else 1)


func _load_allow() -> void:
	if not FileAccess.file_exists(ALLOW_PATH):
		return
	for raw in FileAccess.get_file_as_string(ALLOW_PATH).split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#") or not line.contains(" ## "):
			continue
		_allow.append(line.split(" ## ", false, 1)[0].strip_edges())


func _count_errors() -> void:
	for e in _log.take():
		var text := str(e["text"])
		var allowed := false
		for a in _allow:
			if text.contains(a):
				allowed = true
		if allowed:
			print("SMOKE ALLOWED %s" % text)
			continue
		if bool(e["script"]):
			_script_errors += 1
		else:
			_engine_errors += 1
		print("SMOKE ERROR %s" % text)


# ---------------------------------------------------------------- tiện ích

func step(text: String) -> void:
	_count_errors()
	print("SMOKE STEP %s" % text)


func wait_until(cond: Callable, ms: int = 10000) -> bool:
	var deadline := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func wait_frames(n: int) -> void:
	for i in n:
		await process_frame


## Đợi theo thời gian game (đã nhân time_scale).
func wait_sec(sec: float) -> void:
	await create_timer(sec, true, false, false).timeout


func popups() -> Array[Node]:
	var out: Array[Node] = []
	if main == null or main.popup_layer == null:
		return out
	for c in main.popup_layer.get_children():
		if not UiTween.closing(c):
			out.append(c)
	return out


## Popup còn sống chứa node tên `node_name` (trả node đó), null nếu không có.
func popup_node(node_name: String) -> Node:
	for c in popups():
		var n: Node = c.find_child(node_name, true, false)
		if n != null:
			return n
	return null


## Popup còn sống có script tên `file` (vd "popup_rescue.gd").
func popup_script(file: String) -> Node:
	for c in popups():
		var s := c.get_script() as Script
		if s != null and s.resource_path.get_file() == file:
			return c
	return null


func level_screen() -> Control:
	if main == null or main.current_name != "level" or not is_instance_valid(main.current_screen):
		return null
	return main.current_screen as Control


func screen_name() -> String:
	return str(main.current_name) if main != null else ""


# ---------------------------------------------------------------- input thật

## Khung màn trong toạ độ canvas (886x1920 ở màn chuẩn, rộng hoặc cao hơn theo tỉ lệ cửa sổ). root.get_visible_rect()
## trả cỡ cửa sổ khi stretch canvas_items, không dùng được để so với toạ độ UI.
func view_rect() -> Rect2:
	if main != null and is_instance_valid(main):
		var xf := main.get_global_transform_with_canvas()
		return Rect2(xf * Vector2.ZERO, xf.basis_xform(main.size))
	return root.get_visible_rect()


## Toạ độ viewport của điểm `local` trong Control `c` (gồm transform của CanvasLayer).
func to_viewport(c: CanvasItem, local: Vector2) -> Vector2:
	return c.get_global_transform_with_canvas() * local


func _push(ev: InputEvent) -> void:
	_guard.injecting = true
	root.push_input(ev, true)
	_guard.injecting = false


## Control nhận chuột tại điểm `p` (toạ độ viewport).
func hovered_at(p: Vector2) -> Control:
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	_push(mv)
	await process_frame
	return root.gui_get_hovered_control()


## Nhấn rồi thả ở `p` (toạ độ viewport). Có `target`: trả "" khi cú nhấn rơi vào `target` hoặc con của nó, không thì
## tên node nhận cú nhấn (hover ngay sau khi nhấn, trước khi nút kịp đóng popup).
func click_at(p: Vector2, target: Control = null) -> String:
	var missed := ""
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = p
		ev.global_position = p
		_push(ev)
		if pressed and target != null and is_instance_valid(target):
			var got := root.gui_get_hovered_control()
			if got != null and got != target and not target.is_ancestor_of(got):
				missed = node_label(got)
		await process_frame
	return missed


## Kéo bằng chuột (cuộn danh sách): nhấn ở `from`, di qua `steps` bước, thả ở `to` (toạ độ viewport).
func drag(from: Vector2, to: Vector2, steps: int = 10) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	down.global_position = from
	_push(down)
	var last := from
	for i in range(1, steps + 1):
		var p := from.lerp(to, float(i) / steps)
		var mv := InputEventMouseMotion.new()
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.position = p
		mv.global_position = p
		mv.relative = p - last
		mv.velocity = (p - last) * 60.0
		last = p
		_push(mv)
		await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	up.global_position = to
	_push(up)
	await wait_frames(6)


## Nút Back của Android (NOTIFICATION_WM_GO_BACK_REQUEST): main đóng popup trên cùng hoặc gọi on_back của màn.
func back() -> void:
	step("bấm Back")
	_guard.injecting = true
	root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_guard.injecting = false
	await wait_frames(3)


## Control hit-test trúng `c` (hoặc con của nó) ở tâm: nút đang thấy và bấm được.
func reachable(c: Control) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return false
	var h := await hovered_at(to_viewport(c, c.size * 0.5))
	return is_instance_valid(c) and h != null and (h == c or c.is_ancestor_of(h))


static func node_label(n: Variant) -> String:
	if n == null or not is_instance_valid(n) or not (n is Node):
		return "(không có gì)"
	var s := n.get_script() as Script
	var tag := (" [%s]" % s.resource_path.get_file()) if s != null else ""
	return "%s%s" % [n.name, tag]


## Đợi tâm của `c` đứng yên trên màn (lệch dưới 1 px qua 2 khung liền), tối đa tới `deadline`. Popup đang phóng to
## hay màn đang trượt thì nút còn chạy: hit-test ở khung này rồi nhấn ở khung sau sẽ trượt sang nền. Nút chỉ nhún tại
## chỗ (tâm không đổi) không phải đợi.
func _wait_still(c: Control, deadline: int) -> void:
	var last := Vector2.INF
	var still := 0
	while still < 2 and Time.get_ticks_msec() < deadline:
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		var p := to_viewport(c, c.size * 0.5)
		still = still + 1 if p.distance_to(last) < 1.0 else 0
		last = p
		await process_frame


## Bấm Control `c` như ngón tay: đợi tối đa `wait_ms` cho nút đứng yên và tâm nút hit-test trúng `c` (hiệu ứng mở
## popup, màn chuyển cảnh còn che), rồi thử tâm và lưới 3x3, bấm điểm đầu tiên trúng `c` (hoặc con của nó). Không điểm
## nào trúng: vẫn bấm tâm (như người chơi), log "(NOT the target)" và trả false.
func tap(c: Control, label: String = "", wait_ms: int = 2000) -> bool:
	if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
		return fail("bấm %s: không có hoặc đang ẩn" % label)
	var name := label if not label.is_empty() else str(c.name)
	var deadline := Time.get_ticks_msec() + wait_ms
	await _wait_still(c, deadline)
	while Time.get_ticks_msec() < deadline and not await reachable(c):
		await wait_frames(2)
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			return fail("bấm %s: nút biến mất trong lúc đợi" % name)
	var points: Array[Vector2] = [c.size * 0.5]
	for fy in [0.3, 0.5, 0.7]:
		for fx in [0.3, 0.5, 0.7]:
			points.append(c.size * Vector2(fx, fy))
	var first_hit: Control = null
	for i in points.size():
		if not is_instance_valid(c) or not c.is_inside_tree():
			return fail("bấm %s: nút biến mất trong lúc bấm" % name)
		var p := to_viewport(c, points[i])
		var h := await hovered_at(p)
		if not is_instance_valid(c):
			return fail("bấm %s: nút biến mất trong lúc bấm" % name)
		if i == 0:
			first_hit = h
		if h != null and (h == c or c.is_ancestor_of(h)):
			if i > 0:
				print("SMOKE WARN tâm của %s bị %s che, bấm điểm khác" % [name, node_label(first_hit)])
			step("bấm %s" % name)
			var missed := await click_at(p, c)
			if not missed.is_empty():
				print("SMOKE WARN bấm %s trượt: lúc nhấn trúng %s" % [name, missed])
				return false
			return true
	step("bấm %s (NOT the target: trúng %s)" % [name, node_label(first_hit)])
	if is_instance_valid(c) and c.is_inside_tree():
		await click_at(to_viewport(c, points[0]))
	return false


## Bấm khối `id` trên bàn: tâm một ô của khối mà board_view.block_at trả đúng khối đó.
func tap_block(id: String) -> bool:
	var lv := level_screen()
	if lv == null:
		return fail("bấm khối %s: không ở màn level" % id)
	var bv: Control = lv.board_view
	var node: Control = bv.block_node(id)
	if node == null:
		return fail("bấm khối %s: không có node" % id)
	for c in node.get("cells"):
		var local: Vector2 = bv.cell_center(c)
		if str(bv.block_at(local)) != id:
			continue
		var p := to_viewport(bv, local)
		var h := await hovered_at(p)
		var deadline := Time.get_ticks_msec() + 2000
		while Time.get_ticks_msec() < deadline and h != bv and not (h != null and bv.is_ancestor_of(h)):
			await wait_frames(2)
			if not is_instance_valid(bv):
				return fail("bấm khối %s: bàn biến mất" % id)
			h = await hovered_at(p)
		if h != bv and not (h != null and bv.is_ancestor_of(h)):
			step("chạm khối %s (NOT the target: trúng %s)" % [id, node_label(h)])
			await click_at(p)
			return false
		await click_at(p)
		return true
	return fail("bấm khối %s: không ô nào của khối nhận chạm" % id)


## Chạm một nước theo solver. false khi không còn nước hoặc không ở trạng thái chơi.
func tap_next_move() -> bool:
	var lv := level_screen()
	if lv == null or str(lv.state) != "playing":
		return false
	var r: Dictionary = Solver.solve_state(lv.board)
	if not bool(r.ok) or (r.order as Array).is_empty():
		return false
	return await tap_block(str(r.order[0]))


# ---------------------------------------------------------------- ảnh và census

## Đợi màn yên để ảnh không dính chuyển cảnh: không popup nào đang đóng, không curtain, không màn cũ đang mờ hay trượt
## ra (main._slide_out), rồi thêm một nhịp cho hiệu ứng mở popup.
func quiet(ms: int = 4000) -> void:
	await wait_until(func() -> bool:
		if main == null or not is_instance_valid(main):
			return true
		for c in main.popup_layer.get_children():
			if UiTween.closing(c):
				return false
		var lv := level_screen()
		if lv != null and lv.find_child("LoadTransition", false, false) != null:
			return false
		return main.curtain == null and not is_instance_valid(main.get("_slide_out")), ms)
	await wait_sec(0.4)


## Chụp màn (chỉ khi có cửa sổ) và ghi census chữ đang hiện (mọi chế độ), sau khi màn yên.
func shot(name: String) -> void:
	await quiet()
	shots += 1
	var base := "%02d_%s" % [shots, name]
	if window:
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png(out_dir.path_join(base + ".png"))
			print("SMOKE SHOT %s.png" % base)
	census(base)


## Ảnh liền nhau mỗi `every` giây thật trong `sec` giây, không đợi màn yên, để soát animation chuyển cảnh (kịch bản
## T). Chỉ chụp khi có cửa sổ; headless chỉ đợi chừng đó thời gian.
func film(name: String, sec: float, every: float = 0.15) -> void:
	var n := int(ceil(sec / every))
	if not window:
		step("quay %s: %d khung (headless không chụp)" % [name, n])
		await create_timer(sec, true, false, true).timeout
		return
	shots += 1
	var base := "%02d_%s" % [shots, name]
	for i in n:
		var t0 := Time.get_ticks_msec()
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		if img != null and not img.is_empty():
			img.save_png(out_dir.path_join("%s_%02d.png" % [base, i]))
			print("SMOKE SHOT %s_%02d.png" % [base, i])
		var left := every * 1000.0 - float(Time.get_ticks_msec() - t0)
		if left > 1.0:
			await create_timer(left / 1000.0, true, false, true).timeout


## Khung của `c` trên viewport (gồm transform của CanvasLayer và scale của node).
func _canvas_rect(c: Control) -> Rect2:
	var xf := c.get_global_transform_with_canvas()
	return Rect2(xf * Vector2.ZERO, xf.basis_xform(c.size)).abs()


## Giao các khung cắt của node cha (clip_contents, clip_children: ScrollContainer, Unity Mask), null khi không có.
func _clip_of(c: Control) -> Variant:
	var clip: Variant = null
	var n := c.get_parent()
	while n != null:
		var pc := n as Control
		if pc != null and (pc.clip_contents or pc.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED):
			var r := _canvas_rect(pc)
			clip = r if clip == null else (clip as Rect2).intersection(r)
		n = n.get_parent()
	return clip


func census(base: String) -> void:
	var rows: Array = []
	var warns: Array[String] = []
	var view := view_rect()
	var key_re := RegEx.create_from_string(RAW_KEY)
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if not (n is Label) or not (n as Label).is_visible_in_tree():
			continue
		var l := n as Label
		var shown := l.text
		if l.can_auto_translate():
			shown = l.tr(l.text)
		if shown.strip_edges().is_empty():
			continue
		var rect := _canvas_rect(l)
		# Trong danh sách cuộn (ScrollRect, Mask): phần nằm ngoài khung cắt không hiện, nhãn cuộn khuất hẳn thì bỏ qua.
		var clip: Variant = _clip_of(l)
		if clip != null:
			if not (clip as Rect2).intersects(rect):
				continue
			rect = rect.intersection(clip as Rect2)
		var fsize := l.get_theme_font_size("font_size")
		if l.label_settings != null:
			fsize = l.label_settings.font_size
		rows.append({"text": shown, "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"font_size": fsize, "color": l.get_theme_color("font_color").to_html(), "path": str(root.get_path_to(l))})
		var where := "%s \"%s\"" % [l.name, shown.substr(0, 40)]
		if key_re.search(shown.strip_edges()) != null:
			warns.append("%s: giống key tr() chưa dịch" % where)
		if rect.size.x > 1.0 and not view.grow(2.0).encloses(rect):
			warns.append("%s: ra ngoài màn" % where)
		if l.autowrap_mode == TextServer.AUTOWRAP_OFF and not l.clip_text \
				and l.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
			var font := l.label_settings.font if l.label_settings != null and l.label_settings.font != null \
				else l.get_theme_font("font")
			if font != null:
				var w := font.get_multiline_string_size(shown, l.horizontal_alignment, -1, fsize).x
				if w > l.size.x + 2.0:
					warns.append("%s: chữ rộng %d, nhãn rộng %d" % [where, int(w), int(l.size.x)])
	var f := FileAccess.open(out_dir.path_join("census_%s.json" % base), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"labels": rows, "warnings": warns}, "  "))
	print("SMOKE CENSUS %s: %d nhãn, %d cảnh báo" % [base, rows.size(), warns.size()])
	for i in mini(warns.size(), 20):
		print("SMOKE WARN census %s: %s" % [base, warns[i]])


# ---------------------------------------------------------------- khung hình, bộ nhớ, bất biến

func begin_phase(name: String) -> void:
	if _phase != "":
		end_phase()
	_phase = name
	_phase_times = []
	_last_usec = Time.get_ticks_usec()


func end_phase() -> void:
	var t := _phase_times.duplicate()
	t.sort()
	if t.size() > 0:
		var p50 := t[int(t.size() * 0.5)]
		var p95 := t[mini(t.size() - 1, int(t.size() * 0.95))]
		var hitches := 0
		for v in t:
			if v > HITCH_MS:
				hitches += 1
		print("SMOKE FRAMES %s n=%d p50=%.1fms p95=%.1fms max=%.1fms hitch=%d" % [_phase, t.size(), p50, p95, t[-1], hitches])
	_phase = ""


func mem(label: String) -> void:
	print("SMOKE MEM %s static=%.1fMB objects=%d nodes=%d orphans=%d" % [label,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])


func _on_frame() -> void:
	_frame_no += 1
	var now := Time.get_ticks_usec()
	if _phase != "":
		var ms := (now - _last_usec) / 1000.0
		_phase_times.append(ms)
		if ms > HITCH_MS * 3.0:
			print("SMOKE HITCH %s %.0fms" % [_phase, ms])
	_last_usec = now
	_guard_urls()
	if _invariants_on and _frame_no % INVARIANT_EVERY == 0:
		_check_invariants()


## Link ra ngoài (mail hỗ trợ, chính sách, điều khoản) của Settings đi qua settings.opener; smoke thay bằng hàm chỉ
## ghi log, để không bao giờ mở trình duyệt hay ứng dụng mail thật (monkey bấm được mọi nút của Settings).
func _guard_urls() -> void:
	if main == null or not is_instance_valid(main) or main.popup_layer == null:
		return
	for c in main.popup_layer.get_children():
		if "opener" in c and not (c.get("opener") as Callable).is_valid():
			c.set("opener", _blocked_url)


func _blocked_url(url: String) -> void:
	print("SMOKE STEP mở URL bị chặn: %s" % url)


## Kiểm luật luôn đúng của trạng thái game (docs/TESTING.md "Bất biến"); vi phạm INVARIANT_STRIKES lần liền mới báo.
func _check_invariants() -> void:
	for v in Scenarios.invariants(self):
		var name := str(v[0])
		var bad := bool(v[1])
		_strikes[name] = int(_strikes.get(name, 0)) + 1 if bad else 0
		if bad and int(_strikes[name]) >= INVARIANT_STRIKES and not _reported.has(name):
			_reported[name] = true
			print("SMOKE INVARIANT %s %s" % [name, str(v[2])])
			fail("vi phạm bất biến %s" % name)
