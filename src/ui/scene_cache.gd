extends RefCounted
## The scenes opened last (screens, popups, Unity layers), kept loaded so opening one again skips parsing it and
## decoding its textures: a held PackedScene keeps its sub-resources, the scenes it instances and their textures in
## memory. `capacity` (Config.SCENE_CACHE) caps how many are held; the one opened longest ago goes first.
## Every instance shares the sub-resources of the held scene (materials, styleboxes, animations): code edits a
## duplicate, never a resource it got from a node of the scene (tests/test_scene_cache.gd).

const Config := preload("res://src/config.gd")

static var capacity: int = Config.SCENE_CACHE
## path -> PackedScene, oldest use first (a Dictionary keeps insertion order).
static var _held := {}


## PackedScene at path, held or loaded now and held; null when it is missing.
static func scene(path: String) -> PackedScene:
	var ps: PackedScene = _held.get(path)
	if ps != null:
		_held.erase(path)
	else:
		ps = load(path) as PackedScene
		if ps == null:
			return null
	if capacity > 0:
		_held[path] = ps
		while _held.size() > capacity:
			_held.erase(_held.keys()[0])
	return ps


## New instance of the scene at path; null when it is missing.
static func instantiate(path: String) -> Node:
	var ps := scene(path)
	return ps.instantiate() if ps != null else null


## Paths held, oldest use first.
static func held() -> Array:
	return _held.keys()


static func clear() -> void:
	_held.clear()
