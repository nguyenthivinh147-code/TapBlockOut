extends "res://src/ui/stub_ui.gd"
## Wireframe 3.8 New Booster Unlocked: popup quà booster hướng dẫn khi tới level mở booster (level.gd, design.md
## mục 3 "Mở khoá theo level"). Bố cục BoosterTutorialLayer (color-cube-match-puzzle): tiêu đề ba lớp chữ, tên
## booster, icon giữa tia sáng quay, số lượng trong kho, lời tặng. ClaimButton ẩn: quà không bán kèm. Dòng
## "Chạm để tiếp tục" là bản sao chữ mô tả, đặt vào chỗ nút; chạm đâu cũng đóng.
## Cùng khung giới thiệu cơ chế mới ở level dạy (design.md mục 4): tiêu đề "VẬT CẢN MỚI!", tên, icon và luật của cơ
## chế; không có số lượng, luật dời lên chỗ số lượng.
## setup({view}): view = {kind ("hint" | "move" | "smash"), count} hoặc {mech ("stone" | "ice" | ... | "pulse")}.
## closed({"action": "close"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")

const PANEL := "GameObject/UnlockPanel"
const HEADERS := ["txtHeader BG2", "txtHeader BG1", "txtHeader"]
## Smallest title size _fit_title shrinks to.
const TITLE_MIN_FS := 60


func _sample() -> Dictionary:
	return SampleData.BOOSTER_UNLOCK


func _build() -> void:
	# The booster icon and TapLabel are saved in scenes/booster_unlocked.tscn.
	ui = UnityUI.build(self, "BoosterTutorialLayer")
	var mech := str(view.get("mech", ""))
	var qty: Label = ui.label(PANEL + "/BoosterQuantity")
	if mech != "":
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
	var claim: Control = ui.node(PANEL + "/ClaimButton")
	claim.visible = false
	# "Tap to continue" takes the hidden button's place.
	var tap: Label = %TapLabel
	tap.position.y = claim.position.y + (claim.size.y - tap.size.y) * 0.5
	UnityUI.set_text(tap, tr("boot_tap_continue"))


func _show_item(title: String, item_name: String, icon: String, desc: String) -> void:
	for h in HEADERS:
		ui.text(PANEL + "/Image/" + h, title)
	_fit_title()
	ui.text(PANEL + "/BoosterName", item_name)
	ui.texture(PANEL + "/BoosterImage/Icon", ThemeKit.icon(icon))
	ui.text(PANEL + "/BoosterDescription", desc)


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
