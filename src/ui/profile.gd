extends Control
## Profile (wireframe 10.1) on ProfileLayer of color-cube-match-puzzle: worn avatar and frame, nickname (the saved one or
## the default "Player"; the pencil opens popup_change_name), Avatar | Frame
## tabs (ToggleAnimator swaps the grid and its button group), 3-column grids of Profile_AvtCells / Profile_FrameCells
## clones with the game's avatar and frame pictures. The button under the grid follows ProfileUICoreLayer: Used (worn),
## OK = equip (owned), Buy with the gold price (not owned); the game's video unlock is a copy of SaveButton on the blue
## pill beside Buy. The UID row shows the game's gold (no accounts). Only Game and Sfx are called. Static nodes are in
## scenes/profile.tscn; the cells follow Config.cosmetic_ids and are cloned here.
## closed({"action": "back"}) on X, the dim or Back.

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const UView := preload("res://src/ui/u_view.gd")
const Config := preload("res://src/config.gd")

const CHANGE_NAME := "res://scenes/popup_change_name.tscn"
const KINDS: Array[String] = ["avatar", "frame"]
const LAYER := "ProfileLayer"
const INFO := "Panel/ProfileMenu/PlayerInfo"
const UID := "Panel/ProfileMenu/PlayerInfo/UID but very DeviceID"
## Per kind: tab toggle, scroll host, grid content, pooled cell, button group (ProfileUICoreLayer fields).
const PARTS := {
	"avatar": {"tab": "Panel/ProfileMenu/BG/ToggleGroup/Avatar", "scroll": "Panel/ProfileMenu/BG/Avatar",
		"content": "Panel/ProfileMenu/BG/Avatar/Viewport/Content",
		"cell": "Panel/ProfileMenu/BG/Avatar/Viewport/Content/Profile_AvtCells",
		"image": "", "group": "Panel/ProfileMenu/AvatarButtonGroup", "label": "profile_avatars"},
	"frame": {"tab": "Panel/ProfileMenu/BG/ToggleGroup/Frame", "scroll": "Panel/ProfileMenu/BG/Frame",
		"content": "Panel/ProfileMenu/BG/Frame/Viewport/Content",
		"cell": "Panel/ProfileMenu/BG/Frame/Viewport/Content/Profile_FrameCells",
		"image": "FrameImage", "group": "Panel/ProfileMenu/FrameButtonGroup", "label": "profile_frames"},
}
## Buy and video side by side: 286-wide pills 20 apart (SettingMainMenuLayer's two pills sit 20 apart).
const PAIR_X := 153.0
const BTN_Y := -364.0

var gold_label: Label = null
var name_label: Label = null
var status_label: Label = null
var preview: Control = null
var back_btn: Button = null
var ui: UView = null
var tab_buttons: Dictionary = {}
var use_button: Button = null
var buy_button: Button = null
var video_button: Button = null
## id -> {"panel": Button, "ring": Control, "check": Control, "lock": Control}
var cells: Dictionary = {}

var _args: Dictionary = {}
var _built: bool = false
var _tab: String = "avatar"
var _sel: Dictionary = {}
## kind -> {"save", "used", "buy", "video": Button}
var _actions: Dictionary = {}
var _busy: bool = false


## Avatar có frame bao ngoài. Thiếu ảnh thật thì avatar là hình tròn placeholder, frame là vòng viền.
static func make_avatar(avatar_id: String, frame_id: String, px: int) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := int(px * 0.08)
	var av := TextureRect.new()
	av.texture = ThemeKit.icon(avatar_id)
	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av.set_anchors_preset(Control.PRESET_FULL_RECT)
	av.offset_left = pad
	av.offset_top = pad
	av.offset_right = -pad
	av.offset_bottom = -pad
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	av.name = "Avatar"
	root.add_child(av)
	var fr: Control = null
	if ThemeKit.has_real_icon(frame_id):
		var tr_rect := TextureRect.new()
		tr_rect.texture = ThemeKit.icon(frame_id)
		tr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fr = tr_rect
	else:
		var panel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.set_corner_radius_all(px)
		var keys := ThemeKit.BLOCK_COLORS.keys().slice(0, 4)
		var col: Color = ThemeKit.TEXT_DIM
		if not frame_id.ends_with("_00"):
			col = ThemeKit.BLOCK_COLORS[keys[absi(frame_id.hash()) % keys.size()]]
		sb.border_color = col
		sb.set_border_width_all(maxi(4, int(px * 0.05)))
		panel.add_theme_stylebox_override("panel", sb)
		fr = panel
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.name = "Frame"
	root.add_child(fr)
	return root


func _ready() -> void:
	_build()
	_connect_game()
	refresh()


func _exit_tree() -> void:
	if Game.coins_changed.is_connected(_on_game_changed):
		Game.coins_changed.disconnect(_on_game_changed)
	if Game.cos_changed.is_connected(_on_game_changed):
		Game.cos_changed.disconnect(_on_game_changed)


func setup(args: Dictionary) -> void:
	_args = args
	_build()
	_connect_game()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()


func _connect_game() -> void:
	if not Game.coins_changed.is_connected(_on_game_changed):
		Game.coins_changed.connect(_on_game_changed)
	if not Game.cos_changed.is_connected(_on_game_changed):
		Game.cos_changed.connect(_on_game_changed)


func _on_game_changed(_v: Variant = null) -> void:
	refresh()


func _build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# scenes/profile.tscn holds the game background under the dim (Profile is a screen here, a popup over the main
	# menu in Unity), the gold icon, both VideoButtons and StatusLabel, and hides CopyBtn, the tabs' red dots and the
	# pooled cells. Layer nodes keep their prefab names there (a renamed instanced node loses its overrides): renamed
	# here.
	ui = UnityUI.build(self, LAYER)
	# The prefab root sits at x -5; UICoreLayer.SetShowOrHide puts the layer at anchoredPosition 0 when shown. Set
	# here: a scene does not keep an instanced node's offset changed back to 0.
	var rr: Dictionary = ui.root.get_meta("u_rect")
	rr.pos = Vector2.ZERO
	UnityUI.apply_rect(ui.root)
	var cosm: Dictionary = Game.s.cos
	_sel = {"avatar": str(cosm.get("avatar", "avatar_00")), "frame": str(cosm.get("frame", "frame_00"))}
	_tab = "avatar"
	ui.text("Panel/ProfileMenu/Image/txtHeader", tr("profile_title"))
	back_btn = ui.on_click("Panel/ProfileMenu/Top/btnTurnOff", _close)
	back_btn.name = "BackButton"
	ui.on_click("Bg", _close)
	_wire_info()
	for kind in KINDS:
		_wire_kind(kind)
	status_label = %StatusLabel
	status_label.text = ""


## PlayerInfo: worn avatar and frame, nickname box, gold where Unity shows the device id.
func _wire_info() -> void:
	preview = ui.node(INFO + "/CurrentAvt")
	preview.name = "Preview"
	ui.text(INFO + "/Label", tr("profile_nickname"))
	name_label = ui.text(INFO + "/PlayerName/Placeholder", tr("profile_name_default"))
	name_label.name = "NameLabel"
	ui.on_click(INFO + "/Editname", _on_edit_name).name = "EditNameButton"
	ui.text(UID, "")
	gold_label = ui.label(UID + "/DeviceID")
	gold_label.name = "GoldLabel"


## One kind: tab toggle, pooled cells (ProfileUICoreLayer.SetupAvatarList / SetupFrameList), button group.
func _wire_kind(kind: String) -> void:
	var p: Dictionary = PARTS[kind]
	var tab := ui.button(str(p.tab))
	tab.name = "Tab_" + kind
	ui.text(str(p.tab) + "/Text (TMP)", tr(str(p.label)))
	tab.connect("clicked", _on_tab.bind(kind))
	tab_buttons[kind] = tab
	ui.node(str(p.scroll)).name = "Grid_" + kind
	var group := ButtonGroup.new()
	for id in Config.cosmetic_ids(kind):
		var v: RefCounted = ui.clone(str(p.cell))
		var b := v.root as Button
		b.name = "Cell_" + str(id)
		b.button_group = group
		# Clones join the ScrollRect content after build: let drags through like _pass_buttons does.
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		var pic: Control = b if str(p.image) == "" else v.node(str(p.image))
		UnityUI.image_of(pic).call("set_texture", ThemeKit.icon(str(id)))
		b.connect("clicked", _on_cell.bind(str(id)))
		cells[str(id)] = {"panel": b, "ring": v.node("Select"), "check": v.node("Equipped"), "lock": v.node("Lock")}
	ui.relayout(str(p.content))
	var g := str(p.group)
	var save := ui.on_click(g + "/SaveButton", _on_equip_selected)
	ui.text(g + "/SaveButton/Text (TMP)", tr("profile_equip"))
	var used := ui.button(g + "/UsedButton")
	ui.text(g + "/UsedButton/Text (TMP)", tr("profile_equipped"))
	var buy := ui.on_click(g + "/BuyButton", _on_buy_selected)
	# Gold buy button like every gold price: atlas_main's yellow pill, coin then price (the prefab has price then coin).
	UnityKit.gold_pill(buy)
	var coin := ui.node(g + "/BuyButton/Image")
	UnityKit.gold_coin(coin)
	var price := ui.node(g + "/BuyButton/Text (TMP)")
	if coin.get_index() > price.get_index():
		buy.move_child(coin, price.get_index())
	_actions[kind] = {"save": save, "used": used, "buy": buy, "video": _video_button(g)}


## The game's video unlock (VideoButton in the scene): SaveButton copy on the blue pill, TV left of the text like
## PopupRewardLayer's x2.
func _video_button(group: String) -> Button:
	var b := ui.node(group).get_node("VideoButton") as Button
	UnityUI.set_text(b.get_node("Text (TMP)") as Label, tr("ads_watch"))
	b.connect("clicked", _on_video_selected)
	b.visible = false
	return b


func _kind_of(id: String) -> String:
	return "frame" if id.begins_with("frame_") else "avatar"


func refresh() -> void:
	if not _built:
		return
	var cosm: Dictionary = Game.s.cos
	var av_id := str(cosm.get("avatar", "avatar_00"))
	var fr_id := str(cosm.get("frame", "frame_00"))
	var owned: Array = cosm.owned
	gold_label.text = str(int(Game.s.coins))
	var nick := Game.profile_name()
	UnityUI.set_text(name_label, nick if nick != "" else tr("profile_name_default"))
	ui.texture(INFO + "/CurrentAvt", ThemeKit.icon(av_id))
	ui.texture(INFO + "/CurrentFrame", ThemeKit.icon(fr_id))
	for id in cells:
		var e: Dictionary = cells[id]
		var kind := _kind_of(str(id))
		var picked := str(id) == str(_sel.get(kind, ""))
		(e.panel as Button).button_pressed = picked
		# ToggleAnimator.gameObjects (the Select ring) is not applied by unity_ui.gd.
		(e.ring as Control).visible = picked
		(e.check as Control).visible = str(id) == (av_id if kind == "avatar" else fr_id)
		(e.lock as Control).visible = not owned.has(id)
	for kind in KINDS:
		(tab_buttons[kind] as Button).button_pressed = kind == _tab
		_refresh_actions(kind, owned, av_id if kind == "avatar" else fr_id)


## ProfileUICoreLayer.OnAvatarSelected: Used when worn, OK when owned, Buy (+ the game's video) otherwise.
func _refresh_actions(kind: String, owned: Array, worn: String) -> void:
	var a: Dictionary = _actions[kind]
	var id := str(_sel.get(kind, ""))
	var have := owned.has(id)
	var on := id == worn
	(a.used as Control).visible = on
	(a.save as Control).visible = have and not on
	(a.buy as Control).visible = not have
	(a.video as Control).visible = not have
	var group := str(PARTS[kind].group)
	if not have:
		ui.text(group + "/BuyButton/Text (TMP)", str(Config.cosmetic_price(id)))
		_place(a.buy, -PAIR_X)
		_place(a.video, PAIR_X)
		ui.relayout(group + "/BuyButton")
	if kind == _tab:
		use_button = (a.used if on else a.save) if have else null
		buy_button = null if have else a.buy
		video_button = null if have else a.video


func _place(b: Control, x: float) -> void:
	var r: Dictionary = b.get_meta("u_rect")
	r.pos = Vector2(x, BTN_Y)
	UnityUI.apply_rect(b)


## Chọn một món: chuyển sang tab của nó và hiện nút tương ứng.
func select(id: String) -> void:
	if not cells.has(id):
		return
	_tab = _kind_of(id)
	_sel[_tab] = id
	_say("")
	refresh()


func _on_cell(id: String) -> void:
	Sfx.play("button")
	select(id)


func _on_tab(kind: String) -> void:
	if kind == _tab:
		return
	_tab = kind
	_say("")
	refresh()


## popup_change_name over the Profile; a saved name shows in the name box.
func _on_edit_name() -> void:
	if get_node_or_null("ChangeName") != null:
		return
	var node := (load(CHANGE_NAME) as PackedScene).instantiate()
	node.name = "ChangeName"
	add_child(node)
	node.call("setup", {})
	node.connect("closed", func(_r: Variant) -> void:
		node.queue_free()
		refresh())


func _say(text: String) -> void:
	if status_label != null:
		status_label.text = text


func _on_equip_selected() -> void:
	_on_equip(str(_sel.get(_tab, "")))


func _on_buy_selected() -> void:
	_on_buy(str(_sel.get(_tab, "")))


func _on_video_selected() -> void:
	_on_video(str(_sel.get(_tab, "")))


func _on_equip(id: String) -> void:
	_say("")
	Game.cos_equip(id)


func _on_buy(id: String) -> void:
	if Game.cos_buy(id):
		_say("")
		Sfx.play("coin")
		Game.cos_equip(id)
	else:
		_say(tr("profile_not_enough"))


func _on_video(id: String) -> void:
	if _busy:
		return
	_busy = true
	var ok: bool = await Game.cos_unlock_video(id)
	_busy = false
	if ok:
		_say("")
		Game.cos_equip(id)
	elif Game.last_ad_reason == "closed":
		_say(tr("ads_closed_early"))
	elif Game.last_ad_reason == "error":
		_say(tr("ads_failed"))
	else:
		_say(tr("ads_not_available"))


func _close() -> void:
	closed.emit({"action": "back"})
