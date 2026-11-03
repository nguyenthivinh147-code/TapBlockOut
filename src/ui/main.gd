extends Control
## Gốc UI: giữ một màn hiện tại và một lớp popup, nối điều hướng giữa các màn.

signal booted

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const Unlocks := preload("res://src/meta/unlocks.gd")
const POPUP_DAILY := "res://scenes/popup_daily.tscn"
const POPUP_OFFER := "res://scenes/popup_offer.tscn"
const SETTINGS := "res://scenes/settings.tscn"
const WEEKLY_PASS := "res://scenes/weekly_pass.tscn"
const CHAIN_OFFER := "res://scenes/chain_offer.tscn"

var current_screen: Node = null
var current_name: String = ""
var popup_layer: Control = null
var is_booted: bool = false


func _ready() -> void:
	theme = ThemeKit.make_theme()
	add_child(ThemeKit.make_background())
	popup_layer = Control.new()
	popup_layer.name = "PopupLayer"
	popup_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(popup_layer)
	_boot()


func _boot() -> void:
	await Game.boot()
	go("home")
	is_booted = true
	booted.emit()
	_chain_autoshow()


## Chain Offer tự mở đúng một lần mỗi chuỗi, khi người chơi đang ở Home.
func _chain_autoshow() -> void:
	if current_name == "home" and Game.chain_take_autoshow():
		_popup_then(CHAIN_OFFER, {}, false)


## screen: "home", "level", "no_lives", "profile", "shop", "challenge".
func go(screen: String, args: Dictionary = {}) -> void:
	var path := "res://scenes/%s.tscn" % screen
	if not ResourceLoader.exists(path):
		push_warning("Thiếu scene màn hình: " + path)
		return
	if current_screen != null:
		current_screen.queue_free()
		current_screen = null
	current_name = screen
	Game.set_in_level(screen == "level" or screen == "challenge")
	var node := (load(path) as PackedScene).instantiate()
	add_child(node)
	move_child(node, popup_layer.get_index())
	current_screen = node
	if node.has_signal("closed"):
		node.connect("closed", _on_screen_closed.bind(screen, node))
	if node.has_method("setup"):
		node.call("setup", args)
	if screen == "home" and is_booted:
		_chain_autoshow.call_deferred()


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
		"home":
			_home_action(action, result as Dictionary if result is Dictionary else {})
		"level":
			if action == "no_lives":
				go("no_lives")
			else:
				go("home")
		"no_lives":
			if action == "refilled":
				go("level")
			else:
				go("home")
		_:
			go("home")


func _home_action(action: String, res: Dictionary) -> void:
	match action:
		"play":
			go("level")
		"no_lives":
			go("no_lives")
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
		"settings":
			_popup_then(SETTINGS, {}, true)
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


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or popup_layer == null:
		return
	var top := _top_popup()
	if top != null:
		if top.has_signal("closed"):
			top.emit_signal("closed", null)
		else:
			top.queue_free()
	elif current_screen != null and current_screen.has_method("on_back"):
		current_screen.call("on_back")
