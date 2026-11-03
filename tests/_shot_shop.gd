extends SceneTree
## Private visual check for the shop group (deleted after use). Windowed:
## tools/godot.sh --path . --resolution 720x1280 -s res://tests/_shot_shop.gd -- --lang=en --tag=x --only=shop_scroll

const MAIN := "res://scenes/main.tscn"
const OUT := "res://tests/shots/"
const NOW := 1800000000
const Config := preload("res://src/config.gd")

var lang := "en"
var tag := "x"
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
	for name in only:
		await _shot(str(name))
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
	g.reset_for_test("user://shotx_%d" % _n)
	g.test_now = NOW
	_main = (load(MAIN) as PackedScene).instantiate() as Control
	root.add_child(_main)
	if not _main.is_booted:
		await _main.booted
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
	img.save_png("%s_%s_%s_%s.png" % [OUT, name, tag, lang])
	print("shot ", name)


func _scroll(v: float) -> void:
	var sc: Node = _main.current_screen.find_child("ScrollRect", true, false)
	sc.call("set_vertical_normalized", v)


func _shot(name: String) -> void:
	var g := _g()
	match name:
		"shop_scroll":
			await _fresh(8)
			_main.go("shop", {"source": "home"})
			await _settle()
			for v in [0.66, 0.33, 0.0]:
				_scroll(v)
				await _settle(0.3)
				_save("shop_scroll_%d" % int(v * 100))
		"shop_weekday":
			g.test_now = NOW
			await _fresh(8)
			g.test_now = NOW + 2 * 86400
			_main.go("shop", {"source": "home"})
			await _settle()
			_scroll(0.0)
			await _settle(0.3)
			_save(name)
		"shop_preview":
			Config.ui_preview_override = 1
			await _fresh(8)
			_main.go("shop", {"source": "home"})
			await _settle()
			for v in [0.75, 0.5]:
				_scroll(v)
				await _settle(0.3)
				_save("shop_preview_%d" % int(v * 100))
			Config.ui_preview_override = -1
		"shop_drag":
			await _fresh(8)
			_main.go("shop", {"source": "home"})
			await _settle()
			var sc: Node = _main.current_screen.find_child("ScrollRect", true, false)
			var content: Control = sc.get("content")
			var y0 := content.position.y
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Vector2(360, 900)
			ev.global_position = ev.position
			root.push_input(ev)
			for i in 10:
				var m := InputEventMouseMotion.new()
				m.position = Vector2(360, 900 - i * 40)
				m.global_position = m.position
				m.button_mask = MOUSE_BUTTON_MASK_LEFT
				root.push_input(m)
				await process_frame
			var up := InputEventMouseButton.new()
			up.button_index = MOUSE_BUTTON_LEFT
			up.pressed = false
			up.position = Vector2(360, 540)
			up.global_position = up.position
			root.push_input(up)
			await _settle(0.5)
			print("drag: content y ", y0, " -> ", content.position.y, " coins ", g.s.coins)
			_save(name)
		"offer_starter_pack", "offer_special_pack", "offer_level_pack", "offer_rescue_pack", "offer_remove_ads":
			await _fresh(17)
			_main.open_popup("res://scenes/popup_offer.tscn", {"id": name.trim_prefix("offer_")})
			await _settle()
			_save(name)
		"offer_timer":
			await _fresh(11)
			g.s.level = 11
			g.test_now = NOW + 400
			var id: String = g.check_offer(false)
			print("offer id ", id)
			_main.open_popup("res://scenes/popup_offer.tscn", {"id": id})
			await _settle()
			_save(name)
		_:
			await _fresh(10)
			_main.open_popup("res://scenes/%s.tscn" % name, {})
			await _settle()
			_save(name)
