extends Control
## Khung bàn theo concept kẹo: bốn thanh capsule là bốn cổng, bốn ống góc hồng đỏ nằm dưới đầu thanh.
## BoardView gọi layout(board, cell) khi xếp lại, set_gate() và set_flash() khi cổng đổi.
## Mọi số hình học tính theo ô, đo từ `art/concepts/ref_board_size.png`; màu lấy từ `art/concepts/concept_candy_board_v5_stripe.png`.

const BAR_SHADER := preload("res://src/ui/frame_bar.gdshader")
const CORNER_SHADER := preload("res://src/ui/frame_corner.gdshader")

const SIDES := ["up", "left", "right", "down"]
## axis: từ mép bàn tới đường giữa thanh; thick: bề dày; inset: từ mép ngoài khung tới đầu thanh.
const BARS := {
	"up": {"axis": 0.305, "thick": 0.55, "inset": 0.78},
	"left": {"axis": 0.46, "thick": 0.58, "inset": 0.77},
	"right": {"axis": 0.47, "thick": 0.60, "inset": 0.77},
	"down": {"axis": 0.32, "thick": 0.58, "inset": 0.78},
}
## Mũi tên: x ngang thân, y dọc theo hướng; shift lệch dọc theo thanh (thanh dọc đặt mũi tên cao hơn tâm).
const ARROWS := {
	"up": {"dir": Vector2(0, -1), "size": Vector2(0.45, 0.34), "shift": Vector2(0.0, -0.03)},
	"left": {"dir": Vector2(-1, 0), "size": Vector2(0.50, 0.35), "shift": Vector2(-0.03, -0.21)},
	"right": {"dir": Vector2(1, 0), "size": Vector2(0.50, 0.35), "shift": Vector2(0.03, -0.21)},
	"down": {"dir": Vector2(0, 1), "size": Vector2(0.45, 0.34), "shift": Vector2(0.0, 0.02)},
}
const TUBE_R := 0.49  # bán kính tới đường giữa ống góc
const TUBE_W := 0.44  # bề rộng ống góc
const TUBE_RUN := 0.36  # phần ống thẳng chui dưới đầu thanh
const PAD := 0.35  # lề vùng vẽ, chứa bóng đổ
## Vệt sáng trên ống ở mỗi góc, ánh sáng từ trên hơi lệch trái. peak: vị trí trên mặt cắt (-1 trong, 1 ngoài);
## gloss, gloss_w: độ đậm và nửa bề rộng; gloss_at, gloss_arc: tâm và độ dài theo góc (radian từ phương ngang);
## spread: mặt cắt tối dần chậm hay nhanh quanh chỗ sáng.
const CORNERS := {
	"tl": {"out": Vector2(-1, -1), "peak": 0.55, "gloss": 0.85, "gloss_w": 0.15, "gloss_at": 0.8, "gloss_arc": 0.7, "spread": 1.3},
	"tr": {"out": Vector2(1, -1), "peak": 0.25, "gloss": 0.7, "gloss_w": 0.13, "gloss_at": 1.17, "gloss_arc": 0.24, "spread": 1.2},
	"bl": {"out": Vector2(-1, 1), "peak": -0.25, "gloss": 0.72, "gloss_w": 0.17, "gloss_at": 0.96, "gloss_arc": 0.36, "spread": 1.0},
	"br": {"out": Vector2(1, 1), "peak": -0.42, "gloss": 0.72, "gloss_w": 0.16, "gloss_at": 1.0, "gloss_arc": 0.34, "spread": 1.0},
}
## Mặt cắt thanh: [vị trí 0..1 từ mép trên hoặc mép trái, màu], lấy trung vị dọc theo thanh trong ảnh.
const BAR_RAMPS := {
	"up": [[0.0, "E89A1E"], [0.03, "ECA41C"], [0.065, "FEDB41"], [0.11, "FEF079"], [0.15, "FDFDDB"], [0.2, "FDFCA9"], [0.24, "FEF884"], [0.28, "FEF470"], [0.37, "FDE94E"], [0.46, "FCDC35"], [0.54, "FCD026"], [0.63, "FAC31D"], [0.67, "F9BA1A"], [0.72, "F7AB14"], [0.76, "F1980C"], [0.8, "EB8A07"], [0.85, "E98207"], [0.89, "EB860D"], [0.93, "F29012"], [1.0, "C9701F"]],
	"left": [[0.0, "36A014"], [0.02, "39A615"], [0.06, "47B713"], [0.1, "4CC014"], [0.14, "5BCD17"], [0.18, "6DDD1D"], [0.22, "78E822"], [0.27, "82F028"], [0.31, "8AF52D"], [0.35, "8FF830"], [0.43, "93FA36"], [0.51, "99FB3D"], [0.59, "9FFC46"], [0.67, "A5FC4F"], [0.76, "A8FB52"], [0.8, "B6FC66"], [0.84, "A4F74F"], [0.88, "7BE225"], [0.92, "61CB1C"], [0.96, "43A916"], [1.0, "3A9A1C"]],
	"right": [[0.0, "0458CC"], [0.02, "0462D9"], [0.06, "0178F0"], [0.1, "0186F4"], [0.14, "059BFB"], [0.18, "43C5FD"], [0.22, "63D8FD"], [0.26, "56D1FD"], [0.34, "54D4FD"], [0.42, "50D1FD"], [0.5, "47CEFD"], [0.58, "3DC9FD"], [0.66, "2FC2FE"], [0.7, "28BDFE"], [0.74, "1FB5FD"], [0.78, "12A5FB"], [0.82, "038EF6"], [0.86, "007EF1"], [0.9, "0075EE"], [0.94, "036DE6"], [1.0, "0A62CC"]],
	"down": [[0.0, "B025AE"], [0.02, "C32BB5"], [0.06, "F468EA"], [0.1, "F68AE8"], [0.14, "FDD5F7"], [0.18, "FDBCF4"], [0.22, "FC96ED"], [0.27, "FA82E8"], [0.35, "F667DF"], [0.43, "F253D9"], [0.51, "ED43D3"], [0.59, "E636CD"], [0.63, "E12EC8"], [0.67, "D726C1"], [0.71, "C91BB6"], [0.76, "B811A8"], [0.8, "AF0CA0"], [0.84, "AA099C"], [0.88, "AD0B9D"], [0.92, "B50FA4"], [0.96, "8F0D7D"], [1.0, "8A0C78"]],
}
const END_COLORS := {"up": Color("EFA512"), "left": Color("33BD11"), "right": Color("0279EE"), "down": Color("C81CBA")}

const HIT_TIME := 0.45  # giây, sóng sáng và nảy của thanh khi bị va
const HIT_BUMP := 0.1  # thanh bật ra ngoài chừng này ô
const HIT_POP := 0.42  # mũi tên phồng thêm chừng này
## Đoạn thanh khối phủ lên nổi thành lăng trụ lục giác, lăn theo hướng khối đi rồi chậm dần và nhập lại vào thanh.
const SPIN_FACE := PI / 3.0  # góc một mặt lục giác
const SPIN_TIME := 0.6  # giây chậm dần tới khi dừng, sau khi khối đã qua hết
const SPIN_EXIT := 3  # khối thoát qua: lăn chừng này mặt trong lúc chậm dần
const SPIN_BUMP := 1  # khối dội vào cổng đóng
const SPIN_RISE := 0.05  # giây để đoạn nổi lên
const SPIN_SINK := 0.7  # từ phần này của SPIN_TIME đoạn chìm dần vào thanh

static var _ramp_cache: Dictionary = {}

var _bars: Dictionary = {}  # cạnh -> ColorRect
var _corners: Dictionary = {}  # góc -> ColorRect
var _open: Dictionary = {}  # cạnh -> 0 (đóng) .. 1 (mở)
var _bar_home: Dictionary = {}  # cạnh -> vị trí khi chưa bị va
var _hit_tws: Dictionary = {}  # cạnh -> Tween
var _spin: Dictionary = {}  # cạnh -> góc quay hiện tại của đoạn bị va
var _cell: float = 64.0


func _init() -> void:
	name = "Frame"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in CORNERS:
		_corners[key] = _make_part(CORNER_SHADER)
	for side in SIDES:
		_bars[side] = _make_part(BAR_SHADER)
		_open[side] = 1.0


func _make_part(shader: Shader) -> ColorRect:
	var part := ColorRect.new()
	part.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = shader
	part.material = m
	add_child(part)
	return part


## Khung chiếm thêm bao nhiêu ô mỗi phía quanh bàn (lấy phía lớn hơn của mỗi trục để bàn vẫn ở giữa).
static func margin() -> Vector2:
	return Vector2(maxf(_outer("left"), _outer("right")), maxf(_outer("up"), _outer("down")))


static func _outer(side: String) -> float:
	return float(BARS[side]["axis"]) + float(BARS[side]["thick"]) * 0.5


## Khoảng trống (ô) từ mép bàn tới mặt trong của thanh: khối bị cổng đóng chặn trượt thêm chừng này.
static func gap(side: String) -> float:
	return float(BARS[side]["axis"]) - float(BARS[side]["thick"]) * 0.5


## Mặt nền bàn: tới đường giữa các thanh, bo theo ống góc.
static func panel_rect(board: Rect2, cell: float) -> Rect2:
	return board.grow_individual(float(BARS["left"]["axis"]) * cell, float(BARS["up"]["axis"]) * cell, float(BARS["right"]["axis"]) * cell, float(BARS["down"]["axis"]) * cell)


## Mặt trong của cả bốn thanh: nơi khối chạm cổng.
static func inner_rect(board: Rect2, cell: float) -> Rect2:
	return board.grow_individual(gap("left") * cell, gap("up") * cell, gap("right") * cell, gap("down") * cell)


## Trọn khung, tính cả bề dày thanh.
static func outer_rect(board: Rect2, cell: float) -> Rect2:
	return board.grow_individual(_outer("left") * cell, _outer("up") * cell, _outer("right") * cell, _outer("down") * cell)


static func bar_rect(side: String, board: Rect2, cell: float) -> Rect2:
	var outer := outer_rect(board, cell)
	var b: Dictionary = BARS[side]
	var t: float = float(b["thick"]) * cell
	var inset: float = float(b["inset"]) * cell
	var a: float = float(b["axis"]) * cell
	match side:
		"up":
			return Rect2(outer.position.x + inset, board.position.y - a - t * 0.5, outer.size.x - 2.0 * inset, t)
		"down":
			return Rect2(outer.position.x + inset, board.end.y + a - t * 0.5, outer.size.x - 2.0 * inset, t)
		"left":
			return Rect2(board.position.x - a - t * 0.5, outer.position.y + inset, t, outer.size.y - 2.0 * inset)
		_:
			return Rect2(board.end.x + a - t * 0.5, outer.position.y + inset, t, outer.size.y - 2.0 * inset)


## Tâm cung của bốn ống góc.
static func corner_centers(board: Rect2, cell: float) -> Dictionary:
	var p := panel_rect(board, cell)
	var r := TUBE_R * cell
	return {"tl": p.position + Vector2(r, r), "tr": Vector2(p.end.x - r, p.position.y + r),
		"bl": Vector2(p.position.x + r, p.end.y - r), "br": p.end - Vector2(r, r)}


## Mặt cắt của một cạnh thành texture, cache theo cạnh.
static func ramp_texture(side: String) -> Texture2D:
	if not _ramp_cache.has(side):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array()
		g.colors = PackedColorArray()
		for stop: Array in BAR_RAMPS[side]:
			g.add_point(float(stop[0]), Color(str(stop[1])))
		var tex := GradientTexture1D.new()
		tex.width = 128
		tex.gradient = g
		_ramp_cache[side] = tex
	return _ramp_cache[side]


## Xếp lại toàn bộ theo bàn và cỡ ô hiện tại. `board` tính theo toạ độ cục bộ của khung.
func layout(board: Rect2, cell: float) -> void:
	_cell = cell
	var pad := PAD * cell
	for side in SIDES:
		var r := bar_rect(side, board, cell)
		var part: ColorRect = _bars[side]
		part.position = r.position - Vector2(pad, pad)
		part.size = r.size + Vector2(pad, pad) * 2.0
		_bar_home[side] = part.position
		var m: ShaderMaterial = part.material
		var arrow: Dictionary = ARROWS[side]
		m.set_shader_parameter("ramp", ramp_texture(side))
		m.set_shader_parameter("end_col", END_COLORS[side])
		m.set_shader_parameter("quad_px", part.size)
		m.set_shader_parameter("bar_px", r.size)
		m.set_shader_parameter("vertical", side == "left" or side == "right")
		m.set_shader_parameter("arrow_dir", arrow["dir"])
		m.set_shader_parameter("arrow_at", (arrow["shift"] as Vector2) * cell)
		m.set_shader_parameter("arrow_size", (arrow["size"] as Vector2) * cell)
		m.set_shader_parameter("cell_px", cell)
		m.set_shader_parameter("open", _open[side])
	var centers := corner_centers(board, cell)
	var tube_r := TUBE_R * cell
	var tube_hw := TUBE_W * 0.5 * cell
	var run := TUBE_RUN * cell
	var reach := tube_r + tube_hw + pad
	for key in CORNERS:
		var c: Dictionary = CORNERS[key]
		var out: Vector2 = c["out"]
		var part: ColorRect = _corners[key]
		var a: Vector2 = centers[key] + out * reach
		var b: Vector2 = centers[key] - out * run
		part.position = Vector2(minf(a.x, b.x), minf(a.y, b.y))
		part.size = Vector2(reach + run, reach + run)
		var m: ShaderMaterial = part.material
		m.set_shader_parameter("quad_px", part.size)
		m.set_shader_parameter("center_px", centers[key] - part.position)
		m.set_shader_parameter("quadrant", out)
		m.set_shader_parameter("tube_r", tube_r)
		m.set_shader_parameter("tube_hw", tube_hw)
		m.set_shader_parameter("peak", c["peak"])
		m.set_shader_parameter("gloss", c["gloss"])
		m.set_shader_parameter("gloss_w", c["gloss_w"])
		m.set_shader_parameter("gloss_at", c["gloss_at"])
		m.set_shader_parameter("gloss_arc", c["gloss_arc"])
		m.set_shader_parameter("spread", c["spread"])
		m.set_shader_parameter("cell_px", cell)


## Độ mở của cổng ở một cạnh: 0 đóng, 1 mở.
func set_gate(side: String, open: float) -> void:
	_open[side] = open
	(_bars[side].material as ShaderMaterial).set_shader_parameter("open", open)


## Cả bốn thanh nháy sáng khi cổng đổi trạng thái.
func set_flash(v: float) -> void:
	for side in SIDES:
		(_bars[side].material as ShaderMaterial).set_shader_parameter("flash", v)


## Khối đập vào thanh, phủ một đoạn dài `span` px có tâm ở `at` (toạ độ của khung): thanh bật ra rồi nảy về,
## sóng sáng chạy dọc thanh, mũi tên phồng lên, đoạn bị phủ lăn đều trong `hold` giây (khối còn đang qua thanh)
## rồi chậm dần qua `turns` mặt.
func hit(side: String, at: Vector2, span: float, strength: float = 1.0, turns: int = SPIN_EXIT, hold: float = 0.0) -> void:
	var part: ColorRect = _bars[side]
	var m: ShaderMaterial = part.material
	var center: Vector2 = _bar_home[side] + part.size * 0.5
	var along := at.y - center.y if side == "left" or side == "right" else at.x - center.x
	m.set_shader_parameter("hit_at", along)
	m.set_shader_parameter("seg_at", along)
	m.set_shader_parameter("seg_half", span * 0.5)
	var old: Tween = _hit_tws.get(side, null)
	if old != null and old.is_valid():
		old.kill()
	var tw := create_tween().set_parallel(true)
	_hit_tws[side] = tw
	tw.tween_method(_apply_hit.bind(side, strength), 0.0, 1.0, HIT_TIME)
	# mặt trên lăn cùng hướng khối đi; tiếp từ góc đang dở nếu thanh đang lăn
	var out: Vector2 = ARROWS[side]["dir"]
	var angle := -(out.x + out.y) * float(turns) * SPIN_FACE
	tw.tween_method(_apply_spin.bind(side, _spin.get(side, 0.0), angle, hold), 0.0, hold + SPIN_TIME, hold + SPIN_TIME)


## `s` tính bằng giây. Lăn đều trong `hold`, rồi chậm dần (cubic) thêm `angle`, nối liền vận tốc.
func _apply_spin(s: float, side: String, from: float, angle: float, hold: float) -> void:
	var m: ShaderMaterial = (_bars[side] as ColorRect).material
	var speed := 3.0 * angle / SPIN_TIME
	var u := clampf((s - hold) / SPIN_TIME, 0.0, 1.0)
	_spin[side] = from + speed * minf(s, hold) + angle * (1.0 - pow(1.0 - u, 3.0))
	m.set_shader_parameter("spin", _spin[side])
	m.set_shader_parameter("seg", smoothstep(0.0, SPIN_RISE, s) * (1.0 - smoothstep(SPIN_SINK, 1.0, u)))


func _apply_hit(t: float, side: String, strength: float) -> void:
	var part: ColorRect = _bars[side]
	var m: ShaderMaterial = part.material
	m.set_shader_parameter("hit_t", t)
	m.set_shader_parameter("pop", HIT_POP * strength * sin(PI * minf(t * 2.2, 1.0)))
	var out: Vector2 = ARROWS[side]["dir"]
	var bump := HIT_BUMP * strength * _cell * exp(-5.0 * t) * cos(t * TAU * 2.0) * (1.0 - t)
	part.position = _bar_home[side] + out * bump
