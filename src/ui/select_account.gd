extends "res://src/ui/stub_ui.gd"
## Wireframe 1.4 Select Account. Layout of SelectAccountLayer (color-cube-match-puzzle): SelectAccountLayer pools
## one AccountItem per save (avatar, name, level, Select) into the Panel HorizontalLayoutGroup. Its message text
## holds both lines, so the game's body and warning share it. The game's "Linked" line is a copy of that text,
## mirrored below the centre. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")

const ITEM := "Panel/AccountItem"


func _sample() -> Dictionary:
	return SampleData.ACCOUNTS


func _build() -> void:
	ui = UnityUI.build(self, "SelectAccountLayer")
	ui.text("Title", tr("boot_account_title"))
	ui.text("Text (TMP)", "%s\n%s" % [tr("boot_account_body"), tr("boot_account_warn")])
	var linked := UnityKit.spec("SelectAccountLayer", "Text (TMP)")
	linked.n = "Linked"
	linked.r[5] = -float(linked.r[5])
	UnityKit.add(ui.node(""), linked).text("", tr("boot_account_linked"))
	# SelectAccountItem.Awake hides the template; the pool shows one copy per account.
	ui.show(ITEM, false)
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
