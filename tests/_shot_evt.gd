extends SceneTree
## Private: extra states of the evt screens (deleted after the visual check).

const MAIN := "res://scenes/main.tscn"
const OUT := "res://tests/shots/"
const NOW := 1800000000
const Config := preload("res://src/config.gd")

var lang := "en"
var tag := "evt720"
var only: Array = []
var _main: Control = null
var _n := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			lang = a.substr(7)
		elif a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
	_run.call_deferred()


func _run() -> void:
	for name in ["daily_claimed", "daily_w4", "daily_locked", "daily_fail", "challenge_done", "streak_rewards_full",
			"streak_main_m4", "streak_main_0"]:
		if not only.is_empty() and not only.has(name):
			continue
		await _shot(name)
	quit(0)


func _g() -> Node:
	return root.get_node("Game")


func _fresh(level: int) -> void:
	if _main != null:
		_main.queue_free()
		_main = null
		await process_frame
	_n += 1
	var g := _g()
	g.reset_for_test("user://shots_evt_%d" % _n)
	g.test_now = NOW
	_main = (load(MAIN) as PackedScene).instantiate() as Control
	root.add_child(_main)
	if not _main.is_booted:
		await _main.booted
	g.test_now = NOW
	g.s.level = level
	g.s.coins = 12345
	g.set_setting("lang", lang)
	_main.go("home")
	await _settle()


func _settle(sec: float = 0.8) -> void:
	for i in 6:
		await process_frame
	await create_timer(sec).timeout
	for i in 3:
		await process_frame


func _shot(name: String) -> void:
	var g := _g()
	match name:
		"daily_claimed":
			await _fresh(8)
			var p: Node = _main.open_popup("res://scenes/popup_daily.tscn", {})
			await _settle()
			p.claim_button.pressed.emit()
			await _settle()
		"daily_w4":
			await _fresh(8)
			g.s.daily.idx = 27
			_main.open_popup("res://scenes/popup_daily.tscn", {})
			await _settle()
		"daily_locked":
			await _fresh(3)
			_main.open_popup("res://scenes/popup_daily.tscn", {})
			await _settle()
		"daily_fail":
			await _fresh(8)
			var p: Node = _main.open_popup("res://scenes/popup_daily.tscn", {})
			await _settle()
			p.claim_button.pressed.emit()
			root.get_node("Platform").ads.simulate({"ok": false, "reason": "closed"})
			await p._on_video()
			await _settle()
		"challenge_done":
			await _fresh(60)
			Config.FEATURES.challenge = true
			g.s.challenge = {"day": g.today(), "won": true}
			_main.go("challenge")
			await _settle()
		"streak_rewards_full":
			await _fresh(10)
			_main.open_popup("res://scenes/popup_streak_rewards.tscn", {})
			await _settle(2.6)
		"streak_main_m4":
			await _fresh(10)
			_main.open_popup("res://scenes/streak_main.tscn", {"view": {"ends_in": "1d 3h", "streak": 4, "milestones": [8, 6, 4, 2, 0]}})
			await _settle()
		"streak_main_0":
			await _fresh(10)
			_main.open_popup("res://scenes/streak_main.tscn", {"view": {"ends_in": "6d 23h", "streak": 0, "milestones": [6, 4, 2, 0]}})
			await _settle()
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%s_%s_%s.png" % [OUT, name, tag, lang])
	print("shot ", name, " ", tag, " ", lang)
