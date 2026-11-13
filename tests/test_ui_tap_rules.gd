extends RefCounted
## Taps on the UI (design.md mục 2 "Chạm vào UI"; checklist [UI], [EDGE] of /game-testcase-generator), with real
## mouse and touch events through GUI hit-testing (tests/ui_probe.gd), on Home of a save with every feature open:
## - a popup's dim takes every tap around the panel; nothing behind it does;
## - a double tap on a Home button ends the same as a single tap (one popup, or the same screen);
## - a double tap on Play starts one level; taps and Back under the curtain reach nothing;
## - two fingers on two buttons at once: one action;
## - a held button shows it is pressed; dragging the finger off and lifting it does nothing.
const T := preload("res://tests/t.gd")
const Driver := preload("res://tests/e2e_driver.gd")
const Probe := preload("res://tests/ui_probe.gd")
const Scen := preload("res://tests/smoke/scenarios.gd")

const DIR := "user://test_ui_tap_rules"
## Home buttons that open a popup on a save with every feature open: the two-finger test needs two of them.
const POPUP_BUTTONS := ["SettingsButton", "GiftButton", "LeaderboardButton", "RemoveAdsButton", "WeeklyPassButton"]
## Gap between the two taps of a quick double tap by a finger, game seconds.
const DOUBLE_TAP_GAP := 0.12

## Game not yet following design.md mục 2 "Chạm vào UI"; see ui_probe.gd "verdicts". Fixed 2026-11-13: double_tap
## (the second tap closed the popup still opening: Main.add_popup guard), two_fingers (a second finger pressed a button
## too: Main._input), no_feedback (top bar buttons: hub_top.gd).
const KNOWN := {
	"double_tap": [],
	"two_fingers": false,
	"no_feedback": [],
}


func _home(d: Driver) -> void:
	await d.begin(DIR, 1, -1, true, false)
	await Probe.home_all_unlocked(d)


func test_dim_blocks_home_behind_popups(t: T) -> void:
	var d := Driver.new()
	await _home(d)
	var checked := 0
	var leaks := {}
	for name in Scen.HOME_BUTTONS:
		var p := await Probe.open_from_home(d, name)
		if p != null:
			checked += 1
			for q in Probe.edge_points():
				var h := await Probe.hovered_at(q)
				if h != null and not Probe.inside(h, p):
					leaks[name] = "%s: chạm tại (%d, %d) tới %s" % [Probe.label(p), q.x, q.y, Probe.label(h)]
					break
		await Probe.to_home(d)
	t.ok(checked >= 5, "mở được ít nhất 5 popup từ Home (mở được %d)" % checked)
	Probe.expect_none(t, "chạm vào dim quanh popup không tới UI phía sau", leaks, [])
	d.finish()


func test_double_tap_ends_like_single_tap(t: T) -> void:
	var d := Driver.new()
	await _home(d)
	var main := d.main
	var checked := 0
	var wrong := {}
	for name in Scen.HOME_BUTTONS:
		var single := {}
		var double := {}
		for taps in [1, 2]:
			var at := await Probe.home_aim(main, name)
			if at == Vector2.INF:
				break
			var before: int = main.popup_count()
			Probe.click(at)
			if taps == 2:
				await Probe.wait(DOUBLE_TAP_GAP)
				Probe.click(at)
			await Probe.await_reaction(d, before)
			if taps == 1:
				single = Probe.outcome(main, before)
			else:
				double = Probe.outcome(main, before)
			await Probe.to_home(d)
		if single.is_empty() or double.is_empty():
			continue
		checked += 1
		if single != double:
			wrong[name] = "một chạm %s, chạm đúp %s" % [str(single), str(double)]
	t.ok(checked >= 8, "bấm được ít nhất 8 nút ở Home (bấm được %d)" % checked)
	Probe.expect_none(t, "bấm đúp nhanh: kết quả như bấm một lần", wrong, KNOWN["double_tap"])
	d.finish()


func test_double_tap_play_starts_one_level(t: T) -> void:
	var d := Driver.new()
	await _home(d)
	var main := d.main
	var level := int(d.game().s.level)
	var play: Control = main.current_screen.get("play_btn")
	await Probe.settle(play)
	var at := await Probe.aim(play)
	t.ok(at != Vector2.INF, "chạm được nút Chơi")
	if at == Vector2.INF:
		d.finish()
		return
	Probe.click(at)
	await Probe.wait(DOUBLE_TAP_GAP)
	Probe.click(at)
	t.ok(await d.wait_playing(level), "chạm đúp Chơi: vào chơi L%d" % level)
	var levels := main.find_children("*", "", true, false).filter(func(n: Node) -> bool:
		var s := n.get_script() as Script
		return s != null and s.resource_path.get_file() == "level.gd")
	t.eq(levels.size(), 1, "chạm đúp Chơi: một màn chơi")
	t.eq(int(d.game().s.level), level, "chạm đúp Chơi: level không đổi")
	d.finish()


func test_taps_and_back_reach_nothing_under_curtain(t: T) -> void:
	var d := Driver.new()
	await _home(d)
	var main := d.main
	var spots: Array[Vector2] = []
	for name in ["SettingsButton", "GiftButton", "ShopButton", "ProfileButton", "LeaderboardButton"]:
		var at := await Probe.home_aim(main, name)
		if at != Vector2.INF:
			spots.append(at)
	t.ok(spots.size() >= 3, "lấy được chỗ của ít nhất 3 nút ở Home (%d)" % spots.size())
	var play: Control = main.current_screen.get("play_btn")
	await Probe.settle(play)
	Probe.click(await Probe.aim(play))
	t.ok(await d.wait_until(func() -> bool: return main.curtain != null, 3000), "bấm Chơi chạy màn chuyển cảnh")
	var rounds := 0
	while main.curtain != null and rounds < 60:
		for p in spots:
			Probe.click(p)
		await Probe.back()
		rounds += 1
	t.ok(rounds >= 3, "chạm và Back được %d lượt trong lúc chuyển cảnh" % rounds)
	t.ok(await d.wait_playing(int(d.game().s.level)), "hết màn chuyển cảnh thì vào chơi")
	t.eq(main.current_name, "level", "chạm và Back dưới màn chuyển cảnh không đổi màn")
	t.eq(main.popup_count(), 0, "chạm và Back dưới màn chuyển cảnh không mở popup")
	d.finish()


func test_two_fingers_one_action(t: T) -> void:
	var d := Driver.new()
	await _home(d)
	var main := d.main
	var pair: Array[Vector2] = []
	var names: Array[String] = []
	for name in POPUP_BUTTONS:
		var at := await Probe.home_aim(main, name)
		if at != Vector2.INF:
			pair.append(at)
			names.append(name)
		if pair.size() == 2:
			break
	t.eq(pair.size(), 2, "có hai nút mở popup ở Home")
	if pair.size() < 2:
		d.finish()
		return
	var before: int = main.popup_count()
	Probe.touch(0, pair[0], true)
	Probe.touch(1, pair[1], true)
	await Probe.frames(2)
	Probe.touch(1, pair[1], false)
	Probe.touch(0, pair[0], false)
	await Probe.await_reaction(d, before)
	var got := Probe.outcome(main, before)
	Probe.expect(t, got == {"screen": "home", "popups": 1},
		"hai ngón chạm %s và %s cùng lúc: một popup (nhận %s)" % [names[0], names[1], str(got)], KNOWN["two_fingers"])
	d.finish()


func test_press_feedback_and_drag_off(t: T) -> void:
	var d := Driver.new()
	await _home(d)
	var main := d.main
	var checked := 0
	var animated: Array[String] = []
	var no_feedback := {}
	var fired := {}
	var stuck := {}
	for name in Scen.HOME_BUTTONS:
		var at := await Probe.home_aim(main, name)
		if at == Vector2.INF:
			continue
		var b := Probe.home_button(main, name)
		var away := await Probe.empty_spot(at)
		if away == Vector2.INF:
			continue
		var idle_look := Probe.look(b)
		await Probe.wait(0.2)
		if Probe.look(b) != idle_look:
			# The button animates on its own (pulse, shine): its pressed look cannot be told apart.
			animated.append(name)
			continue
		checked += 1
		var before: int = main.popup_count()
		Probe.button(at, true)
		await Probe.wait(0.25)
		if Probe.look(b) == idle_look:
			no_feedback[name] = "giữ 0,25 giây không đổi hình"
		await Probe.drag_release(at, away)
		await Probe.wait(0.5)
		var after := Probe.outcome(main, before)
		if after != {"screen": "home", "popups": 0}:
			fired[name] = str(after)
			await Probe.to_home(d)
			continue
		if is_instance_valid(b) and Probe.look(b) != idle_look:
			stuck[name] = "thả ra ngoài rồi vẫn giữ hình lúc nhấn"
	if not animated.is_empty():
		print("  nút tự chạy animation, không chấm phản hồi nhấn: ", ", ".join(animated))
	t.ok(checked >= 8, "chấm được ít nhất 8 nút ở Home (chấm được %d)" % checked)
	Probe.expect_none(t, "nút đổi hình khi đang giữ", no_feedback, KNOWN["no_feedback"])
	Probe.expect_none(t, "giữ rồi kéo ra khỏi nút mới thả: không kích hoạt", fired, [])
	Probe.expect_none(t, "thả ra ngoài thì nút về như cũ", stuck, [])
	d.finish()
