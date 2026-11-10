extends "res://src/ui/stub_ui.gd"
## Wireframe 3.8 New Booster Unlocked: popup quà booster hướng dẫn khi tới level mở booster (level.gd, design.md
## mục 3 "Mở khoá theo level"). Bố cục BoosterTutorialLayer (color-cube-match-puzzle): tiêu đề ba lớp chữ, tên
## booster, icon giữa tia sáng quay, số lượng trong kho, lời tặng. ClaimButton ẩn: quà không bán kèm. Dòng
## "Chạm để tiếp tục" là bản sao chữ mô tả, đặt sát lề dưới màn hình (Config.TAP_CONTINUE_BOTTOM); chạm đâu cũng đóng.
## Cùng khung giới thiệu cơ chế mới ở level dạy (design.md mục 4): tiêu đề "VẬT CẢN MỚI!", tên, icon và luật của cơ
## chế; không có số lượng, luật dời lên chỗ số lượng. Bom kẹo (giúp người chơi) có tiêu đề riêng "BOM KẸO!", ẩn dòng tên.
## Cũng là hướng dẫn lần đầu của Màn đặc biệt (design.md mục 7): {special: true} hiện quả bom và luật, không số lượng.
## setup({view}): view = {kind ("hint" | "move" | "smash"), count}, {mech ("stone" | "ice" | ... | "pulse")} hoặc
## {special: true}.
## closed({"action": "close"}).

const Config := preload("res://src/config.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const RewardFly := preload("res://src/ui/reward_fly.gd")

const PANEL := "GameObject/UnlockPanel"
const HEADERS := ["txtHeader BG2", "txtHeader BG1", "txtHeader"]
## Smallest title size _fit_title shrinks to.
const TITLE_MIN_FS := 60
## Mechanics that help the player (design.md section 4, candy bomb): own popup title key, name line hidden.
const HELPER_TITLES := {"pop": "mech_pop_title"}


func _sample() -> Dictionary:
	return SampleData.BOOSTER_UNLOCK


func _build() -> void:
	# The booster icon and TapLabel are saved in scenes/booster_unlocked.tscn.
	ui = UnityUI.build(self, "BoosterTutorialLayer")
	var mech := str(view.get("mech", ""))
	var special := bool(view.get("special", false))
	var qty: Label = ui.label(PANEL + "/BoosterQuantity")
	if mech != "" or special:
		if special:
			_show_item(tr("special_guide_title"), tr("special_title"), "special_bomb", tr("special_guide_desc"))
		elif HELPER_TITLES.has(mech):
			# A helper, not an obstacle: its own title instead of "NEW MECHANIC!", and no name line (same words).
			_show_item(tr(HELPER_TITLES[mech]), "", "mech_" + mech, tr("mech_%s_desc" % mech))
			ui.node(PANEL + "/BoosterName").visible = false
		else:
			_show_item(tr("mech_new_title"), tr("mech_" + mech), "mech_" + mech, tr("mech_%s_desc" % mech))
		# No count for a mechanic: the rule's box grows up over the count's place, so a long rule auto sizes larger.
		qty.visible = false
		var desc: Label = ui.label(PANEL + "/BoosterDescription")
		var qr: Dictionary = qty.get_meta("u_rect")
		var dr: Dictionary = desc.get_meta("u_rect")
		var top := float(qr.pos.y) + float(qr.size.y) * 0.5
		var bottom := float(dr.pos.y) - float(dr.size.y) * 0.5
		dr.pos = Vector2(float(dr.pos.x), (top + bottom) * 0.5)
		dr.size = Vector2(float(dr.size.x), top - bottom)
		UnityUI.apply_rect(desc)
	else:
		var kind := str(view.get("kind", "hint"))
		_show_item(tr("booster_new_title"), tr("booster_" + kind), "booster_" + kind, tr("tut_%s_gift" % kind))
		ui.text(PANEL + "/BoosterQuantity", tr("booster_count") % int(view.get("count", 1)))
		if not UnityUI.baking:
			# The gift is in the inventory already: the booster's button keeps its old count until the icon flies
			# there as the popup closes.
			var gift := {"items": {kind: 1}}
			var icon: Control = ui.node(PANEL + "/BoosterImage/Icon")
			RewardFly.hold(self, gift)
			closed.connect(func(_r: Variant) -> void: RewardFly.launch(self, gift, {kind: icon}), CONNECT_ONE_SHOT)
	ui.node(PANEL + "/ClaimButton").visible = false
	UnityUI.set_text(%TapLabel, tr("boot_tap_continue"))
	# "Tap to continue" sits near the bottom of the screen, kept there when the screen resizes.
	var full: Control = ui.node(PANEL).get_parent()
	full.resized.connect(_place_tap)
	_place_tap()


func _show_item(title: String, item_name: String, icon: String, desc: String) -> void:
	for h in HEADERS:
		ui.text(PANEL + "/Image/" + h, title)
	_fit_title()
	ui.text(PANEL + "/BoosterName", item_name)
	ui.texture(PANEL + "/BoosterImage/Icon", ThemeKit.icon(icon))
	ui.text(PANEL + "/BoosterDescription", desc)


## TapLabel lives in the centered panel (it pops with the panel's reveal), so its bottom is set from the full-screen
## parent's bottom edge in panel coordinates. The panel's top comes from its anchor and offset, not its position, which
## may not be updated yet when the parent's resized fires.
func _place_tap() -> void:
	var panel: Control = ui.node(PANEL)
	var full := panel.get_parent() as Control
	var panel_top := full.size.y * panel.anchor_top + panel.offset_top
	var tap: Label = %TapLabel
	tap.position.y = full.size.y - panel_top - Config.TAP_CONTINUE_BOTTOM - tap.size.y


## The prefab's title is a fixed 120 px that wraps inside a word once a word is wider than the box ("NEW MECHANIC!",
## "NOUVELLE MÉCANIQUE !"). Shrink all three layers alike until the title fits in whole words on at most two lines.
func _fit_title() -> void:
	var main: Label = ui.label(PANEL + "/Image/txtHeader")
	var font := main.get_theme_font("font")
	var fs := main.get_theme_font_size("font_size")
	var w := main.size.x
	var brk := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	while fs > TITLE_MIN_FS:
		var sz := font.get_multiline_string_size(main.text, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, brk)
		if sz.x <= w and sz.y <= font.get_height(fs) * 2.5:
			break
		fs -= 4
	for h in HEADERS:
		ui.label(PANEL + "/Image/" + h).add_theme_font_size_override("font_size", fs)


## "Tap to continue": a tap anywhere closes.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_send("close")
