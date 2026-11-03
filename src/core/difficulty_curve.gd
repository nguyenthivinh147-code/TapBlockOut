extends RefCounted
## Đường cong độ khó L1-100, lấy từ difficulty_curve_levels_1-100.json (PixelFlow): điểm trung bình trượt 5 level
## nhân 100, và danh sách level Hard / VeryHard. Thuần dữ liệu: bộ sinh đổi điểm thành số khối, không đọc Config.

const MIN_BLOCKS := 2
const MAX_BLOCKS := 30
## Hard +2 khối, VeryHard +3 khối so với đường nền (tối đa MAX_BLOCKS).
const HARD_BONUS := 2
const VERY_HARD_BONUS := 3
## Số màu (hướng) L1-4; từ L5 là đủ 4.
const EARLY_COLORS := [2, 3, 3, 4]
## Từ level SHAPED_FROM: số khối nhân BOOST (trần BOOST_MAX), khối xếp theo hình trong `motifs.gd`, và bộ sinh ưu
## tiên khối bị chặn lúc đầu mạnh hơn (BLOCKED_POWER, level Hard/VeryHard dùng BLOCKED_POWER_HARD; trước đó là 1 và 2).
const SHAPED_FROM := 14
const BOOST := 1.3
const BOOST_MAX := 40
const BLOCKED_POWER := 2
const BLOCKED_POWER_HARD := 3

## Điểm độ khó đã làm mượt (x100), L1 ở chỉ số 0.
const SCORE := [
	43, 52, 69, 94, 118, 145, 173, 195, 209, 199,
	213, 209, 220, 244, 296, 297, 339, 380, 390, 388,
	374, 369, 329, 351, 329, 391, 439, 419, 377, 423,
	394, 317, 312, 365, 323, 339, 361, 370, 330, 373,
	397, 476, 548, 521, 496, 422, 370, 344, 338, 334,
	389, 414, 391, 419, 441, 411, 407, 410, 457, 418,
	499, 504, 529, 507, 539, 498, 500, 437, 403, 419,
	428, 393, 492, 479, 485, 448, 504, 487, 546, 572,
	559, 517, 479, 516, 471, 471, 503, 478, 413, 403,
	441, 369, 440, 445, 458, 498, 569, 516, 549, 577,
]
const HARD := [24, 28, 33, 38, 44, 53, 59, 63, 68, 73, 79, 89, 93, 98]
const VERY_HARD := [29, 36, 45, 49, 54, 64, 69, 75, 82, 84, 95, 99]


## Level cuối có trong đường cong.
static func last_level() -> int:
	return SCORE.size()


## 0..10 (điểm đã làm mượt). id ngoài 1..100 kẹp vào đầu mút.
static func score(id: int) -> float:
	return float(SCORE[clampi(id, 1, SCORE.size()) - 1]) / 100.0


## Level Hard hoặc VeryHard. Ngoài L1-100 (Daily Challenge, level sinh thêm) thì cứ 4 level một lần.
static func is_hard(id: int) -> bool:
	if id > SCORE.size():
		return id % 4 == 0
	return id in HARD or id in VERY_HARD


static func is_very_hard(id: int) -> bool:
	return id in VERY_HARD


## Số màu cho phép ở level này.
static func color_count(id: int) -> int:
	if id <= EARLY_COLORS.size():
		return EARLY_COLORS[maxi(id, 1) - 1]
	return 4


## Số khối mục tiêu: điểm chuẩn hoá theo min-max trên 100 level, nội suy MIN_BLOCKS..MAX_BLOCKS; từ SHAPED_FROM nhân BOOST.
static func block_count(id: int) -> int:
	var lo: float = SCORE.min() / 100.0
	var hi: float = SCORE.max() / 100.0
	var norm := (score(id) - lo) / (hi - lo)
	var n := MIN_BLOCKS + roundi(float(MAX_BLOCKS - MIN_BLOCKS) * norm)
	if id in VERY_HARD:
		n += VERY_HARD_BONUS
	elif is_hard(id):
		n += HARD_BONUS
	n = clampi(n, MIN_BLOCKS, MAX_BLOCKS)
	if id >= SHAPED_FROM:
		n = mini(BOOST_MAX, roundi(n * BOOST))
	return n


## Số mũ trọng số "khối bị chặn lúc đầu" khi bộ sinh gán hướng: càng lớn càng ít khối thoát được ngay.
static func blocked_power(id: int) -> int:
	if id >= SHAPED_FROM:
		return BLOCKED_POWER_HARD if is_hard(id) else BLOCKED_POWER
	return 2 if is_hard(id) else 1
