extends "res://src/ui/stub_ui.gd"
## Wireframe 1.4 Select Account. Layout of SelectAccountLayer (color-cube-match-puzzle): SelectAccountLayer pools
## one AccountItem per save (avatar, name, level, Select) into the Panel HorizontalLayoutGroup. Its message text
## holds both lines, so the game's body and warning share it. The game's "Linked" line is a copy of that text,
## mirrored below the centre. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")

const ITEM := "Panel/AccountItem"


func _sample() -> Dictionary:
	return SampleData.ACCOUNTS


func _build() -> void:
	# Linked (the message text mirrored below the centre) is a node of scenes/select_account.tscn; the hidden
	# AccountItem template (SelectAccountItem.Awake) too.
	ui = UnityUI.build(self, "SelectAccountLayer")
	ui.text("Title", tr("boot_account_title"))
	ui.text("Text (TMP)", "%s\n%s" % [tr("boot_account_body"), tr("boot_account_warn")])
	UnityUI.set_text(%Linked, tr("boot_account_linked"))
	# The pool shows one copy per account.
	for a in view.get("accounts", []):
		_account(a)
	ui.relayout("Panel")


## SelectAccountItem.InitItem.
func _account(a: Dictionary) -> void:
	var item: RefCounted = ui.clone(ITEM)
	item.root.name = "Account_" + str(a.name)
	item.texture("Avatar", ThemeKit.icon(str(a.avatar)))
	item.text("NickName", str(a.name))
	item.text("Level", tr("profile_level") % int(a.level))
	item.text("Button/Text (TMP)", tr("boot_select"))
	item.on_click("Button", _send.bind("select_" + str(a.name)))
