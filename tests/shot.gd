extends SceneTree
## Chụp màn hình để kiểm bằng mắt (cửa sổ thật, không --headless).
## DISPLAY=:0 tools/godot.sh --path . --resolution 720x1280 -s res://tests/shot.gd -- --lang=en --tag=720 [--only=home,win]
## Ảnh ra tests/shots/<màn>_<tag>_<lang>.png. Không thuộc bộ test thường.

const MAIN := "res://scenes/main.tscn"
const OUT := "res://tests/shots/"
const NOW := 1800000000
const Gallery := preload("res://src/ui/ui_gallery.gd")
const Leaderboard := preload("res://src/meta/leaderboard.gd")
const Config := preload("res://src/config.gd")
const ALL := ["home", "level", "popup_rescue", "popup_rescue_late", "win", "lose", "shop", "daily", "profile", "settings",
	"no_lives", "offer", "offer_level", "shop_mini", "level_booster"]

var lang := "en"
var tag := "720"
var only: Array = []
var _main: Control = null
var _n := 0
var _report: Array[String] = []


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var names: Array = ALL.duplicate()
	names.append_array(["lives_hub", "lives_full", "home_l1", "home_hard", "home_very_hard", "weekly_pass", "chain_offer", "challenge", "ingame_settings", "ingame_settings_life",
		"settings_language", "profile_frames",
		"leaderboard", "leaderboard_world", "leaderboard_world_rewards", "lb_result", "lb_leagues", "level_lb", "win_lb", "level_booster_all"])
	for s in Gallery.SCREENS:
		names.append(s[1])
	for name in names:
		if not only.is_empty() and not only.has(name):
			continue
		await _shot(name)
	for r in _report:
		print(r)
	quit(0)


func _g() -> Node:
	return root.get_node("Game")


func _fresh(level: int, gold: int = 12345) -> void:
	if _main != null:
		_main.queue_free()
		_main = null
		await process_frame
	_n += 1
	var g := _g()
	g.reset_for_test("user://shots_%d" % _n)
	g.test_now = NOW
	_main = (load(MAIN) as PackedScene).instantiate() as Control
	root.add_child(_main)
	if not _main.is_booted:
		await _main.booted
	# Boot nạp lại bản lưu, nên đặt trạng thái sau boot rồi dựng lại Home.
	g.test_now = NOW
	g.s.level = level
	g.s.coins = gold
	g.s.inv = {"hint": 2, "move": 1, "smash": 3}
	g.s.gifted = {"hint": true, "move": true, "smash": true}
	g.set_setting("lang", lang)
	_main.go("home")
	await _settle()


func _settle(sec: float = 0.8) -> void:
	for i in 6:
		await process_frame
	await create_timer(sec).timeout
	for i in 3:
		await process_frame


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%s_%s_%s.png" % [OUT, name, tag, lang])
	_scan_placeholders(name)


## Icon dựng bằng code (ImageTexture) thay vì file png nạp từ res:// là placeholder.
func _scan_placeholders(name: String) -> void:
	var found := {}
	_walk(_main, found)
	if not found.is_empty():
		_report.append("PLACEHOLDER %s_%s: %s" % [name, lang, ", ".join(found.keys())])


func _walk(n: Node, found: Dictionary) -> void:
	var tex: Texture2D = null
	if n is TextureRect:
		tex = (n as TextureRect).texture
	elif n is Button:
		tex = (n as Button).icon
	if tex is ImageTexture and (n as CanvasItem).is_visible_in_tree():
		found[str(n.get_path()).trim_prefix(str(_main.get_path()) + "/")] = true
	for c in n.get_children():
		_walk(c, found)


func _attempt_out_of_moves() -> Dictionary:
	var g := _g()
	var att: Dictionary = g.start_attempt()
	var b = att.board
	b.add_moves(-b.moves_left())
	return att


func _shot(name: String) -> void:
	var g := _g()
	match name:
		"home":
			await _fresh(8)
		"home_l1":
			await _fresh(1)
		"home_hard", "home_very_hard":
			# level đầu tiên có độ khó tương ứng (khung Hard / Super Hard trong Figma)
			var want := name.trim_prefix("home_")
			var lv := 2
			while lv < 400 and g.difficulty_of(lv) != want:
				lv += 1
			await _fresh(lv)
		"level":
			await _fresh(8)
			_main.go("level")
			await _settle()
		"level_booster":
			await _fresh(12, 500)
			_main.go("level")
			await _settle()
		"level_booster_all":
			# từ L17 hàng booster có đủ Gợi ý, +3 Move, Phá khối
			await _fresh(17, 500)
			_main.go("level")
			await _settle()
		"popup_rescue":
			await _fresh(8)
			_main.go("level")
			await _settle()
			var att := _attempt_out_of_moves()
			var o: Dictionary = g.rescue_offer(att).duplicate()
			_main.open_popup("res://scenes/popup_rescue.tscn", o)
			await _settle()
		"popup_rescue_late":
			await _fresh(8)
			_main.go("level")
			await _settle()
			var att := _attempt_out_of_moves()
			g.rescue_offer(att)
			att.rescue.accept("video")
			var o: Dictionary = g.rescue_offer(att).duplicate()
			_main.open_popup("res://scenes/popup_rescue.tscn", o)
			await _settle()
		"win":
			await _fresh(8)
			_main.go("level")
			await _settle()
			var att: Dictionary = g.start_attempt()
			var res: Dictionary = g.on_level_won(att)
			_main.open_popup("res://scenes/win_card.tscn", res)
			await _settle()
		"lose":
			await _fresh(8)
			_main.go("level")
			await _settle()
			_main.open_popup("res://scenes/lose_card.tscn", {"offer": "rescue_pack", "life_charged": true})
			await _settle()
		"shop":
			await _fresh(8)
			_main.go("shop", {"source": "home"})
			await _settle()
		"daily":
			await _fresh(8)
			_main.open_popup("res://scenes/popup_daily.tscn", {})
			await _settle()
		"profile":
			await _fresh(8)
			_main.go("profile")
			await _settle()
		"settings":
			await _fresh(8)
			_main.open_popup("res://scenes/settings.tscn", {})
			await _settle()
		"no_lives":
			await _fresh(10)
			g.s.lives = {"count": 0, "next_at": NOW + 900}
			_main.go("no_lives")
			await _settle()
		"lives_hub", "lives_full":
			await _fresh(10)
			if name == "lives_hub":
				g.s.lives = {"count": 3, "next_at": NOW + 900}
			_main.call("_home_action", "lives", {})
			await _settle()
		"offer":
			await _fresh(8)
			_main.open_popup("res://scenes/popup_offer.tscn", {"id": "starter_pack"})
			await _settle()
		"offer_level":
			await _fresh(10)
			_main.open_popup("res://scenes/popup_offer.tscn", {"id": "level_pack"})
			await _settle()
		"shop_mini":
			await _fresh(8, 100)
			_main.open_popup("res://scenes/shop_mini.tscn", {"source": "rescue"})
			await _settle()
		"weekly_pass":
			await _fresh(30)
			g.s.weekly.tut_seen = true
			g.s.weekly.points = 8
			_main.open_popup("res://scenes/weekly_pass.tscn", {})
			await _settle()
		"chain_offer":
			await _fresh(30)
			g.s.chain = {"active": true, "id": "chain_a", "step": 1, "expires": NOW + 86400, "cooldown_until": 0, "shown": true, "rotation": 1}
			_main.open_popup("res://scenes/chain_offer.tscn", {})
			await _settle()
		"challenge":
			await _fresh(60)
			Config.FEATURES.challenge = true
			_main.go("challenge")
			await _settle()
		"ingame_settings":
			await _fresh(10)
			_main.open_popup("res://scenes/popup_ingame_settings.tscn", {})
			await _settle()
		"ingame_settings_life":
			await _fresh(10)
			_main.open_popup("res://scenes/popup_ingame_settings.tscn", {"life_cost": true})
			await _settle()
		"settings_language":
			await _fresh(8)
			var st: Node = _main.open_popup("res://scenes/settings.tscn", {})
			st.call("open_language")
			await _settle()
		"profile_frames":
			await _fresh(8)
			g.s.cos.owned.append("frame_02")
			_main.go("profile")
			await _settle(0.2)
			_main.current_screen.call("select", "frame_01")
			await _settle()
		"leaderboard", "leaderboard_world", "leaderboard_world_rewards":
			await _fresh(30)
			g.lb_refresh()
			g.lb_claim()
			Leaderboard.add_points(g.s, 14)
			_main.go("leaderboard", {"tab": "league" if name == "leaderboard" else "world"})
			await _settle()
			if name == "leaderboard_world_rewards":
				# World ladder in its Rewards mode (the banner switch).
				_main.current_screen.call("_toggle_rewards")
				await _settle()
		"lb_result":
			await _fresh(30)
			g.lb_refresh()
			Leaderboard.add_points(g.s, 31)
			_main.go("leaderboard")
			await _settle()
		"lb_leagues":
			await _fresh(30)
			g.lb_refresh()
			g.lb_claim()
			Leaderboard.add_points(g.s, 90)
			g.lb_claim()
			_main.open_popup("res://scenes/popup_leagues.tscn", {"view": g.lb_leagues_view()})
			await _settle()
		"level_lb":
			await _fresh(9)
			_main.go("level")
			await _settle()
		"win_lb":
			await _fresh(9)
			_main.go("level")
			await _settle()
			var att: Dictionary = g.start_attempt()
			for id in att.board.block_ids():
				g.smash_block(att, id)
			var res: Dictionary = g.on_level_won(att)
			_main.open_popup("res://scenes/win_card.tscn", res)
			await _settle(1.5)
		_:
			await _fresh(10)
			_main.open_popup("res://scenes/%s.tscn" % name, {})
			await _settle()
	_save(name)
	print("shot ", name, " ", tag, " ", lang)
