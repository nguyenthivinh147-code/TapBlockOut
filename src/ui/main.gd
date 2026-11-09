extends Control
## Gốc UI: giữ một màn hiện tại và một lớp popup, nối điều hướng giữa các màn.

signal booted

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const Config := preload("res://src/config.gd")
const POPUP_DAILY := "res://scenes/popup_daily.tscn"
## Leaderboard: popup over Home (design.md mục 7 "Leaderboard theo league").
const LEADERBOARD := "res://scenes/leaderboard.tscn"
const POPUP_OFFER := "res://scenes/popup_offer.tscn"
const SETTINGS := "res://scenes/settings.tscn"
const WEEKLY_PASS := "res://scenes/weekly_pass.tscn"
const CHAIN_OFFER := "res://scenes/chain_offer.tscn"
const NO_LIVES := "res://scenes/no_lives.tscn"
const TESTER := "res://scenes/tester_menu.tscn"
const STREAK_POPUPS := {"intro": "res://scenes/popup_streak_intro.tscn", "main": "res://scenes/streak_main.tscn",
	"end": "res://scenes/popup_streak_end.tscn"}
const STREAK_RULES := "res://scenes/popup_streak_rewards.tscn"
const REMOVE_ADS := "res://scenes/popup_remove_ads.tscn"
const WEEKLY_UPSELL := "res://scenes/popup_weekly_upsell.tscn"
const POPUP_UPDATE := "res://scenes/popup_update.tscn"
const SELECT_ACCOUNT := "res://scenes/select_account.tscn"
const POPUP_NOTICE := "res://scenes/popup_notice.tscn"
const NO_INTERNET := "res://scenes/popup_no_internet.tscn"
const AD_LOADING := "res://scenes/ad_loading.tscn"
const TesterMenu := preload("res://src/ui/tester_menu.gd")
const LevelCurtain := preload("res://src/ui/level_curtain.gd")
const CandyCurtain := preload("res://src/ui/candy_curtain.gd")
const BombCurtain := preload("res://src/ui/bomb_curtain.gd")
## Màn đặc biệt (design.md mục 7): popup mời / chờ vé.
const POPUP_SPECIAL := "res://scenes/popup_special.tscn"
const HubNav := preload("res://src/ui/hub_nav.gd")
const HubTop := preload("res://src/ui/hub_top.gd")
const TapFx := preload("res://src/ui/tap_fx.gd")
const Pudding := preload("res://src/ui/pudding.gd")
const SceneCache := preload("res://src/ui/scene_cache.gd")
## Hub screens left to right, as on the bottom bar: going between two of them slides the screens (_slide_screens).
const HUB_SCREENS := ["shop", "home", "road_trip"]

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
## Lớp "Đang tải video" (ad_loading, wireframe 11.1) khi Game chờ video rewarded; null khi không chờ.
var ad_loading: Control = null


func _ready() -> void:
	theme = ThemeKit.make_theme()
	var tap_fx := TapFx.new()
	tap_fx.name = "TapFx"
	add_child(tap_fx)
	Game.ad_wait.connect(_on_ad_wait)
	Game.notice.connect(_on_notice)
	Game.cloud_conflict.connect(_on_cloud_conflict)
	_boot()


func _boot() -> void:
	go("splash", {"view": {"percent": 0, "version": _version()}})
	# Baked block body SDFs: read on a loader thread while the splash shows.
	Pudding.load_bank_async()
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
	# The bank finished loading on its thread long ago: take it now, the level does not wait on it.
	Pudding.ensure_bank()
	# The game opens straight into the level, without the curtain of Play on Home; Home when it cannot start.
	go("level" if boot_to_level() else "home")
	is_booted = true
	booted.emit()
	_boot_popups()
	_home_autoshow()


## After loading, the game opens on the level when the player can start it: lives (as Play on Home) and a level
## to play (the demo ends at demo_max_level). Otherwise Home.
func boot_to_level() -> bool:
	# A save conflict (select_account) is settled on Home first: the level would run on the save being replaced.
	return bool(Game.lives_view().get("can_play", true)) and Game.level_exists(int(Game.s.level)) 		and Game.cloud_conflict_view().is_empty()


## Sau khi mở game: chọn bản lưu khi cloud xung đột (1.4), rồi popup cập nhật (1.2).
func _boot_popups() -> void:
	_on_cloud_conflict()
	_show_update()


## Popup cập nhật (wireframe 1.2): bắt buộc thì không đóng được; không bắt buộc thì một lần mỗi lần mở game.
func _show_update() -> void:
	var st := Game.update_state()
	if st == "":
		return
	Game.mark_update_asked()
	open_popup(POPUP_UPDATE, {"view": {"force": st == "force"}})


## Bản lưu Google Play khác bản trên máy (Game.cloud_conflict): hỏi chọn khi đang ở Home. Lúc tải game thì
## _boot_popups hỏi (boot_to_level đã chọn Home); đang ở level thì chờ về Home (_home_autoshow).
func _on_cloud_conflict() -> void:
	var v := Game.cloud_conflict_view()
	if v.is_empty() or not is_booted or current_name != "home" or _has_popup(SELECT_ACCOUNT):
		return
	var p := open_popup(SELECT_ACCOUNT, {"view": v})
	if p != null:
		p.connect("closed", func(r: Variant) -> void:
			var pick := str((r as Dictionary).get("action", "")) if r is Dictionary else ""
			Game.resolve_cloud(pick == "select_cloud")
			if current_name == "home":
				go("home"))


func _has_popup(path: String) -> bool:
	for c in popup_layer.get_children():
		if not c.is_queued_for_deletion() and c.scene_file_path == path:
			return true
	return false


## Game đang chờ video: lớp ad_loading trên cùng, chặn chạm; xong thì gỡ.
func _on_ad_wait(on: bool) -> void:
	if on and ad_loading == null:
		ad_loading = SceneCache.instantiate(AD_LOADING)
		ad_loading.name = "AdLoading"
		add_child(ad_loading)
		if ad_loading.has_method("setup"):
			ad_loading.call("setup", {})
	elif not on and ad_loading != null:
		ad_loading.queue_free()
		ad_loading = null


## Lỗi Game đã phân loại: không có video (popup_notice 11.2) hoặc mất mạng (popup_no_internet 1.6).
func _on_notice(kind: String) -> void:
	match kind:
		"not_ready":
			open_popup(POPUP_NOTICE, {"view": {"title": "ads_notice_title", "body": "ads_not_available"}})
		"offline":
			if not _has_popup(NO_INTERNET):
				open_popup(NO_INTERNET)


## "v0.1.0" theo application/config/version; trống thì Splash ẩn dòng version.
func _version() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", ""))
	return "v" + v if v != "" else ""


## Popup tự mở khi về Home, nhiều nhất một cái mỗi lần: chọn bản lưu (1.4), Chain Offer (một lần mỗi chuỗi), giới
## thiệu Win Streak (một lần mỗi lượt, khi chưa bấm Start), Weekly Pass Upsell (một lần mỗi mùa).
func _home_autoshow() -> void:
	if current_name != "home":
		return
	if not Game.cloud_conflict_view().is_empty():
		_on_cloud_conflict()
	elif Game.chain_take_autoshow():
		_popup_then(CHAIN_OFFER, {}, false)
	elif popup_count() > 0:
		return
	elif Game.special_take_invite():
		_open_special()
	elif Game.streak_take_auto_intro():
		_open_streak("intro")
	elif Game.weekly_take_upsell():
		var p := open_popup(WEEKLY_UPSELL)
		if p != null:
			p.connect("closed", func(r: Variant) -> void:
				if r is Dictionary and str(r.get("action", "")) == "bought" and current_name == "home":
					_popup_then(WEEKLY_PASS, {}, false))


## Win Streak (design.md mục 7): popup theo Game.streak_entry. Intro: Start thì Game.streak_start, luật (9.3) rồi
## Main (UIPopupWinStreakInstruction.OnStartButtonClicked, luật đóng thì mở Main). Main: Chơi vào level.
func _open_streak(entry: String) -> void:
	var path := str(STREAK_POPUPS.get(entry, ""))
	if path == "":
		return
	var host := current_screen
	var p := open_popup(path)
	if p == null:
		return
	p.connect("closed", func(r: Variant) -> void:
		var action := str((r as Dictionary).get("action", "")) if r is Dictionary else ""
		if entry == "intro" and action == "go":
			Game.streak_start()
			var rules := open_popup(STREAK_RULES)
			if rules != null:
				rules.connect("closed", func(_r: Variant) -> void: _open_streak("main"))
			return
		if entry == "main" and action == "play" and host == current_screen:
			_home_action("play" if bool(Game.lives_view().get("can_play", true)) else "no_lives", {})
			return
		if host == current_screen and is_instance_valid(host) and host.has_method("refresh"):
			host.call("refresh"))


## screen: "splash", "home", "level", "no_lives", "profile", "shop", "challenge", "road_trip".
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
	# The Road Trip screen sets it itself while its level is open.
	Game.set_in_level(screen == "level" or screen == "challenge")
	# The level starts its own music, also when the Daily Challenge screen hosts it; the loading screen has none.
	if screen != "level" and screen != "splash":
		Sfx.music(Sfx.MUSIC_HOME)
	var node := SceneCache.instantiate(path)
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
		_home_autoshow.call_deferred()


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


## Như go(), có màn chuyển cảnh kẹo rơi (candy_curtain.gd): Home bấm Chơi, nạp mạng xong ở màn hết mạng.
func go_curtain(screen: String, args: Dictionary = {}) -> void:
	await curtain_swap(go.bind(screen, args), CandyCurtain)


## Màn chuyển cảnh `kind` phủ kín màn, gọi swap (dựng màn chơi bên dưới) rồi mở ra. Mặc định level_curtain.gd (hai
## cánh kẹo khép lại kèm logo), dùng ở Daily Challenge; Road Trip truyền gift_curtain.gd (nắp hộp quà).
## Chạm và Back bị chặn suốt lúc chạy; đang có một màn chuyển cảnh thì bỏ qua.
func curtain_swap(swap: Callable, kind: GDScript = LevelCurtain) -> void:
	if curtain != null:
		return
	curtain = kind.new()
	curtain.name = kind.resource_path.get_file().get_basename().to_pascal_case()
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
	var node := SceneCache.instantiate(scene_path)
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
		"shop", "road_trip":
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
				_popup_then(LEADERBOARD, {}, false)
		"road_trip":
			if bool(Game.road_trip_view().get("open", false)):
				go("road_trip")
		"settings":
			_popup_then(SETTINGS, {}, true)
		"offer":
			var oid := str(res.get("id", ""))
			if oid == "remove_ads":
				_popup_then(REMOVE_ADS, {}, false)
			else:
				_popup_then(POPUP_OFFER, {"id": oid}, false)
		"weekly":
			_popup_then(WEEKLY_PASS, {}, false)
		"chain":
			_popup_then(CHAIN_OFFER, {}, false)
		"streak":
			_open_streak(Game.streak_entry())
		"remove_ads":
			_popup_then(REMOVE_ADS, {}, false)
		"special_bomb":
			if bool(Game.special_view().get("open", false)):
				_open_special()
		_:
			pass


## Màn đặc biệt từ Home: popup mời (hết vé thì popup báo thời gian chờ). Bắt đầu thì màn mưa bom rồi vào màn level ở
## chế độ Special (không cần mạng); đóng thì làm mới Home.
func _open_special() -> void:
	var host := current_screen
	var p := open_popup(POPUP_SPECIAL)
	if p == null:
		return
	p.connect("closed", func(r: Variant) -> void:
		if host != current_screen or not is_instance_valid(host):
			return
		if r is Dictionary and str(r.get("action", "")) == "start":
			curtain_swap(go.bind("level", {"special": true}), BombCurtain)
		elif host.has_method("refresh"):
			host.call("refresh"))


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


func _exit_tree() -> void:
	Pudding.finish_bank_load()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or popup_layer == null or curtain != null or _slide_out != null:
		return
	var top := _top_popup()
	if top != null:
		# A forced update cannot be dismissed.
		if top.has_method("blocks_back") and bool(top.call("blocks_back")):
			return
		if top.has_signal("closed"):
			top.emit_signal("closed", null)
		else:
			top.queue_free()
	elif current_screen != null and current_screen.has_method("on_back"):
		current_screen.call("on_back")
