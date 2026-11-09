extends "res://src/ui/stub_ui.gd"
## Wireframe 1.4 Select Account (design.md mục 8 "Lưu và cloud"): Main mở khi bản lưu Google Play và bản trên máy là
## hai lịch sử chơi khác nhau (Game.cloud_conflict: cả hai đã chơi, khác level, cài ở hai thời điểm). Người chơi chọn
## một bản; bản kia bị bỏ, chỉ đơn mua của nó được gộp (Game.resolve_cloud). Phải chọn: Back không đóng.
## Layout of SelectAccountLayer (color-cube-match-puzzle): SelectAccountLayer pools one AccountItem per save (avatar,
## name, level, Select) into the Panel HorizontalLayoutGroup. Its message text holds both lines, so the game's body and
## warning share it. The game's "Linked" line is a copy of that text, mirrored below the centre.
## setup({view}): Game.cloud_conflict_view() = {local, cloud}, each {name, level, avatar}.
## closed({"action": "select_local" | "select_cloud"}).

const UnityUI := preload("res://src/ui/unity_ui.gd")

const ITEM := "Panel/AccountItem"
## Save -> label key of its source.
const SOURCES := {"local": "boot_account_device", "cloud": "boot_account_cloud"}


func _sample() -> Dictionary:
	var a: Array = SampleData.ACCOUNTS.accounts
	return {"local": a[0], "cloud": a[1]}


func _build() -> void:
	# Linked (the message text mirrored below the centre) is a node of scenes/select_account.tscn; the hidden
	# AccountItem template (SelectAccountItem.Awake) too.
	ui = UnityUI.build(self, "SelectAccountLayer")
	ui.text("Title", tr("boot_account_title"))
	ui.text("Text (TMP)", "%s\n%s" % [tr("boot_account_body"), tr("boot_account_warn")])
	UnityUI.set_text(%Linked, tr("boot_account_linked"))
	# The pool shows one copy per save.
	for key in SOURCES:
		_account(key, view.get(key, {}))
	ui.relayout("Panel")


func blocks_back() -> bool:
	return true


## SelectAccountItem.InitItem: the save's source as the title, then the player's name and level.
func _account(key: String, a: Dictionary) -> void:
	var item: RefCounted = ui.clone(ITEM)
	item.root.name = "Account_" + key
	item.texture("Avatar", ThemeKit.icon(str(a.get("avatar", "avatar_00"))))
	item.text("NickName", tr(str(SOURCES[key])))
	item.text("Level", "%s\n%s" % [str(a.get("name", "")), tr("profile_level") % int(a.get("level", 1))])
	item.text("Button/Text (TMP)", tr("boot_select"))
	item.on_click("Button", _send.bind("select_" + key))
