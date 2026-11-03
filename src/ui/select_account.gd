extends "res://src/ui/stub_ui.gd"
## Wireframe 1.4 Select Account: chọn một trong hai bản lưu. Chưa nối logic.

func _sample() -> Dictionary:
	return SampleData.ACCOUNTS


func _full_screen() -> bool:
	return true


func _title() -> String:
	return tr("boot_account_title")


func _fill(box: VBoxContainer) -> void:
	box.add_child(_say(tr("boot_account_body")))
	box.add_child(_say(tr("boot_account_warn"), ThemeKit.FS_SMALL, ThemeKit.INK_DANGER))
	var cards: Array = []
	for a in view.accounts:
		cards.append(_account(a))
	box.add_child(PopupKit.row(cards))
	box.add_child(_say(tr("boot_account_linked"), ThemeKit.FS_SMALL, ThemeKit.INK_DIM))


func _account(a: Dictionary) -> Control:
	var well := ThemeKit.make_well()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	well.add_child(v)
	v.add_child(ThemeKit.make_icon(str(a.avatar), 130))
	var n := ThemeKit.ink_label(str(a.name), ThemeKit.FS_SMALL + 2)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var lv := ThemeKit.ink_label(tr("profile_level") % int(a.level), ThemeKit.FS_SMALL, ThemeKit.INK_DIM)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lv)
	v.add_child(_btn(tr("boot_select"), "primary", "select_" + str(a.name)))
	return well
