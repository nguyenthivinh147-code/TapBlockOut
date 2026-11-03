extends Control
## Danh sách các màn đã dựng UI nhưng chưa nối logic. Chỉ mở từ Settings khi Config.ui_preview.
## Chạm một dòng để xem màn đó với dữ liệu mẫu. setup(args); signal closed(null).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")

## [số wireframe, scene]
const SCREENS := [
	["1.1", "splash"], ["1.2", "popup_update"], ["1.3", "download_data"], ["1.4", "select_account"],
	["1.5", "tutorial_intro"], ["1.6", "popup_no_internet"],
	["2.3", "popup_ads_daily"], ["2.4", "popup_remove_ads"],
	["3.1", "load_transition"], ["3.3", "popup_mechanic"], ["3.7", "booster_soon"], ["3.8", "booster_unlocked"],
	["3.9", "popup_free_pick"], ["3.11", "speedup_tutorial"],
	["4.2", "popup_bonus"], ["4.3", "popup_rate"], ["4.6", "popup_keep_playing"], ["4.7", "popup_helper_pack"],
	["5.2", "popup_heart_bundle"], ["5.3", "popup_heart_support"],
	["7.5", "popup_weekly_upsell"],
	["8.1", "leaderboard"], ["8.2", "popup_lb_howto"], ["8.3", "popup_leagues"], ["8.4", "popup_lb_result"],
	["9.1", "popup_streak_intro"], ["9.2", "streak_main"], ["9.3", "popup_streak_rewards"], ["9.4", "popup_streak_end"], ["9.5", "popup_streak_keep"],
	["10.2", "popup_change_name"], ["10.4", "popup_language"], ["10.5", "popup_help"],
	["11.1", "ad_loading"], ["11.2", "popup_notice"], ["11.3", "popup_reward"],
]

func setup(_args: Dictionary = {}) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var k := PopupKit.make(self, tr("settings_gallery"), func() -> void: closed.emit(null))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(PopupKit.CONTENT_W, 900)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	(k.box as VBoxContainer).add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for s in SCREENS:
		var b := ThemeKit.make_button("%s  %s" % [s[0], s[1]], "ghost")
		b.name = "Open_" + str(s[1])
		b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
		b.pressed.connect(_open.bind(str(s[1])))
		list.add_child(b)
	PopupKit.show_in(k)


func _open(scene: String) -> void:
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate()
	add_child(node)
	node.call("setup", {})
	node.connect("closed", func(_r: Variant) -> void: node.queue_free())
