extends Control
## Danh sách các màn đã dựng UI nhưng chưa nối logic. Chỉ mở từ Settings khi Config.ui_preview.
## Chạm một dòng để xem màn đó với dữ liệu mẫu. Khung và danh sách cuộn nằm trong scenes/ui_gallery.tscn, mỗi dòng
## SCREENS sinh lúc chạy. setup(args); signal closed(null).

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
	["9.1", "popup_streak_intro"], ["9.2", "streak_main"], ["9.3", "popup_streak_rewards"], ["9.4", "popup_streak_end"], ["9.5", "popup_streak_keep"],
	["10.2", "popup_change_name"], ["10.4", "popup_language"], ["10.5", "popup_help"],
	["11.1", "ad_loading"], ["11.2", "popup_notice"], ["11.3", "popup_reward"],
]

func setup(_args: Dictionary = {}) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The PopupKit frame (dim, ribbon, X) and the scrolling list are nodes of scenes/ui_gallery.tscn; one row per
	# SCREENS entry is added here.
	(%TitleLabel as Label).text = tr("settings_gallery")
	(%CloseX as Button).pressed.connect(func() -> void: closed.emit(null))
	for s in SCREENS:
		var b := ThemeKit.make_button("%s  %s" % [s[0], s[1]], "ghost")
		b.name = "Open_" + str(s[1])
		b.add_theme_font_size_override("font_size", ThemeKit.FS_SMALL)
		b.pressed.connect(_open.bind(str(s[1])))
		%List.add_child(b)
	PopupKit.show_in({"card": %Panel})


func _open(scene: String) -> void:
	var node := (load("res://scenes/%s.tscn" % scene) as PackedScene).instantiate()
	add_child(node)
	node.call("setup", {})
	node.connect("closed", func(_r: Variant) -> void: node.queue_free())
