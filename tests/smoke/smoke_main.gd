extends SceneTree
## Điểm vào smoke trên desktop: tools/smoke.sh (và kịch bản G khi mở tiến trình G2) chạy
## `-s res://tests/smoke/smoke_main.gd -- <tham số>`. Runner là Node smoke.gd, gắn vào root như màn chính; trên máy
## Android thật nó là gốc của tests/smoke/device_main.tscn (tools/device_smoke.sh).

const Runner := preload("res://tests/smoke/smoke.gd")


func _initialize() -> void:
	root.add_child(Runner.new())
