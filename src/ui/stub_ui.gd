extends Control
## Nền cho màn đã dựng UI theo wireframe nhưng chưa nối logic. Không đụng Game, không tự mua, không tự xem quảng cáo.
## setup({view}): view là dữ liệu hiển thị; không truyền thì dùng _sample(). Khi nối logic chỉ cần truyền view thật.
## Nút chỉ phát closed({"action": <tên>}); X phát {"action": "close"}. Màn đè toàn màn hình chạm là đóng ({"action": "tap"}).

signal closed(result: Variant)

const ThemeKit := preload("res://src/ui/theme_kit.gd")
const PopupKit := preload("res://src/ui/popup_kit.gd")
const UiAtlas := preload("res://src/ui/ui_atlas.gd")
const SampleData := preload("res://src/ui/sample_data.gd")

var view: Dictionary = {}
var kit: Dictionary = {}
## Screens built from a color-cube-match-puzzle prefab (unity_ui.gd) keep their view here.
var ui: RefCounted = null

var _built: bool = false


func setup(args: Dictionary = {}) -> void:
	if _built:
		return
	_built = true
	view = args.get("view", _sample())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _ready() -> void:
	# Main gọi setup(args) ngay sau add_child; chỉ tự dựng khi không ai gọi.
	setup.call_deferred()


func _sample() -> Dictionary:
	return {}


func _title() -> String:
	return ""


## Tuỳ chọn cho PopupKit.make.
func _opts() -> Dictionary:
	return {}


## true: nền gradient thay vì nền mờ (lớp PopupFullScreen trong wireframe).
func _full_screen() -> bool:
	return false


func _fill(_box: VBoxContainer) -> void:
	pass


## Mặc định dựng popup; màn không có khung thì ghi đè hàm này.
func _build() -> void:
	if _full_screen():
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(ThemeKit.make_background())
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		kit = PopupKit.make_card(_title(), _act.bind("close"), _opts())
		center.add_child(kit.card)
	else:
		kit = PopupKit.make(self, _title(), _act.bind("close"), _opts())
	_fill(kit.box)
	PopupKit.show_in(kit)


## Màn đè: nền mờ và cột nội dung giữa màn; chạm đâu cũng đóng.
func _overlay(dim_color: Color = ThemeKit.SCRIM) -> VBoxContainer:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = dim_color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	return _center_column()


func _center_column() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	return col


func _gui_input(event: InputEvent) -> void:
	if kit.is_empty() and ui == null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_act("tap")


func _act(action: String) -> void:
	Sfx.play("button")
	closed.emit({"action": action})


## Like _act for prefab buttons, which play their own click sound.
func _send(action: String) -> void:
	closed.emit({"action": action})


func _say(content: String, size: int = ThemeKit.FS_SMALL + 4, color: Color = ThemeKit.INK) -> Label:
	return PopupKit.text(content, size, color)


## Chữ trắng viền tối, dùng trên nền màu hoặc nền mờ.
func _shout(content: String, size: int = ThemeKit.FS_BODY, color: Color = ThemeKit.TEXT) -> Label:
	var l := ThemeKit.make_label(content, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 620
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(content: String, kind: String, action: String, icon_name: String = "") -> Button:
	var b := ThemeKit.make_button(content, kind)
	if icon_name != "":
		ThemeKit.set_button_icon(b, icon_name)
	b.pressed.connect(_act.bind(action))
	return b


## Hàng check: dấu tích + chữ, trên nền well.
func _check_row(content: String) -> Control:
	var well := ThemeKit.make_well()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	well.add_child(h)
	h.add_child(ThemeKit.make_icon("ui_check", 44))
	var l := ThemeKit.ink_label(content, ThemeKit.FS_SMALL + 2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	return well


## Hàng số thứ tự + chữ (How it works, Instruction).
func _step_row(n: int, content: String) -> Control:
	var well := ThemeKit.make_well()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	well.add_child(h)
	var num := ThemeKit.gold_label(str(n), ThemeKit.FS_BUTTON)
	num.custom_minimum_size.x = 44
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(num)
	var l := ThemeKit.ink_label(content, ThemeKit.FS_SMALL + 2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	return well


func _gold_tile(amount: int, px: float = 80.0) -> Control:
	return PopupKit.reward_tile(ThemeKit.icon("ui_gold"), tr("shop_gold_pack") % amount, px)


func _hint_tile(amount: int, px: float = 80.0) -> Control:
	return PopupKit.reward_tile(ThemeKit.icon("booster_hint"), "%s %s" % [tr("booster_hint"), tr("booster_count") % amount], px)


func _bar(value: float, fill: Color = Color("3CD020")) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 28)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = value
	ThemeKit.style_bar(bar, fill)
	return bar
