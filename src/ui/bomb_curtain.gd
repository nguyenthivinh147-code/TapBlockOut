extends "res://src/ui/candy_curtain.gd"
## Màn chuyển cảnh vào Màn đặc biệt (design.md mục 7 "Màn đặc biệt"): như màn kẹo rơi (candy_curtain.gd) nhưng mỗi viên
## là quả bom kẹo cao su (assets/ui/special_bomb.png), nền dưới đống bom màu chàm đậm của thân bom. Dùng cho cả hai lối
## vào: icon ở Home (Main.curtain_swap) và popup mời sau thẻ thắng (level.gd).

const BOMB_TEX := "res://assets/ui/special_bomb.png"
const BOMB_BACKING := Color("1d1850")


func _init() -> void:
	custom_tex = BOMB_TEX
	custom_backing = BOMB_BACKING
