extends Control
## Profile (wireframe 10.1) on ProfileLayer of color-cube-match-puzzle: avatar and frame preview (the picked cells, the
## worn ones on open), nickname (the saved one or
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
const Cosmetics := preload("res://src/meta/cosmetics.gd")
const Leaderboard := preload("res://src/meta/leaderboard.gd")
const UiTween := preload("res://src/ui/ui_tween.gd")

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
## Items only league rewards give: Leaderboard note and button side by side, 286-wide pills 20 apart.
const PAIR_X := 153.0
const BTN_Y := -364.0
## "Unlocked at Level N" line in place of Buy and video (items only Road Trip gives, Road Trip still locked).
const RT_LABEL := Vector2(640, 110)
## Items only league rewards give: "Reach Platinum League ... to get it" where Buy sits (left), the Leaderboard button
## or "Unlocked at Level N" where video sits (right). No room for a line between the grid and the buttons.
const LB_NOTE := Vector2(300, 120)

var gold_label: Label = null
var name_label: Label = null
var status_label: Label = null
var preview: Control = null
var back_btn: Button = null
var ui: UView = null
var tab_buttons: Dictionary = {}
var use_button: Button = null
var video_button: Button = null
## Road Trip button of the shown tab (item only a Road Trip box gives, Road Trip open); null otherwise.
var road_trip_button: Button = null
## Leaderboard button of the shown tab (item only league rewards give, Leaderboard open); null otherwise.
var league_button: Button = null
## id -> {"panel": Button, "ring": Control, "check": Control, "lock": Control}
var cells: Dictionary = {}

var _args: Dictionary = {}
var _built: bool = false
var _tab: String = "avatar"
var _sel: Dictionary = {}
## kind -> {"save", "used", "video": Button, ...}
var _actions: Dictionary = {}
var _busy: bool = false


## Avatar có frame bao ngoài. Thiếu ảnh thật thì avatar là hình tròn placeholder, frame là vòng viền.
## inset: phần avatar thụt vào mỗi cạnh so với frame (tỉ lệ px). Góc avatar bo to hơn góc lỗ frame,
## nên 8% hở ở góc; 3% lấp kín lỗ của mọi frame_00..12 mà không lòi ra ngoài.
static func make_avatar(avatar_id: String, frame_id: String, px: int, inset: float = 0.08) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(px, px)
	root.size = Vector2(px, px)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := int(px * inset)
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


## Icon of an avatar or frame reward (Road Trip box): a new avatar inside the worn frame, or a new frame around the
## worn avatar, so it shows the way it will look. `worn` is s.cos.
static func reward_icon(id: String, worn: Dictionary, px: int) -> Control:
	if id.begins_with("frame_"):
		return make_avatar(str(worn.get("avatar", "avatar_00")), id, px)
	return make_avatar(id, str(worn.get("frame", "frame_00")), px)


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
	name_label = ui.text(INFO + "/PlayerName/Placeholder", "")
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
	# Cosmetics are not sold for gold (design.md mục 5): the prefab's BuyButton stays hidden.
	ui.node(g + "/BuyButton").visible = false
	_actions[kind] = {"save": save, "used": used, "video": _video_button(g)}
	_actions[kind].merge(_road_trip_parts(g))
	_actions[kind].merge(_league_parts(g))


## Where the video button sits, for an item only a Road Trip box gives (Cosmetics.road_trip_box): a green Road Trip button
## that opens the Road Trip screen, or "Unlocked at Level N" while Road Trip is still locked.
func _road_trip_parts(group: String) -> Dictionary:
	var save: Dictionary = (ui.node(group + "/SaveButton") as Control).get_meta("u_rect")
	var b: Control = UnityKit.button(ui.node(group), "green", tr("rt_title"), Rect2(Vector2.ZERO, save.size),
		_on_road_trip).root
	b.name = "RoadTripButton"
	var l := UnityKit.label(ui.node(group), "", Rect2(0, 0, RT_LABEL.x, RT_LABEL.y), 40.0, "ffffffff",
		"Baloo Outline - Purple")
	l.name = "RoadTripLocked"
	for c: Control in [b, l]:
		var r: Dictionary = c.get_meta("u_rect")
		r.amin = save.amin
		r.amax = save.amax
		r.pivot = Vector2(0.5, 0.5)
		r.pos = Vector2(0, BTN_Y)
		UnityUI.apply_rect(c)
		c.visible = false
	return {"rt": b, "rt_locked": l}


## Road Trip button: leave the Profile for the Road Trip screen (Main routes the action).
func _on_road_trip() -> void:
	closed.emit({"action": "road_trip"})


## Where the video button sits, for an item only league rewards give (Cosmetics.league_only): the line "Reach Platinum
## League or higher in the Leaderboard to get it" (left) beside a green Leaderboard button that opens the
## Leaderboard popup over Home, or "Unlocked at Level N" in the button's place while the Leaderboard is locked.
func _league_parts(group: String) -> Dictionary:
	var save: Dictionary = (ui.node(group + "/SaveButton") as Control).get_meta("u_rect")
	var b: Control = UnityKit.button(ui.node(group), "green", tr("lb_title"), Rect2(Vector2.ZERO, save.size),
		_on_league).root
	b.name = "LeagueButton"
	var l := UnityKit.label(ui.node(group), "", Rect2(Vector2.ZERO, LB_NOTE), 36.0, "ffffffff",
		"Baloo Outline - Purple")
	l.name = "LeagueLocked"
	var note := UnityKit.label(ui.node(group), "", Rect2(Vector2.ZERO, LB_NOTE), 32.0, "ffffffff",
		"Baloo Outline - Purple")
	note.name = "LeagueNote"
	for c: Control in [b, l, note]:
		var r: Dictionary = c.get_meta("u_rect")
		r.amin = save.amin
		r.amax = save.amax
		r.pivot = Vector2(0.5, 0.5)
		r.pos = Vector2(-PAIR_X if c == note else PAIR_X, BTN_Y)
		UnityUI.apply_rect(c)
		c.visible = false
	return {"lb": b, "lb_locked": l, "lb_note": note}


## Leaderboard button: leave the Profile for Home with the Leaderboard popup (Main routes the action).
func _on_league() -> void:
	closed.emit({"action": "ranking"})


## The game's video unlock (VideoButton in the scene), the only way to get a sale item: SaveButton copy on the blue
## pill, TV left of the text like PopupRewardLayer's x2. Centered under the grid.
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
	# Spending on a cosmetic counts the wallet down instead of jumping.
	UiTween.roll(gold_label, int(Game.s.coins))
	UnityUI.set_text(name_label, Game.profile_name())
	# ProfileUICoreLayer.OnAvatarSelected / OnFrameSelected: the big picture previews the picked cell, owned or not;
	# leaving without OK/Buy keeps the worn one (it is what Home and the leaderboard show).
	ui.texture(INFO + "/CurrentAvt", ThemeKit.icon(str(_sel.get("avatar", av_id))))
	ui.texture(INFO + "/CurrentFrame", ThemeKit.icon(str(_sel.get("frame", fr_id))))
	for id in cells:
		var e: Dictionary = cells[id]
		var kind := _kind_of(str(id))
		var picked := str(id) == str(_sel.get(kind, ""))
		(e.panel as Button).button_pressed = picked
		# ToggleAnimator disables a pressed toggle ("a selected tab cannot be pressed again"); a cell must never stay
		# disabled, or the avatar previewed before this one cannot be tapped again.
		(e.panel as Button).disabled = false
		# ToggleAnimator.gameObjects (the Select ring) is not applied by unity_ui.gd.
		(e.ring as Control).visible = picked
		(e.check as Control).visible = str(id) == (av_id if kind == "avatar" else fr_id)
		(e.lock as Control).visible = not owned.has(id)
	for kind in KINDS:
		(tab_buttons[kind] as Button).button_pressed = kind == _tab
		_refresh_actions(kind, owned, av_id if kind == "avatar" else fr_id)


## ProfileUICoreLayer.OnAvatarSelected: Used when worn, OK when owned, the video button otherwise.
func _refresh_actions(kind: String, owned: Array, worn: String) -> void:
	var a: Dictionary = _actions[kind]
	var id := str(_sel.get(kind, ""))
	var have := owned.has(id)
	var on := id == worn
	var rt_only := not have and Cosmetics.road_trip_box(id) > 0
	var lb_only := not have and Cosmetics.league_only(id)
	var sale := not have and not rt_only and not lb_only
	var rt_view: Dictionary = Game.road_trip_view() if rt_only else {}
	var rt_open := rt_only and bool(rt_view.get("open", false))
	var lb_open := lb_only and Game.lb_open()
	(a.used as Control).visible = on
	(a.save as Control).visible = have and not on
	(a.video as Control).visible = sale
	(a.rt as Control).visible = rt_open
	(a.rt_locked as Control).visible = rt_only and not rt_open
	if rt_only and not rt_open:
		UnityUI.set_text(a.rt_locked as Label, tr("common_locked_level") % int(rt_view.get("unlock_level", 0)))
	(a.lb as Control).visible = lb_open
	(a.lb_locked as Control).visible = lb_only and not lb_open
	(a.lb_note as Control).visible = lb_only
	if lb_only:
		UnityUI.set_text(a.lb_note as Label, tr("profile_league_only") % tr("lb_league_" +
			Leaderboard.league_id(maxi(Leaderboard.cos_from(), 0))))
		if not lb_open:
			UnityUI.set_text(a.lb_locked as Label, tr("common_locked_level") % int(Config.UNLOCK.get("leaderboard", 0)))
	if sale:
		_place(a.video, 0.0)
	if kind == _tab:
		use_button = (a.used if on else a.save) if have else null
		video_button = a.video if sale else null
		road_trip_button = a.rt if rt_open else null
		league_button = a.lb if lb_open else null


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


func _on_video_selected() -> void:
	_on_video(str(_sel.get(_tab, "")))


func _on_equip(id: String) -> void:
	_say("")
	Game.cos_equip(id)


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
	elif Game.notice_shown(Game.last_ad_reason):
		_say("")  # Main đã báo bằng popup (Game.notice)
	else:
		_say(tr("ads_failed"))


func _close() -> void:
	closed.emit({"action": "back"})
