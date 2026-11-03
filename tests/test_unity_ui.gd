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


func test_cutout(t: T) -> void:
	var o := _owner()
	var v := UnityUI.build(o, "LoadLevelProcessVer2", {"reveal": false})
	var icon := v.node("icon")
	var bg := v.node("icon/Background")
	t.eq(icon.clip_children, CanvasItem.CLIP_CHILDREN_DISABLED, "Mask không cắt con CutoutMaskUI")
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
