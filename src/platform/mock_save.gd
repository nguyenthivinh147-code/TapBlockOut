extends RefCounted
## Bản sao lưu giả lập (chỉ trong bộ nhớ). Thật sự là Play Games Saved Games.

signal cloud_synced(json: String)

var last_json: String = ""
## Bản cloud giả lập. Mặc định rỗng (demo không có cloud); test đặt rồi phát cloud_synced.
var cloud_json: String = ""
var mirror_count: int = 0
var flush_count: int = 0
var sync_count: int = 0


func mirror(json: String) -> void:
	last_json = json
	mirror_count += 1


func backup() -> String:
	return last_json


func flush() -> void:
	flush_count += 1


func sync_cloud() -> void:
	sync_count += 1

