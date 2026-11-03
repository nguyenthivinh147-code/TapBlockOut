extends Control
## Sao nhỏ 4 cánh lấp lánh trên nền Home: vị trí ngẫu nhiên theo seed cố định, mỗi sao nhấp nháy theo nhịp riêng.

const COUNT := 22
const SEED := 7
## Cạnh ngắn của màn chia cho số này ra bán kính sao lớn nhất.
const MAX_R_DIV := 42.0
const MIN_R_RATIO := 0.35
const PERIOD_MIN := 1.6
const PERIOD_MAX := 3.4
const INNER := 0.22

var color := Color(1, 1, 1, 0.9)
var glow := Color(0.96, 0.56, 0.72, 0.4)
## Mỗi sao: {"pos": Vector2 0..1, "r": 0..1, "period": giây, "phase": 0..1}.
var _stars: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in COUNT:
		_stars.append({
			"pos": Vector2(rng.randf(), rng.randf()),
			"r": rng.randf_range(MIN_R_RATIO, 1.0),
			"period": rng.randf_range(PERIOD_MIN, PERIOD_MAX),
			"phase": rng.randf(),
		})


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var max_r := minf(size.x, size.y) / MAX_R_DIV
	for st in _stars:
		var k := 0.5 - 0.5 * cos(TAU * (_t / float(st.period) + float(st.phase)))
		k = k * k
		if k < 0.02:
			continue
		var r: float = max_r * float(st.r) * (0.55 + 0.45 * k)
		var c: Vector2 = (st.pos as Vector2) * size
		draw_circle(c, r * 0.6, Color(glow, glow.a * k * 0.5))
		draw_circle(c, r * 0.35, Color(glow, glow.a * k))
		draw_colored_polygon(_star(c, r), Color(color, color.a * k))


## Sao 4 cánh: đỉnh dài theo trục, đỉnh ngắn ở góc chéo.
func _star(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * INNER))
	return pts
