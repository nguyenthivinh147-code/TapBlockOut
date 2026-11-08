extends RefCounted
## Difficulty curve L1-500 (design.md section 4): target block count and target clear rounds of every level, and the
## Hard / VeryHard lists. REF_* were measured on L1-500 of the reference game Tap Block Out 2.2.1: blocks in the level,
## and clear rounds (each round taps every block whose way is open, see Solver.clear_rounds). Hard and VeryHard (the
## reference's Super Hard) keep the reference levels, except L70 (fog teaching level) which moved to L71 together with
## its numbers. The generator clamps the block count to what the hand-drawn shapes hold (`block_count`) and scales the
## rounds with it (`wave_count`). Pure data: does not read Config.

## L1-4 are hand-made (tools/gen_levels.gd, table EARLY).
const EARLY_BLOCKS := [4, 6, 8, 10]
## From MOTIF_FROM blocks are cut from hand-drawn shapes of 36-182 cells at 2.5-3.4 cells per block: at least
## MOTIF_MIN_BLOCKS blocks so that a dozen shapes fit, at most BLOCK_CAP so that 16 shapes still fit (6-8 above it).
const MOTIF_MIN_BLOCKS := 12
const BLOCK_CAP := 60
## A Hard / VeryHard level is a peak of the curve: blocks and rounds at least PEAK_HARD / PEAK_VERY_HARD times the
## median of the normal levels within PEAK_SPAN levels on each side (after clamping, still at most the caps).
const PEAK_HARD := 1.15
const PEAK_VERY_HARD := 1.3
const PEAK_SPAN := 3
## Rounds at most WAVE_SHARE_MAX per block: deeper chains rarely fit the 12x17 shapes (the reference goes past 0.7).
const WAVE_SHARE_MAX := 0.55
## Points of the curve (`score`): blocks over BLOCK_CAP and rounds over SCORE_ROUNDS, half each, times 10.
const SCORE_ROUNDS := 40
## Colors (directions) for L1-4; 4 from L5.
const EARLY_COLORS := [2, 3, 3, 4]
## From SHAPED_FROM the generator favors blocks that start blocked more strongly (BLOCKED_POWER, Hard / VeryHard
## BLOCKED_POWER_HARD; 1 and 2 before).
const SHAPED_FROM := 14
const BLOCKED_POWER := 2
const BLOCKED_POWER_HARD := 3
## From MOTIF_FROM blocks are laid out as hand-drawn shapes (`motifs.gd`); before that (L1-4, hand-made) random shapes.
const MOTIF_FROM := 5

## Reference block count per level, L1 at index 0.
const REF_BLOCKS := [
	5, 4, 4, 4, 4, 7, 6, 7, 8, 10, 14, 15, 13, 13, 19, 15, 23, 15, 17, 17,
	15, 17, 27, 16, 16, 43, 19, 16, 36, 21, 35, 16, 24, 29, 24, 25, 29, 56, 21, 20,
	50, 35, 49, 30, 23, 42, 35, 29, 56, 32, 49, 29, 28, 70, 40, 39, 35, 34, 61, 70,
	30, 35, 34, 84, 37, 39, 37, 82, 31, 40, 43, 40, 77, 31, 51, 34, 34, 41, 67, 40,
	51, 36, 81, 31, 47, 73, 27, 40, 30, 30, 46, 40, 33, 58, 34, 37, 41, 31, 87, 30,
	31, 42, 39, 38, 68, 37, 38, 49, 64, 41, 64, 32, 37, 89, 39, 66, 60, 32, 51, 89,
	35, 76, 34, 62, 55, 51, 91, 36, 51, 37, 37, 43, 51, 33, 65, 37, 42, 84, 39, 67,
	46, 32, 47, 55, 37, 62, 39, 32, 50, 76, 40, 46, 46, 35, 65, 49, 35, 61, 43, 87,
	49, 50, 56, 47, 45, 75, 48, 91, 50, 36, 67, 56, 43, 56, 41, 32, 72, 78, 48, 59,
	48, 34, 60, 54, 56, 89, 59, 46, 83, 50, 50, 64, 49, 53, 61, 63, 104, 38, 44, 52,
	73, 45, 45, 76, 39, 57, 57, 42, 43, 75, 70, 36, 85, 39, 68, 53, 45, 35, 64, 51,
	82, 31, 55, 52, 60, 34, 43, 83, 60, 37, 67, 38, 64, 56, 39, 47, 78, 44, 50, 62,
	53, 46, 48, 79, 34, 38, 43, 43, 37, 84, 54, 46, 49, 68, 48, 80, 35, 45, 44, 52,
	62, 54, 42, 57, 77, 61, 63, 40, 39, 53, 39, 96, 39, 59, 32, 53, 64, 31, 42, 75,
	43, 42, 49, 40, 39, 84, 40, 51, 44, 59, 57, 54, 37, 70, 37, 69, 35, 32, 51, 86,
	37, 54, 51, 52, 49, 38, 95, 25, 69, 42, 31, 68, 81, 36, 37, 47, 37, 55, 73, 44,
	81, 52, 56, 48, 70, 31, 40, 86, 48, 32, 61, 39, 57, 40, 39, 98, 45, 54, 52, 46,
	56, 65, 41, 80, 39, 71, 43, 68, 44, 89, 38, 41, 58, 42, 39, 76, 36, 76, 41, 57,
	68, 40, 45, 92, 43, 61, 39, 61, 48, 78, 77, 55, 79, 40, 40, 65, 104, 36, 61, 39,
	39, 61, 37, 83, 44, 59, 63, 36, 82, 55, 53, 43, 45, 73, 58, 35, 83, 40, 51, 112,
	55, 36, 58, 50, 76, 65, 35, 36, 74, 39, 61, 48, 37, 94, 44, 56, 76, 35, 52, 58,
	43, 87, 42, 66, 52, 46, 32, 37, 48, 66, 45, 42, 67, 56, 39, 42, 81, 36, 54, 84,
	46, 67, 54, 57, 47, 65, 81, 53, 58, 74, 57, 68, 63, 70, 42, 67, 59, 52, 54, 45,
	72, 54, 52, 55, 44, 49, 39, 42, 50, 44, 43, 62, 56, 44, 51, 36, 48, 56, 45, 72,
	41, 48, 60, 51, 46, 60, 40, 46, 58, 71, 46, 52, 40, 41, 48, 40, 66, 51, 35, 55,
]
## Reference clear rounds per level.
const REF_WAVES := [
	2, 3, 2, 2, 3, 4, 3, 4, 3, 6, 3, 8, 8, 4, 7, 9, 9, 6, 10, 9,
	4, 6, 16, 3, 7, 21, 7, 3, 21, 10, 9, 5, 12, 14, 4, 14, 12, 22, 6, 8,
	20, 11, 10, 10, 7, 20, 5, 12, 27, 15, 27, 20, 10, 35, 18, 19, 16, 18, 29, 31,
	14, 21, 11, 40, 20, 6, 17, 39, 12, 17, 19, 20, 47, 14, 24, 15, 11, 21, 29, 13,
	29, 15, 49, 12, 14, 36, 10, 21, 12, 9, 21, 26, 15, 22, 15, 13, 18, 13, 40, 12,
	9, 21, 20, 20, 34, 20, 18, 30, 32, 22, 24, 21, 14, 36, 22, 37, 38, 19, 21, 52,
	20, 35, 14, 29, 30, 28, 29, 21, 21, 19, 22, 18, 29, 11, 37, 17, 25, 45, 22, 35,
	26, 19, 29, 26, 27, 29, 19, 14, 31, 32, 26, 19, 34, 23, 42, 14, 13, 28, 29, 49,
	12, 26, 31, 25, 30, 42, 13, 48, 29, 20, 38, 11, 25, 30, 23, 14, 42, 42, 12, 35,
	31, 18, 34, 16, 14, 45, 30, 30, 50, 18, 35, 31, 26, 15, 34, 35, 52, 24, 29, 19,
	34, 25, 27, 47, 21, 34, 27, 13, 14, 29, 34, 15, 47, 14, 35, 18, 14, 16, 35, 24,
	47, 11, 30, 14, 32, 23, 30, 36, 35, 8, 35, 16, 41, 35, 11, 27, 35, 11, 12, 33,
	27, 27, 21, 52, 17, 14, 29, 18, 15, 48, 20, 20, 21, 36, 13, 44, 13, 28, 22, 17,
	22, 28, 10, 35, 37, 17, 44, 19, 19, 27, 12, 52, 20, 28, 11, 31, 43, 11, 18, 39,
	15, 21, 28, 17, 21, 46, 10, 15, 27, 28, 32, 27, 14, 35, 12, 48, 20, 11, 25, 49,
	11, 33, 28, 14, 24, 23, 51, 11, 46, 15, 8, 41, 53, 15, 14, 27, 23, 29, 28, 11,
	48, 14, 26, 17, 37, 16, 6, 47, 11, 16, 31, 15, 36, 12, 20, 49, 14, 27, 23, 11,
	37, 40, 16, 44, 10, 38, 13, 39, 27, 50, 11, 13, 32, 14, 9, 49, 10, 42, 14, 35,
	34, 10, 13, 55, 18, 17, 11, 36, 16, 47, 45, 16, 46, 15, 23, 40, 42, 9, 37, 27,
	11, 35, 16, 50, 17, 19, 32, 13, 37, 15, 30, 25, 10, 40, 30, 7, 46, 9, 34, 55,
	21, 11, 30, 19, 45, 47, 20, 11, 43, 15, 32, 12, 16, 65, 13, 24, 49, 15, 25, 45,
	19, 58, 14, 42, 16, 31, 19, 17, 31, 42, 12, 17, 44, 35, 13, 15, 54, 14, 16, 62,
	15, 46, 15, 29, 21, 30, 40, 21, 21, 28, 13, 29, 14, 48, 16, 36, 29, 20, 30, 24,
	53, 15, 29, 30, 25, 28, 9, 29, 28, 20, 23, 36, 15, 14, 27, 20, 24, 19, 12, 37,
	16, 14, 28, 25, 15, 31, 19, 13, 35, 46, 14, 29, 16, 14, 38, 16, 39, 16, 11, 29,
]
const HARD := [
	23, 26, 29, 34, 37, 41, 43, 49, 51, 56, 59, 67, 71, 75, 76, 78, 81, 88, 91, 92,
	97, 102, 103, 108, 111, 116, 117, 119, 122, 124, 129, 132, 133, 138, 143, 144, 149, 150, 152, 158,
	163, 168, 169, 174, 177, 180, 186, 192, 193, 195, 199, 201, 206, 207, 210, 211, 215, 216, 219, 223,
	225, 231, 233, 234, 240, 242, 247, 253, 254, 258, 261, 264, 267, 270, 274, 276, 277, 283, 289, 290,
	292, 296, 299, 302, 305, 309, 312, 316, 318, 319, 323, 325, 331, 333, 338, 341, 342, 346, 348, 353,
	356, 360, 361, 368, 370, 371, 373, 376, 379, 382, 387, 391, 394, 395, 399, 403, 405, 406, 411, 416,
	417, 420, 424, 426, 429, 433, 434, 437, 442, 444, 446, 450, 452, 456, 457, 459, 463, 464, 466, 469,
	475, 477, 483, 484, 486, 489, 492, 495, 500,
]
const VERY_HARD := [
	33, 38, 46, 54, 60, 64, 68, 73, 79, 83, 86, 94, 99, 105, 109, 114, 120, 127, 135, 140,
	146, 155, 160, 166, 171, 178, 183, 189, 197, 204, 213, 221, 228, 237, 244, 250, 256, 265, 272, 280,
	286, 294, 300, 307, 313, 321, 328, 336, 344, 350, 358, 364, 377, 384, 389, 397, 400, 409, 414, 422,
	430, 440, 447, 454, 461, 472, 480, 490, 497,
]


## Last level of the curve.
static func last_level() -> int:
	return REF_BLOCKS.size()


static func _index(id: int) -> int:
	return clampi(id, 1, REF_BLOCKS.size()) - 1


## Hard or VeryHard. Past the curve (generated levels) every 4th level.
static func is_hard(id: int) -> bool:
	if id > REF_BLOCKS.size():
		return id % 4 == 0
	return id in HARD or id in VERY_HARD


static func is_very_hard(id: int) -> bool:
	return id in VERY_HARD


## Colors allowed in this level.
static func color_count(id: int) -> int:
	if id <= EARLY_COLORS.size():
		return EARLY_COLORS[maxi(id, 1) - 1]
	return 4


## Median of `value` over the normal (untagged) levels within PEAK_SPAN levels of `id`, from L5; -1 if none.
static func _neighbor_median(id: int, value: Callable) -> float:
	var near: Array[int] = []
	for j in range(maxi(EARLY_BLOCKS.size() + 1, id - PEAK_SPAN), mini(REF_BLOCKS.size(), id + PEAK_SPAN) + 1):
		if j != id and not is_hard(j):
			near.append(int(value.call(j)))
	if near.is_empty():
		return -1.0
	near.sort()
	@warning_ignore("integer_division")
	var mid := near.size() / 2
	return float(near[mid]) if near.size() % 2 == 1 else 0.5 * float(near[mid - 1] + near[mid])


## Lowest value a Hard / VeryHard level `id` may have: PEAK_* times the neighbor median of `value` (0 for others).
static func _peak_floor(id: int, value: Callable) -> int:
	if id > REF_BLOCKS.size() or not is_hard(id):
		return 0
	var med := _neighbor_median(id, value)
	return ceili(med * (PEAK_VERY_HARD if is_very_hard(id) else PEAK_HARD)) if med >= 0.0 else 0


## Blocks before the peak rule: L1-4 the hand-made boards, then the reference clamped to MOTIF_MIN_BLOCKS..BLOCK_CAP.
static func _base_blocks(id: int) -> int:
	if id >= 1 and id <= EARLY_BLOCKS.size():
		return EARLY_BLOCKS[id - 1]
	return clampi(int(REF_BLOCKS[_index(id)]), MOTIF_MIN_BLOCKS, BLOCK_CAP)


## Rounds before the peak rule for a board of `n` blocks: the reference, scaled down when the block count is below
## the reference, at most WAVE_SHARE_MAX per block.
static func _base_waves(id: int, n: int) -> int:
	var ref_n := int(REF_BLOCKS[_index(id)])
	var w := float(REF_WAVES[_index(id)])
	if n < ref_n:
		w *= float(n) / float(ref_n)
	return clampi(roundi(w), 1, _wave_cap(n))


static func _wave_cap(n: int) -> int:
	return ceili(n * WAVE_SHARE_MAX)


## Target block count: `_base_blocks`, raised for a Hard / VeryHard level to its peak floor (neighbors' block counts),
## at most BLOCK_CAP. Ids outside the curve clamp to its ends.
static func block_count(id: int) -> int:
	var n := _base_blocks(id)
	if id <= EARLY_BLOCKS.size():
		return n
	return clampi(maxi(n, _peak_floor(id, _base_blocks)), MOTIF_MIN_BLOCKS, BLOCK_CAP)


## Target clear rounds: `_base_waves` for the target block count, raised for a Hard / VeryHard level to its peak floor
## (neighbors' rounds), at most WAVE_SHARE_MAX per block.
static func wave_count(id: int) -> int:
	var n := block_count(id)
	var w := _base_waves(id, n)
	var floor_w := _peak_floor(id, func(j: int) -> int: return _base_waves(j, _base_blocks(j)))
	return clampi(maxi(w, floor_w), 1, _wave_cap(n))


## Difficulty points 0..10 from the targets: blocks over BLOCK_CAP and rounds over SCORE_ROUNDS, half each.
static func score(id: int) -> float:
	var b := float(block_count(id)) / float(BLOCK_CAP)
	var w := minf(1.0, float(wave_count(id)) / float(SCORE_ROUNDS))
	return snappedf(5.0 * (b + w), 0.01)


## Exponent of the "blocked at start" weight when the generator assigns directions: higher means fewer blocks can
## leave right away.
static func blocked_power(id: int) -> int:
	if id >= SHAPED_FROM:
		return BLOCKED_POWER_HARD if is_hard(id) else BLOCKED_POWER
	return 2 if is_hard(id) else 1
