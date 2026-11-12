extends ResourceFormatLoader
## Loads a themed twin in place of an original texture: res://assets/<path> -> res://assets/themes/<theme>/<path>.
## Registered in front of the importer by theme_assets.gd, so scenes (ext_resource), load() and preload() all get the
## twin under the original path. The map is fixed at creation and only read afterwards (safe for threaded loads).

const EXTS := ["png", "webp", "jpg", "jpeg"]

var _map: Dictionary = {}


func _init(map: Dictionary) -> void:
	_map = map


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(EXTS)


func _recognize_path(path: String, _type: StringName) -> bool:
	return _map.has(path)


func _handles_type(type: StringName) -> bool:
	return type == &"" or ClassDB.is_parent_class(&"CompressedTexture2D", type)


func _get_resource_type(path: String) -> String:
	return "CompressedTexture2D" if _map.has(path) else ""


func _exists(path: String) -> bool:
	return _map.has(path)


func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	# A fresh copy: ResourceLoader then caches it under the original path, like the importer's own texture.
	return ResourceLoader.load(_map[path], "", ResourceLoader.CACHE_MODE_IGNORE)
