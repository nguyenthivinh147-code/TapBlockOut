extends SceneTree
## Private shots for the lvl group (deleted at the end).
## tools/godot.sh --path . --resolution 720x1280 -s res://tests/_shot_lvl.gd -- --tag=lvl720 --lang=en --only=dlg_booster,...
## raw_<Layer>[_win|_lose]: prefab as exported, no game content.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const MAIN := "res://scenes/main.tscn"
const OUT := "res://tests/shots/"
const NOW := 1800000000

var tag := "lvl720"
var lang := "en"
var only: Array = []
var _main: Control = null
var _n := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tag="):
			tag = a.substr(6)
		elif a.begins_with("--lang="):
			lang = a.substr(7)
		elif a.begins_with("--only="):
			only = a.substr(7).split(",")
	_run.call_deferred()


func _run() -> void:
	for name in only:
		if str(name).begins_with("raw_"):
			await _raw(str(name))
		else:
			await _scenario(str(name))
	quit(0)


func _save(name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s%s_%s_%s.png" % [OUT, name, tag, lang])
	print("shot ", name)


func _raw(name: String) -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = Color("3a5a7a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	var parts: PackedStringArray = name.trim_prefix("raw_").split("_")
	var layer := parts[0]
	var v: RefCounted = UnityUI.build(host, layer)
	if layer == "EndGameUILayer":
		var win := parts.size() > 1 and parts[1] == "win"
		v.show("Panel/WinPanel", win)
		v.show("Panel/LossPanel", not win)
		v.node("Panel/WinPanel").modulate.a = 1.0
		v.node("Panel/LossPanel").modulate.a = 1.0
	if layer == "PopupReviveLayer" and parts.size() > 1:
		v.show("Bg/Panel/Content/GameObject", true)
		v.show("Bg/Panel/Content/FreeObject", false)
		v.show("Bg/Panel/HelperPack", false)
		v.show("Bg/Panel/Text (TMP)", false)
		v.show("Bg/Panel/Text (TMP) (1)", true)
		v.relayout("Bg/Panel/Content/GameObject")
	await _wait(1.2)
	_save(name)
	host.queue_free()
	await process_frame


func _wait(sec: float) -> void:
	for i in 6:
		await process_frame
	await create_timer(sec).timeout


func _g() -> Node:
	return root.get_node("Game")


func _fresh(level: int, gold: int = 12345, inv: Dictionary = {"hint": 2, "move": 1, "smash": 3}, gifted: bool = true) -> void:
	if _main != null:
		_main.queue_free()
		_main = null
		await process_frame
	_n += 1
	var g := _g()
	g.reset_for_test("user://shots_lvl_%d" % _n)
	g.test_now = NOW
	_main = (load(MAIN) as PackedScene).instantiate() as Control
	root.add_child(_main)
	if not _main.is_booted:
		await _main.booted
	g.test_now = NOW
	g.s.level = level
	g.s.coins = gold
	g.s.inv = inv.duplicate()
	g.s.gifted = {"hint": gifted, "move": gifted, "smash": gifted}
	g.set_setting("lang", lang)
	_main.go("home")
	await _wait(0.3)


func _level() -> Control:
	return _main.current_screen as Control


func _scenario(name: String) -> void:
	var g := _g()
	match name:
		"win_free", "win_msg":
			# L11 is the first win card (free x2); L1–10 have none.
			await _fresh(11 if name == "win_free" else 12)
			_main.go("level")
			await _wait(0.5)
			var att: Dictionary = g.start_attempt()
			var res: Dictionary = g.on_level_won(att)
			var p: Node = _main.open_popup("res://scenes/win_card.tscn", res)
			await _wait(0.4)
			if name == "win_msg":
				root.get_node("Platform").ads.simulate("closed")
				(p.find_child("X2Button", true, false) as Button).pressed.emit()
			await _wait(1.2)
		"lose_plain":
			await _fresh(8)
			_main.go("level")
			await _wait(0.5)
			_main.open_popup("res://scenes/lose_card.tscn", {"offer": "", "life_charged": false})
			await _wait(1.2)
		"lose_pack_ok":
			await _fresh(8)
			_main.go("level")
			await _wait(0.5)
			root.get_node("Platform").iap = load("res://src/platform/mock_iap.gd").new()
			var p: Node = _main.open_popup("res://scenes/lose_card.tscn", {"offer": "rescue_pack", "life_charged": false})
			await _wait(0.4)
			(p.find_child("PackBuyButton", true, false) as Button).pressed.emit()
			await _wait(1.2)
		"rescue_poor", "rescue_novideo":
			await _fresh(8, 100, {"hint": 0, "move": 0, "smash": 0})
			root.get_node("Platform").iap = load("res://src/platform/mock_iap.gd").new()
			_main.go("level")
			await _wait(0.5)
			var att: Dictionary = g.start_attempt()
			att.board.add_moves(-att.board.moves_left())
			var o: Dictionary = g.rescue_offer(att).duplicate()
			if name == "rescue_novideo":
				o.video = false
			o["attempt"] = att
			var p: Node = _main.open_popup("res://scenes/popup_rescue.tscn", o)
			await _wait(0.5)
			if name == "rescue_poor":
				root.get_node("Platform").ads.simulate("closed")
				(p.find_child("VideoButton", true, false) as Button).pressed.emit()
			await _wait(0.8)
		"dlg_booster":
			await _fresh(12, 0, {"hint": 0, "move": 0, "smash": 0})
			_main.go("level")
			await _wait(0.6)
			_level()._on_booster_pressed("move")
			await _wait(0.8)
		"dlg_booster_msg":
			await _fresh(12, 0, {"hint": 0, "move": 0, "smash": 0})
			_main.go("level")
			await _wait(0.6)
			root.get_node("Platform").ads.simulate("closed")
			_level()._on_booster_pressed("move")
			await _wait(0.6)
			var b: Button = _main.popup_layer.find_child("VideoButton", true, false)
			b.pressed.emit()
			await _wait(1.0)
		"dlg_restart":
			await _fresh(12)
			_main.go("level")
			await _wait(0.6)
			var lv := _level()
			lv.attempt.taps = 1
			lv._on_restart_pressed()
			await _wait(0.8)
		"dlg_gift":
			await _fresh(5, 12345, {"hint": 0, "move": 0, "smash": 0}, false)
			_main.go("level")
			await _wait(0.8)
		"dlg_demo_end":
			await _fresh(12)
			_main.go("level")
			await _wait(0.4)
			var lv := _level()
			var dlg = load("res://src/ui/level.gd").Dialog.new(lv.tr("level_title") % 21, lv.tr("level_demo_end"),
				[{"id": "ok", "text": lv.tr("common_ok"), "kind": "primary", "name": "OkButton"}])
			_main.add_popup(dlg)
			await _wait(0.8)
		"banner_hard", "banner_very_hard":
			var want := name.trim_prefix("banner_")
			var lvn := 2
			while lvn < 400 and g.difficulty_of(lvn) != want:
				lvn += 1
			await _fresh(lvn)
			_main.go("level")
			for i in 40:
				await process_frame
				if _level().find_child("DifficultyBanner", true, false) != null:
					break
			await create_timer(0.5).timeout
		"banner_fly":
			var lvn := 2
			while lvn < 400 and g.difficulty_of(lvn) != "hard":
				lvn += 1
			await _fresh(lvn)
			_main.go("level")
			for i in 200:
				await process_frame
				if _level().find_child("DifficultyBannerOut", true, false) != null:
					break
			await create_timer(0.3).timeout
		_:
			push_error("unknown scenario " + name)
			return
	_save(name)
