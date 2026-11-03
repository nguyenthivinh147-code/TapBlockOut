extends Node
## Plays the default-state clip of a Unity Animator (data/ui_unity/_anims.json) on the parent control tree.
## Curves are Hermite with the exported tangents, like AnimationCurve.Evaluate; a null tangent is a stepped key.

const UnityUI := preload("res://src/ui/unity_ui.gd")

var clip: Dictionary = {}
var speed := 1.0
var time := 0.0
var playing := true
## Animator.enabled: while off, the prefab's own values stay and the clip does not advance.
var enabled := true:
	set(on):
		enabled = on
		if on:
			_apply()

var _host: Control = null
## [{node, attr, keys} | {node, attr, sprites}]
var _tracks: Array = []


func setup(host: Control, data: Dictionary) -> void:
	_host = host
	clip = data
	speed = float(data.get("speed", 1.0))
	_tracks.clear()
	for c in data.get("curves", []):
		var node := _resolve(host, str(c.path))
		if node == null:
			continue
		var track := {"node": node, "attr": str(c.attr)}
		if c.has("sprites"):
			track["sprites"] = c.sprites
		else:
			track["keys"] = c.get("keys", [])
		_tracks.append(track)
	if enabled:
		_apply()


func _process(delta: float) -> void:
	if not enabled or not playing or _host == null or not _host.is_visible_in_tree():
		return
	time += delta * speed
	_apply()


func _apply() -> void:
	var length := float(clip.get("length", 0.0))
	var t := time
	if length > 0.0:
		t = fposmod(time, length) if bool(clip.get("loop", false)) else minf(time, length)
	var dirty := {}
	for track in _tracks:
		var node: Control = track.node
		if not is_instance_valid(node):
			continue
		if track.has("sprites"):
			var key := ""
			for k in track.sprites:
				if float(k[0]) <= t and k[1] != null:
					key = str(k[1])
			if key != "":
				UnityUI.set_sprite(node, key)
			continue
		var v := evaluate(track["keys"], t)
		if _set_attr(node, str(track.attr), v):
			dirty[node] = true
	for node in dirty:
		UnityUI.apply_rect(node)


## Hermite evaluation between keys [time, value, in_slope, out_slope].
static func evaluate(keys: Array, t: float) -> float:
	if keys.is_empty():
		return 0.0
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	var last: Array = keys[keys.size() - 1]
	if t >= float(last[0]):
		return float(last[1])
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		var t0 := float(a[0])
		var t1 := float(b[0])
		if t < t0 or t > t1:
			continue
		if a[3] == null or b[2] == null:
			return float(a[1])
		var dt := t1 - t0
		if dt <= 0.0:
			return float(b[1])
		var s := (t - t0) / dt
		var s2 := s * s
		var s3 := s2 * s
		var m0 := float(a[3]) * dt
		var m1 := float(b[2]) * dt
		return (2.0 * s3 - 3.0 * s2 + 1.0) * float(a[1]) + (s3 - 2.0 * s2 + s) * m0 + (-2.0 * s3 + 3.0 * s2) * float(b[1]) + (s3 - s2) * m1
	return float(last[1])


## Returns true when the Unity rect changed and needs apply_rect.
func _set_attr(node: Control, attr: String, v: float) -> bool:
	var axis := 0 if attr.ends_with(".x") or attr.ends_with(".r") else (1 if attr.ends_with(".y") or attr.ends_with(".g") else 2)
	if attr.begins_with("m_AnchoredPosition."):
		var r: Dictionary = node.get_meta("u_rect")
		r.pos[axis] = v
		return true
	if attr.begins_with("m_SizeDelta."):
		var r: Dictionary = node.get_meta("u_rect")
		r.size[axis] = v
		return true
	if attr.begins_with("m_LocalScale."):
		if axis < 2:
			node.scale[axis] = v
		return false
	if attr == "localEulerAnglesRaw.z":
		node.rotation = deg_to_rad(-v)
		return false
	if attr == "m_IsActive":
		node.visible = v > 0.5
		return false
	if attr.begins_with("m_Color.") or attr.begins_with("m_fontColor."):
		var ch := attr.get_slice(".", 1)
		UnityUI.set_color_channel(node, ch, v)
	return false


## Unity transform path ("Hand/TapFx") relative to host, by prefab names.
static func _resolve(host: Control, p: String) -> Control:
	if p == "":
		return host
	var cur: Control = host
	for part in p.split("/"):
		var next: Control = null
		for c in cur.get_children():
			if c is Control and c.has_meta("u") and str((c.get_meta("u") as Dictionary).get("n", "")) == part:
				next = c
				break
		if next == null:
			return null
		cur = next
	return cur
