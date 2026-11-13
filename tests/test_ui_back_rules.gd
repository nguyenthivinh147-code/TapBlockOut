extends RefCounted
## Back Android and ESC (design.md mục 2 "Back Android và ESC"; checklist [UI] of /game-testcase-generator):
## - a screen-locking tutorial ignores Back and ESC: the hand on L1 (tutorial_intro, mục 4), the Weekly Pass overlay
##   (mục 7);
## - Back closes every popup that a Home button opens;
## - the "Đang tải video" layer (Main.ad_loading) swallows taps, Back and ESC: the popup under it stays.
## ESC need not act as Back (Android only), so it is checked only where Back is locked.
## Back is the notification Android sends; ESC a key pushed into the root viewport (tests/ui_probe.gd).
const T := preload("res://tests/t.gd")
const Driver := preload("res://tests/e2e_driver.gd")
const Probe := preload("res://tests/ui_probe.gd")
const Scen := preload("res://tests/smoke/scenarios.gd")
const WeeklyPass := preload("res://src/meta/weekly_pass.gd")

const DIR := "user://test_ui_back_rules"

## Game not yet following design.md mục 2; see ui_probe.gd "verdicts". Case ids: "<case>:<key>"; the Back sweep lists
## Home buttons. Fixed 2026-11-13: tutorial_l1:Back, tutorial_weekly:Back (blocks_back), loading:Back
## (Main._back_allowed).
const KNOWN := {
	"cases": [],
	"back_home": [],
}


func _known(id: String) -> bool:
	return (KNOWN["cases"] as Array).has(id)


# --- tutorials ---

## L1 for the first time: the hand points at a block, only a tap on it goes on.
func _first_tutorial(t: T, key: String) -> void:
	var d := Driver.new()
	await d.begin(DIR, 1, -1, false, false)
	var main := d.main
	var g := d.game()
	await Probe.close_all(main)
	g.s.level = 1
	g.s.meta.intro_seen = false
	main.go("level")
	t.ok(await d.wait_until(func() -> bool: return Probe.popup_by_script(main, "tutorial_intro.gd") != null),
		"L1 lần đầu mở hướng dẫn")
	var tut: Node = Probe.popup_by_script(main, "tutorial_intro.gd")
	if tut == null:
		d.finish()
		return
	# Back counts once the old screen has faded out (Main._back_allowed), as for a player.
	await Probe.idle(main)
	await Probe.wait(0.6)
	t.ok(main.call("_back_allowed"), "màn đã đứng yên, Back được xử lý")
	await Probe.send(key)
	await Probe.wait(0.4)
	var lv := d.level_screen()
	var state := str(lv.get("state")) if lv != null else ""
	Probe.expect(t, Probe.is_open(tut) and main.current_name == "level" and state == "dialog",
		"%s lúc hướng dẫn L1: hướng dẫn vẫn mở, chưa vào chơi (màn %s, trạng thái %s)" % [key, main.current_name, state],
		_known("tutorial_l1:" + key))
	# The tap the tutorial waits for (the block under the hand) still goes on.
	d.dismiss_strays()
	d.finish()


func test_first_tutorial_ignores_back(t: T) -> void:
	await _first_tutorial(t, "Back")


func test_first_tutorial_ignores_esc(t: T) -> void:
	await _first_tutorial(t, "ESC")


## Weekly Pass opened the first time in an active season: the 3-step spotlight overlay.
func _weekly_tutorial(t: T, key: String) -> void:
	var d := Driver.new()
	await d.begin(DIR, 1, -1, true, false)
	var main := d.main
	var g := d.game()
	await Probe.home_all_unlocked(d)
	g.s.weekly["tut_seen"] = false
	if str(g.weekly_state()) != WeeklyPass.ACTIVE:
		t.fail("dựng save: Weekly Pass ở trạng thái %s, cần %s" % [str(g.weekly_state()), WeeklyPass.ACTIVE])
		d.finish()
		return
	var wp: Node = main.open_popup(main.WEEKLY_PASS)
	var running := func() -> bool: return Probe.is_open(wp) and is_instance_valid(wp.get("tutorial"))
	t.ok(await d.wait_until(running, 8000), "mở Weekly Pass lần đầu chạy tutorial")
	if not running.call():
		d.finish()
		return
	var tut: Node = wp.get("tutorial")
	await Probe.wait(0.5)
	await Probe.send(key)
	await Probe.wait(0.4)
	Probe.expect(t, Probe.is_open(wp) and is_instance_valid(tut) and wp.get("tutorial") == tut,
		"%s lúc tutorial Weekly Pass: layer vẫn mở, tutorial vẫn chạy" % key, _known("tutorial_weekly:" + key))
	t.ok(not g.weekly_tutorial_seen(), "%s lúc tutorial Weekly Pass: chưa lưu cờ đã xem" % key)
	d.finish()


func test_weekly_tutorial_ignores_back(t: T) -> void:
	await _weekly_tutorial(t, "Back")


func test_weekly_tutorial_ignores_esc(t: T) -> void:
	await _weekly_tutorial(t, "ESC")


# --- popups ---

## Every popup a Home button opens closes on Back.
func test_back_closes_home_popups(t: T) -> void:
	var d := Driver.new()
	await d.begin(DIR, 1, -1, true, false)
	await Probe.home_all_unlocked(d)
	var opened: Array[String] = []
	var stays := {}
	for name in Scen.HOME_BUTTONS:
		var p := await Probe.open_from_home(d, name)
		if p == null:
			await Probe.to_home(d)
			continue
		opened.append("%s → %s" % [name, Probe.label(p)])
		await Probe.back()
		await Probe.wait(0.4)
		if Probe.is_open(p):
			stays[name] = "%s vẫn mở" % Probe.label(p)
		await Probe.to_home(d)
	print("  popup mở từ Home: ", ", ".join(opened))
	t.ok(opened.size() >= 5, "mở được ít nhất 5 popup từ Home (mở được %d)" % opened.size())
	Probe.expect_none(t, "Back đóng popup mở từ Home", stays, KNOWN["back_home"])
	d.finish()


## Settings under the "Đang tải video" layer (Main._on_ad_wait, as Game.ad_wait shows it): a tap on Settings' X,
## Back and ESC all leave Settings open.
func test_loading_layer_blocks_taps_back_and_esc(t: T) -> void:
	var d := Driver.new()
	await d.begin(DIR, 1, -1, true, false)
	var main := d.main
	await Probe.home_all_unlocked(d)
	for key in ["tap", "Back", "ESC"]:
		var settings := await Probe.open_from_home(d, "SettingsButton")
		t.ok(settings != null, "%s: mở Settings từ Home" % key)
		if settings == null:
			break
		var x := Scen.find_close(settings)
		var x_at := Probe.center(x) if x != null else Vector2.INF
		main.call("_on_ad_wait", true)
		await Probe.wait(0.6)
		if key == "tap":
			t.ok(x_at != Vector2.INF, "Settings có nút đóng")
			if x_at != Vector2.INF:
				Probe.click(x_at)
				await Probe.frames(3)
		else:
			await Probe.send(key)
		await Probe.wait(0.4)
		Probe.expect(t, Probe.is_open(settings), "%s lúc đang tải video: Settings vẫn mở" % key,
			_known("loading:" + key))
		t.ok(main.get("ad_loading") != null, "%s lúc đang tải video: lớp tải vẫn hiện" % key)
		main.call("_on_ad_wait", false)
		await Probe.to_home(d)
	d.finish()
