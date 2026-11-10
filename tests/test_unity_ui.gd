extends RefCounted
## Builder Unity UI (unity_ui.gd): build hai lần một owner, Slider, auto size với ContentSizeFitter, Animator tắt sẵn
## và OnDisplayLayout, AnimScaleButton, TMP_InputField, CutoutMaskUI, alpha dim popup.
const T := preload("res://tests/t.gd")
const UnityUI := preload("res://src/ui/unity_ui.gd")
const UnityKit := preload("res://src/ui/unity_kit.gd")
const ThemeKit := preload("res://src/ui/theme_kit.gd")

const INPUT := "Panel/ProfileMenu/PlayerInfo/InputField (TMP)"


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _owner() -> Control:
	var c := Control.new()
	c.size = Vector2(720, 1280)
	_tree().root.add_child(c)
	return c


func test_two_builds_one_owner(t: T) -> void:
	var o := _owner()
	UnityUI.build(o, "PopupOkLayer", {"reveal": false})
	UnityUI.build(o, "PopupFeedBack", {"reveal": false})
	o.size = Vector2(720, 1560)
	var canvases := o.get_children().filter(func(c: Node) -> bool: return c.has_meta("u_canvas"))
	t.eq(canvases.size(), 2, "hai canvas")
	for c in canvases:
		t.near((c as Control).scale.x, 1560.0 / 1920.0, 0.0001, "canvas co theo owner mới")
	o.free()


func test_slider(t: T) -> void:
	var o := _owner()
	var v := UnityUI.build(o, "DownloadDataLayer", {"reveal": false})
	# Filled fill: fillAmount; handle anchors at the value (prefab value 0.064).
	var fill: Control = v.image("Slider/Fill Area/Fill")
	var handle: Control = v.node("Slider/Handle Slide Area/Handle")
	t.near(float(fill.get("fill_amount")), 0.064, 0.0001, "giá trị prefab")
	t.near(fill.anchor_right, 1.0, 0.0001, "fill Filled phủ vùng fill")
	v.slider("Slider", 0.5)
	t.near(float(fill.get("fill_amount")), 0.5, 0.0001, "fillAmount")
	t.near(handle.anchor_left, 0.5, 0.0001, "handle trái")
	t.near(handle.anchor_right, 0.5, 0.0001, "handle phải")
	v.slider("Slider", 2.0)
	t.near(float(fill.get("fill_amount")), 1.0, 0.0001, "kẹp ở max")
	# Sliced fill: anchorMax.x is the value.
	var bar := UnityKit.add(v.node(""), UnityKit.spec("Slider", ""))
	bar.slider("", 0.3)
	t.near(bar.node("Fill Area/Fill").anchor_right, 0.3, 0.0001, "fill thường theo anchor")
	o.free()


func test_auto_size_fitter_measures_at_max(t: T) -> void:
	var o := _owner()
	var v := UnityUI.build(o, "DownloadDataLayer", {"reveal": false})
	var l := v.text("Text (TMP)", "Đang tải dữ liệu trò chơi lần đầu...")
	v.relayout("")
	var fitted := l.get_theme_font_size("font_size")
	# Only the rect height may limit the size: the same text in a very wide rect auto sizes the same.
	var r: Dictionary = l.get_meta("u_rect")
	r.size = Vector2(5000, (r.size as Vector2).y)
	UnityUI.apply_rect(l)
	UnityUI.fit_text(l)
	t.eq(fitted, l.get_theme_font_size("font_size"), "fitter rộng theo cỡ max, bề ngang không làm nhỏ chữ")
	o.free()


## Width of a label's text at its current size.
func _text_w(l: Label) -> float:
	var s := l.text.to_upper() if l.uppercase else l.text
	return l.get_theme_font("font").get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x


func test_button_text_fits_frame(t: T) -> void:
	var o := _owner()
	# Prefab auto size [18, 56] in a rect as wide as the pill: the text keeps off the round ends.
	var v := UnityUI.build(o, "PopupOkLayer", {"reveal": false})
	var ok: Control = v.node("Panel/Content/Button/Ok")
	var l := v.text("Panel/Content/Button/Ok/Out", "Herunterladen")
	var area := ThemeKit.button_text_area(ok.size)
	t.ok(_text_w(l) <= area.size.x + 0.5, "chữ auto size nằm trong vùng chữ của nút")
	t.ok(_text_w(l) > area.size.x * 0.8, "vẫn lấy cỡ lớn nhất vừa vùng")
	v.text("Panel/Content/Button/Ok/Out", "OK")
	t.eq(l.get_theme_font_size("font_size"), 56, "chữ ngắn giữ cỡ max")
	t.near(l.get_global_rect().get_center().x, ok.get_global_rect().get_center().x, 0.5, "lề hai bên bằng nhau, chữ vẫn giữa nút")
	# One line that overflows even at the smallest size goes onto lines between words; short text comes back to one.
	t.eq(l.autowrap_mode, TextServer.AUTOWRAP_OFF, "nhãn prefab một dòng")
	v.text("Panel/Content/Button/Ok/Out", "Obtenir le VIP pour 4,99 € maintenant")
	t.eq(l.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "không vừa ở cỡ nhỏ nhất thì xuống dòng")
	t.ok(l.get_theme_font_size("font_size") > 18, "xuống dòng để chữ to hơn cỡ nhỏ nhất")
	v.text("Panel/Content/Button/Ok/Out", "OK")
	t.eq(l.autowrap_mode, TextServer.AUTOWRAP_OFF, "chữ ngắn về một dòng")
	# The prefab does not auto size this one: on a button it still fits, between 18 and its own size.
	var acc := UnityUI.build(o, "SelectAccountLayer", {"reveal": false})
	var btn: Control = acc.node("Panel/AccountItem/Button")
	var sel := acc.text("Panel/AccountItem/Button/Text (TMP)", "Seleccionar")
	t.ok(sel.get_theme_font_size("font_size") < 46, "chữ dài co lại")
	t.ok(_text_w(sel) <= ThemeKit.button_text_area(btn.size).size.x + 0.5, "chữ cỡ cố định trên nút cũng co vừa")
	acc.text("Panel/AccountItem/Button/Text (TMP)", "OK")
	t.eq(sel.get_theme_font_size("font_size"), 46, "không vượt cỡ prefab")
	o.free()


func test_button_text_rect_and_cover(t: T) -> void:
	var o := _owner()
	# A price in the icon + price row: its rect is shorter than the text, as TMP allows; only the button bounds it.
	var hearts := UnityUI.build(o, "PopupMoreHeartLayer", {"reveal": false})
	var price := hearts.text("Panel/Content/GameObject/GoldBtn/Price/Text (TMP)", "100")
	t.eq(price.get_theme_font_size("font_size"), roundi(float((price.get_meta("u_txt") as Dictionary).fs)), "giá cạnh icon giữ cỡ prefab")
	# A button covering the layer ("tap to continue") holds content, not a caption: its texts keep their size.
	var how := UnityUI.build(o, "LeaderboardDescriptionLayer", {"reveal": false})
	var tap := how.text("Panel/LeaguesDesc/txtHeader", "Cách hoạt động của bảng xếp hạng tuần")
	t.eq(tap.get_theme_font_size("font_size"), roundi(float((tap.get_meta("u_txt") as Dictionary).fs)), "nút phủ màn không co chữ")
	t.ok(not tap.has_meta("u_inset"), "nút phủ màn không thêm lề")
	o.free()


func test_disabled_animator_and_display_layout(t: T) -> void:
	var o := _owner()
	var tut := UnityUI.build(o, "MainTutorialLayer", {"reveal": false})
	var a: Node = tut.animator("GameObject/Step1")
	t.ok(a != null, "Animator tắt sẵn vẫn được dựng")
	t.ok(not bool(a.get("enabled")), "chưa chạy khi prefab tắt")
	a.set("enabled", true)
	t.ok(bool(a.get("enabled")), "bật được")
	# PopupRatingLayer: OnDisplayLayout set_enabled(true) on the Star Animator.
	var rate := UnityUI.build(o, "PopupRatingLayer", {"reveal": false})
	t.ok(not bool(rate.animator("Panel/Star").get("enabled")), "Star tắt lúc dựng")
	await _tree().process_frame
	t.ok(bool(rate.animator("Panel/Star").get("enabled")), "OnDisplayLayout bật Star")
	o.free()


func test_anim_scale_button(t: T) -> void:
	var o := _owner()
	var v := UnityUI.build(o, "EndGameUILayer", {"reveal": false})
	var p := "Panel/WinPanel/BG/GameObject/FreeBtn"
	v.show(p)
	v.play(p)
	t.ok(v.node(p).has_meta("u_scale_loop"), "PlayAnim chạy vòng phóng")
	v.stop(p)
	t.ok(not v.node(p).has_meta("u_scale_loop"), "StopAnim huỷ vòng")
	t.eq(v.node(p).scale, Vector2.ONE, "về cỡ 1")
	o.free()


func test_input_field(t: T) -> void:
	var o := _owner()
	var v := UnityUI.build(o, "PopupEditNameLayer", {"reveal": false})
	var e := v.input(INPUT) as LineEdit
	t.ok(e != null, "LineEdit trong Text Area")
	t.eq(e.max_length, 14, "characterLimit")
	t.ok(not v.node(INPUT + "/Text Area/Text").visible, "nhãn Text ẩn")
	var ph: Control = v.node(INPUT + "/Text Area/Placeholder")
	v.input_text(INPUT, "abc")
	t.eq(e.text, "abc", "đặt chữ")
	t.ok(not ph.visible, "placeholder ẩn khi có chữ")
	v.input_text(INPUT, "")
	t.ok(ph.visible, "placeholder hiện khi trống")
	var te := UnityUI.input_field(v, v.node(INPUT), true)
	t.ok(te is TextEdit, "đổi sang nhiều dòng")
	t.eq(v.node(INPUT + "/Text Area").get_children().filter(func(c: Node) -> bool: return c.name == "Input").size(), 1,
		"chỉ còn một ô nhập")
	o.free()


## A Unity Mask clips raycasts to its rect: a masked child hanging past it (the pack shine) takes no taps outside.
func test_mask_clips_taps(t: T) -> void:
	var o := _owner()
	var v := UnityUI.build(o, "PopupChainOffer", {"reveal": false})
	var border := v.node("Panel/Content/ListPack/ChainOfferPack/BG (1)/BlurredBorder")
	t.ok(border.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED, "BlurredBorder là Mask")
	t.ok(border.clip_contents, "Mask cắt cả vùng nhận chạm")
	o.free()


func test_cutout(t: T) -> void:
	var o := _owner()
	var v := UnityUI.build(o, "LoadLevelProcessVer2", {"reveal": false})
	var icon := v.node("icon")
	var bg := v.node("icon/Background")
	t.eq(icon.clip_children, CanvasItem.CLIP_CHILDREN_DISABLED, "Mask không cắt con CutoutMaskUI")
	t.eq(icon.clip_contents, false, "con CutoutMaskUI vẽ ra ngoài khung Mask")
	t.eq(icon.self_modulate.a, 0.0, "showMaskGraphic tắt")
	var m := bg.material as ShaderMaterial
	t.ok(m != null and bool(m.get_shader_parameter("has_mask_tex")), "shader cắt theo sprite của Mask")
	var r: Dictionary = icon.get_meta("u_rect")
	r.size = Vector2(300, 300)
	UnityUI.apply_rect(icon)
	var mr: Vector4 = m.get_shader_parameter("mask_rect")
	t.near(mr.z, icon.size.x, 0.01, "lỗ theo cỡ icon")
	t.near(mr.x, -bg.position.x, 0.01, "lỗ theo vị trí icon")
	o.free()


func test_popup_dim_alpha(t: T) -> void:
	var o := _owner()
	# Prefab alphas: cc, fc, 7a, ff (a button), dim nested in a panel.
	for case in [["PopupOkLayer", "Bg"], ["PopupReviveLayer", "Bg"], ["PopupNextMonth", "Bg"],
			["PopupRemoveAds", "Continue"], ["LeaderboardWeeklyResultLayer", "WeekResultPanel/Dim"]]:
		var v := UnityUI.build(o, case[0], {"reveal": false})
		var img: Control = UnityUI.image_of(v.node(case[1]))
		t.near(img.color.a, ThemeKit.POPUP_DIM_ALPHA, 0.0001, "%s dim 85%%" % case[0])
	# Not a dim: the loading swirl (material) and the hard-level band (taller than the screen) keep theirs.
	var load := UnityUI.build(o, "LoadLevelProcess", {"reveal": false})
	t.near(UnityUI.image_of(load.node("BG")).color.a, 1.0, 0.0001, "nền loading giữ alpha")
	var warn := UnityUI.build(o, "WarningHardLevelLayer", {"reveal": false})
	t.near(UnityUI.image_of(warn.node("Panel/WarningExtreme/Dim")).color.a, float(0xa6) / 255.0, 0.001, "dải cảnh báo giữ alpha")
	o.free()
