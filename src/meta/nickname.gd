extends RefCounted
## Player nickname (design.md mục 5 "Biệt danh"). Reads and writes s.profile only. "" means none set yet; Game then
## gives the save its default code (ensure, "CD_042917").
## Rules: Config.NAME_MIN..NAME_MAX characters after trimming spaces at both ends, only English letters, digits, "_",
## "." and "-", at least one letter or digit, no banned word (name_filter.gd). Free, no limit on changes.

const Config := preload("res://src/config.gd")
const NameFilter := preload("res://src/meta/name_filter.gd")

## check() and change() results; "" means accepted.
const ERR_LENGTH := "length"
const ERR_CHARS := "chars"
const ERR_BANNED := "banned"


static func current(s: Dictionary) -> String:
	var p: Variant = s.get("profile")
	return str((p as Dictionary).get("name", "")) if p is Dictionary else ""


## "" when `raw` (trimmed) is a valid nickname, else ERR_LENGTH, ERR_CHARS or ERR_BANNED.
static func check(raw: String) -> String:
	var n := raw.strip_edges()
	if n.length() < Config.NAME_MIN or n.length() > Config.NAME_MAX:
		return ERR_LENGTH
	var alnum := false
	for ch in n:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			alnum = true
		elif not "_.-".contains(ch):
			return ERR_CHARS
	if not alnum:
		return ERR_CHARS
	if NameFilter.is_banned(n):
		return ERR_BANNED
	return ""


## Saves the trimmed `raw` in s.profile.name when check() accepts it. Returns check()'s result.
static func change(s: Dictionary, raw: String) -> String:
	var err := check(raw)
	if err != "":
		return err
	_write(s, raw.strip_edges())
	return ""


## Default nickname: Config.NAME_CODE then Config.NAME_CODE_DIGITS random digits ("CD_042917"). Always passes check():
## name_filter.gd reads a trailing digit run as digits, not letters.
static func make_default(rng: RandomNumberGenerator) -> String:
	var n := Config.NAME_CODE
	for i in Config.NAME_CODE_DIGITS:
		n += str(rng.randi_range(0, 9))
	return n


## Gives `s` a make_default() nickname when it has none. True when it wrote one.
static func ensure(s: Dictionary, rng: RandomNumberGenerator) -> bool:
	if current(s) != "":
		return false
	_write(s, make_default(rng))
	return true


static func _write(s: Dictionary, n: String) -> void:
	if not (s.get("profile") is Dictionary):
		s["profile"] = {}
	s.profile["name"] = n
