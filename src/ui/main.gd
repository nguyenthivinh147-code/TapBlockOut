extends Control
## Gốc UI: giữ một màn hiện tại và một lớp popup, nối điều hướng giữa các màn.

signal booted

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const POPUP_DAILY := "res://scenes/popup_daily.tscn"
const POPUP_OFFER := "res://scenes/popup_offer.tscn"
const SETTINGS := "res://scenes/settings.tscn"
const WEEKLY_PASS := "res://scenes/weekly_pass.tscn"
const CHAIN_OFFER := "res://scenes/chain_offer.tscn"
const NO_LIVES := "res://scenes/no_lives.tscn"
const TESTER := "res://scenes/tester_menu.tscn"
const TesterMenu := preload("res://src/ui/tester_menu.gd")
const LevelCurtain := preload("res://src/ui/level_curtain.gd")
const HubNav := preload("res://src/ui/hub_nav.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
## Hub screens left to right, as on the bottom bar: going between two of them slides the screens (_slide_screens).
const HUB_SCREENS := ["shop", "home", "leaderboard"]

var current_screen: Node = null
var current_name: String = ""
## Background and PopupLayer are nodes of scenes/main.tscn.
@onready var popup_layer: Control = $PopupLayer
var is_booted: bool = false
## Màn chuyển cảnh đang chạy (go_curtain); null khi không có.
var curtain: Control = null
## Screen slide of a tab switch: the screen sliding out (freed at the end), the bars held in place
## [{node, base, set}], the touch blocker.
var _slide_tw: Tween = null
var _slide_out: Control = null
var _pinned: Array = []
var _slide_block: Control = null


func _ready() -> void:
	theme = ThemeKit.make_theme()
	_boot()


func _boot() -> void:
	go("splash", {"view": {"percent": 0, "version": _version()}})
	var splash := current_screen
	var c: Dictionary = Config.CONTENT
	var hold := float(c.splash_hold)
	var bar := create_tween()
	bar.tween_method(Callable(splash, "set_progress"), 0.0, hold, float(c.splash_min_sec)) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await Game.boot()
	if bar.is_running():
		await bar.finished
	var fill := create_tween()
	fill.tween_method(Callable(splash, "set_progress"), hold, 1.0, float(c.splash_fill_sec))
	await fill.finished
	go("home")
	is_booted = true
	booted.emit()
	_chain_autoshow()


## "v0.1.0" theo application/config/version; trống thì Splash ẩn dòng version.
func _version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return "v" + v if v != "" else ""


## Chain Offer tự mở đúng một lần mỗi chuỗi, khi người chơi đang ở Home.
func _chain_autoshow() -> void:
	if current_name == "home" and Game.chain_take_autoshow():
		_popup_then(CHAIN_OFFER, {}, false)


## screen: "home", "level", "no_lives", "profile", "shop", "challenge", "leaderboard".
func go(screen: String, args: Dictionary = {}) -> void:
	var path := "res://scenes/%s.tscn" % screen
	if not ResourceLoader.exists(path):
		push_warning("Thiếu scene màn hình: " + path)
		return
	var dir := slide_dir(current_name, screen)
	_end_slide()
	var out: Control = null
	if current_screen != null:
		if dir != 0 and current_screen is Control:
			out = current_screen
		else:
			current_screen.queue_free()
		current_screen = null
	current_name = screen
	Game.set_in_level(screen == "level" or screen == "challenge")
	# The level starts its own music, also when the Daily Challenge screen hosts it; the loading screen has none.
	if screen != "level" and screen != "splash":
		Sfx.music(Sfx.MUSIC_HOME)
	var node := (load(path) as PackedScene).instantiate()
	add_child(node)
	move_child(node, popup_layer.get_index())
	current_screen = node
	if node.has_signal("closed"):
		node.connect("closed", _on_screen_closed.bind(screen, node))
	if node.has_method("setup"):
		node.call("setup", args)
	if out != null:
		# Off-screen until the slide starts next frame, once containers have placed the new screen's bars (their
		# sorts are deferred and may queue more); the old screen keeps its bars for that frame.
		_slide_out = out
		(node as Control).position.x = dir * size.x
		_slide_block = Control.new()
		_slide_block.name = "SlideBlock"
		_slide_block.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_slide_block)
		move_child(_slide_block, popup_layer.get_index())
		get_tree().process_frame.connect(_slide_screens.bind(node, dir), CONNECT_ONE_SHOT)
	if screen == "home" and is_booted:
		_chain_autoshow.call_deferred()


## Side the new screen comes from when going between hub screens: 1 from the right (a tab further right), -1 from the
## left, 0 no slide.
static func slide_dir(from: String, to: String) -> int:
	if not (HUB_SCREENS.has(from) and HUB_SCREENS.has(to)):
		return 0
	return signi(HUB_SCREENS.find(to) - HUB_SCREENS.find(from))


## Tab switch: the new screen slides in from its tab's side while the old one (_slide_out) slides out, over
## HubNav.SLIDE_SEC like the bar's highlight. The new screen's top and bottom bars stay in place and the old one's hide;
## touch and Back wait for the end.
func _slide_screens(into: Control, dir: int) -> void:
	if into != current_screen or _slide_out == null:
		return
	for bar in _bars(_slide_out):
		bar.visible = false
	for bar in _bars(into):
		_pinned.append({"node": bar, "base": bar.position, "set": bar.position})
	_slide_step(0.0, dir)
	_slide_tw = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_slide_tw.tween_method(_slide_step.bind(dir), 0.0, 1.0, HubNav.SLIDE_SEC)
	_slide_tw.finished.connect(_end_slide)


func _slide_step(k: float, dir: int) -> void:
	if is_instance_valid(_slide_out):
		_slide_out.position.x = -dir * size.x * k
	var into := current_screen as Control
	into.position.x = dir * size.x * (1.0 - k)
	for p: Dictionary in _pinned:
		var bar: Control = p.node
		if not is_instance_valid(bar):
			continue
		# A bar the screen laid out again since the last step keeps its new place.
		if not bar.position.is_equal_approx(p.set):
			p.base = bar.position
		var sx := (bar.get_parent() as CanvasItem).get_global_transform().get_scale().x
		bar.position = p.base - Vector2(into.position.x / sx, 0)
		p.set = bar.position


## Ends a screen slide at once (also before the next go()): screen and bars in place, the old screen freed.
func _end_slide() -> void:
	if _slide_tw != null:
		_slide_tw.kill()
		_slide_tw = null
	for p: Dictionary in _pinned:
		var bar: Control = p.node
		if is_instance_valid(bar) and bar.position.is_equal_approx(p.set):
			bar.position = p.base
	_pinned.clear()
	if _slide_out == null:
		return
	if current_screen is Control:
		(current_screen as Control).position = Vector2.ZERO
	if is_instance_valid(_slide_out):
		_slide_out.queue_free()
	_slide_out = null
	_slide_block.queue_free()
	_slide_block = null


## A screen's HubTop and HubNav: they stay in place while the screens slide.
func _bars(screen: Node) -> Array:
	var out: Array = []
	for c in screen.find_children("*", "Control", true, false):
		if c.get_script() == HubNav or c.get_script() == HubTop:
			out.append(c)
	return out


## Như go(), có màn chuyển cảnh vào màn chơi.
func go_curtain(screen: String, args: Dictionary = {}) -> void:
	await curtain_swap(go.bind(screen, args))


## Màn chuyển cảnh: hai cánh kẹo khép lại kèm logo, gọi swap (dựng màn chơi bên dưới) rồi mở ra.
## Chạm và Back bị chặn suốt lúc chạy; đang có một màn chuyển cảnh thì bỏ qua.
func curtain_swap(swap: Callable) -> void:
	if curtain != null:
		return
	curtain = LevelCurtain.new()
	curtain.name = "LevelCurtain"
	add_child(curtain)
	await curtain.close()
	if swap.is_valid():
		swap.call()
	await curtain.open()
	curtain = null


## Đưa một node popup đã dựng sẵn vào lớp popup; nó phải có signal closed (Back đóng được).
func add_popup(node: Node) -> Node:
	popup_layer.add_child(node)
	if node.has_signal("closed"):
		node.connect("closed", func(_r: Variant) -> void: node.queue_free())
	return node


func open_popup(scene_path: String, args: Dictionary = {}) -> Node:
	if not ResourceLoader.exists(scene_path):
		return null
	var node := (load(scene_path) as PackedScene).instantiate()
	add_popup(node)
	if node.has_method("setup"):
		node.call("setup", args)
	return node


func popup_count() -> int:
	var n := 0
	for c in popup_layer.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	return n


func _top_popup() -> Node:
	for i in range(popup_layer.get_child_count() - 1, -1, -1):
		var c := popup_layer.get_child(i)
		if not c.is_queued_for_deletion():
			return c
	return null


# --- điều hướng ---

func _on_screen_closed(result: Variant, screen: String, node: Node) -> void:
	if node != current_screen:
		return
	var action := ""
	if result is Dictionary:
		action = str(result.get("action", ""))
	elif result is String:
		action = result
	match screen:
		"splash":
			pass
		"home":
			_home_action(action, result as Dictionary if result is Dictionary else {})
		"level":
			if action == "no_lives":
				go("no_lives")
			else:
				go("home")
		"no_lives":
			if action == "refilled":
				go_curtain("level")
			else:
				go("home")
		"shop", "leaderboard":
			if action == "" or action == "home":
				go("home")
			else:
				_home_action(action, result as Dictionary if result is Dictionary else {})
		_:
			go("home")


func _home_action(action: String, res: Dictionary) -> void:
	match action:
		"play":
			go_curtain("level")
		"no_lives":
			go("no_lives")
		"lives":
			_popup_then(NO_LIVES, {"source": "hub"}, false)
		"profile":
			go("profile")
		"challenge":
			if bool(Game.challenge_view().get("open", false)):
				go("challenge")
		"gift":
			_popup_then(POPUP_DAILY, {}, false)
		"shop":
			if Unlocks.is_open("shop", int(Game.s.level)):
				go("shop", {"source": "home"})
		"ranking":
			if Game.lb_open():
				go("leaderboard")
		"settings":
			_popup_then(SETTINGS, {}, true)
		"preview":
			_popup_then("res://scenes/%s.tscn" % str(res.get("scene", "")), {}, false)
		"offer":
			_popup_then(POPUP_OFFER, {"id": str(res.get("id", ""))}, false)
		"weekly":
			_popup_then(WEEKLY_PASS, {}, false)
		"chain":
			_popup_then(CHAIN_OFFER, {}, false)
		_:
			pass


## Mở popup trên Home; đóng thì làm mới Home (hoặc dựng lại, khi đổi ngôn ngữ ở Settings).
func _popup_then(path: String, args: Dictionary, rebuild: bool) -> void:
	var host := current_screen
	var p := open_popup(path, args)
	if p == null or not p.has_signal("closed"):
		return
	p.connect("closed", func(_r: Variant) -> void:
		if host != current_screen or not is_instance_valid(host):
			return
		if rebuild and current_name == "home":
			go("home")
		elif host.has_method("refresh"):
			host.call("refresh"))


## F1 (a device with a keyboard): toggles the tester menu over any screen, like 10 taps on the version in Settings.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.keycode == KEY_F1:
		get_viewport().set_input_as_handled()
		toggle_tester()


func toggle_tester() -> Node:
	if not is_booted:
		return null
	for open in get_tree().get_nodes_in_group(TesterMenu.GROUP):
		if not open.is_queued_for_deletion():
			open.emit_signal("closed", null)
			return null
	var p := open_popup(TESTER)
	if p != null:
		p.connect("closed", _on_tester_closed)
	return p


## Saved: rebuild Home, or refresh the screen in place (a level keeps its attempt; a new level number applies to
## the next one). Deleted: every popup closes and the game starts again from Home.
func _on_tester_closed(result: Variant) -> void:
	if not (result is Dictionary):
		return
	if str(result.get("action", "")) == "wiped":
		for c in popup_layer.get_children():
			c.queue_free()
		go("home")
	elif current_name == "home":
		go("home")
	elif current_screen != null and current_screen.has_method("refresh"):
		current_screen.call("refresh")


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or popup_layer == null or curtain != null or _slide_out != null:
		return
	var top := _top_popup()
	if top != null:
		if top.has_signal("closed"):
			top.emit_signal("closed", null)
		else:
			top.queue_free()
	elif current_screen != null and current_screen.has_method("on_back"):
		current_screen.call("on_back")
