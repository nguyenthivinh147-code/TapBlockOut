extends SceneTree
## Chụp màn hình để kiểm bằng mắt (cửa sổ thật, không --headless).
## DISPLAY=:0 tools/godot.sh --path . --resolution 720x1280 -s res://tests/shot.gd -- --lang=en --tag=720 [--only=home,win]
## Ảnh ra tests/shots/<màn>_<tag>_<lang>.png. Không thuộc bộ test thường.

const MAIN := "res://scenes/main.tscn"
const OUT := "res://tests/shots/"
const NOW := 1800000000
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
	for name in ALL:
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
		"level":
			await _fresh(8)
			_main.go("level")
			await _settle()
		"level_booster":
			await _fresh(12, 500)
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
	_save(name)
	print("shot ", name, " ", tag, " ", lang)
