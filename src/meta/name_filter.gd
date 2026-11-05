extends RefCounted
## Banned words for player nicknames (design.md mục 5 "Biệt danh"). A nickname holds only English letters, digits, "_",
## "." and "-", so every list is plain lowercase ASCII: profanity, slurs and sexual words of the game's 14 languages
## written in Latin letters without diacritics, plus names reserved for staff and the brand.
##
## Matching, case-insensitive:
## - A single pattern letter matches once or stretched to 3+ ("fuuuck"), not twice, so natural doubles stay harmless
##   ("Poornima" is not "porn"). A doubled letter needs at least two ("nigger" does not match "niger").
## - A run of digits followed by a letter reads as letters (0 o, 1 i or l, 3 e, 4 a, 5 s, 7 t, 8 b, 9 g): "sh1t",
##   "5hit", "a55hole". Trailing digits stay digits, so "Ana1" is not "anal".
## - ROOTS match anywhere in the name with "_", "." and "-" removed, after the ALLOW words are cut out ("Scunthorpe").
## - WORDS sit inside harmless words ("ass" in "class"), so they match only a whole word: the name split on "_", ".",
##   "-", digits and lower-to-upper case changes ("MyAss", "ass_99"), or the whole name without separators ("a.s.s").

const ROOTS: Array[String] = [
	# English
	"fuck", "phuck", "fakku", "shit", "bitch", "biatch", "cunt", "nigger", "nigga", "faggot", "whore", "slut", "pussy",
	"dickhead", "cocksuck", "asshole", "bastard", "wanker", "twat", "jizz", "penis", "vagina", "porn", "hitler",
	"rapist", "molest", "pedophil", "paedophil", "dildo", "blowjob", "handjob", "cumshot", "orgasm", "incest", "tranny",
	"shemale", "retard", "wetback", "raghead", "towelhead", "bollock", "jerkoff", "killyourself", "milf", "bdsm",
	"hentai", "titties",
	# Vietnamese
	"ditme", "ditmay", "ditcon", "dumemay", "dumamay", "concac", "cailon", "cailoz", "daubuoi", "matlon", "occho",
	"conchode", "sucvat",
	# Spanish
	"mierda", "cabron", "pendejo", "joder", "chingad", "maricon", "culero", "hijodeputa", "putamadre", "gilipolla",
	"malparid", "cojone", "follar",
	# Portuguese
	"caralho", "buceta", "arrombad", "cuzao", "piroca", "xoxota", "fodase", "vagabunda", "punheta",
	# French
	"putain", "salope", "connard", "connasse", "encule", "batard", "couille", "branleur", "niquetamere", "enfoire",
	"suceuse",
	# German
	"scheiss", "arschloch", "fotze", "votze", "wichser", "wixer", "schlampe", "hurensohn", "ficken", "schwuchtel",
	"missgeburt", "kanake", "neger", "drecksau",
	# Italian
	"cazzo", "stronz", "fanculo", "puttan", "minchia", "coglion", "porcodio", "porcamadonna", "dioporco", "diocane",
	"frocio", "zoccola", "mignotta", "pompino",
	# Turkish
	"orospu", "orosbu", "siktir", "sikis", "sikerim", "sikik", "yarrak", "aminakoy", "amcik", "pezevenk", "gavat",
	"kahpe", "yavsak", "gotveren",
	# Indonesian
	"bangsat", "kontol", "memek", "ngentot", "ngewe", "jancok", "jancuk", "goblok", "pepek", "lonte", "bajingan",
	"keparat", "pantek", "jembut", "peler", "jablay",
	# Russian, Ukrainian
	"blyat", "blyad", "bljad", "pizd", "pyzd", "huilo", "khuy", "khuj", "nahui", "nahuy", "pohui", "pohuy", "yebat",
	"yoban", "ebanat", "zaebal", "mudak", "mudila", "pidor", "pidar", "gandon", "gondon", "zhopa", "shlyukha",
	"shluha", "uebok", "eblan", "dolboeb", "dolboyob", "suchka",
	# Hindi
	"chutiy", "chutia", "chootiya", "madarchod", "maderchod", "bhenchod", "behenchod", "benchod", "bhosd", "gandu",
	"jhaant", "gaand", "lavde", "lawde",
	# Korean
	"shibal", "ssibal", "byungsin", "byeongsin", "gaesaek", "saekki", "jotgat", "jiral", "ssangnom",
	# Japanese
	"chinko", "chinpo", "kichigai", "yariman", "kutabare",
	# Reserved: staff and brand
	"admin", "moderator", "gamemaster", "customerservice", "sysop", "official", "horus", "candyaway", "tapblock",
	"google",
]

const WORDS: Array[String] = [
	# English
	"ass", "arse", "anal", "anus", "rape", "cock", "dick", "fag", "fuk", "fck", "fuq", "cum", "tits", "boob", "boobs",
	"sex", "sexy", "nazi", "nazis", "kkk", "kys", "chink", "gook", "spic", "kike", "coon", "dyke", "paki", "beaner",
	"pedo", "nude", "nudes", "xxx", "horny", "boner", "stfu",
	# Vietnamese
	"dit", "lon", "cac", "dcm", "dcmm", "dmm", "dkm", "vcl", "vkl", "clm", "cmm", "duma", "dume", "dmcs", "chode",
	# Spanish
	"puta", "puto", "marica", "culo", "polla", "zorra", "chinga", "verga", "hdp", "ctm",
	# Portuguese ("merda" and "foder" sit in Merdan, Fodera)
	"merda", "porra", "foda", "foder", "viado", "fdp", "vsf", "pqp", "corno", "bosta", "tnc", "vtnc",
	# French ("merde" sits in Merdeka, Indonesian "independence")
	"merde", "pute", "nique", "chier", "ntm",
	# German ("nutte" sits in Nutter)
	"arsch", "fick", "hure", "spast", "nutte",
	# Italian
	"troia", "figa",
	# Turkish
	"amk", "aq", "sik", "yarak", "ibne",
	# Indonesian
	"puki", "titit", "perek", "tolol",
	# Russian, Ukrainian
	"blya", "ebat",
	# Hindi
	"bsdk", "mkc", "bkl", "lodu", "lavda", "lawda", "harami",
	# Japanese
	"manko",
	# Reserved
	"gm", "staff", "support", "developer",
]

## Harmless words that hold a root, cut out before ROOTS match: Scunthorpe, Penistone (towns), therapist, shitake and
## Japanese names ending in -shita (Yamashita, Matsushita), badminton, chorus, flame retardant, Negeri (Malay "state"),
## puttanesca.
const ALLOW: Array[String] = [
	"scunthorpe", "penistone", "therapist", "shita", "badminton", "chorus", "retardant", "negeri", "puttanesca",
]

const LEET := {"0": "o", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "9": "g"}
const SEPARATORS := "_.-"

static var _roots: RegEx = null
static var _words: RegEx = null


## True when `nickname` holds a banned root or word.
static func is_banned(nickname: String) -> bool:
	_compile()
	for one in ["i", "l"]:
		var flat := _leet(_strip_separators(nickname.to_lower()), one)
		if _roots.search(_cut_allowed(flat)) != null or _is_word(flat):
			return true
		for w in _split(nickname, false):
			if _is_word(_leet(w, one)):
				return true
	for w in _split(nickname, true):
		if _is_word(w):
			return true
	return false


static func _is_word(w: String) -> bool:
	return w != "" and _words.search(w) != null


static func _compile() -> void:
	if _roots != null:
		return
	_roots = RegEx.create_from_string("(?:" + "|".join(_patterns(ROOTS)) + ")")
	_words = RegEx.create_from_string("^(?:" + "|".join(_patterns(WORDS)) + ")$")


static func _patterns(list: Array[String]) -> PackedStringArray:
	var out := PackedStringArray()
	for w in list:
		out.append(_stretch(w))
	return out


## "nigger" -> "n(?:nn+)?i(?:ii+)?g{2,}e(?:ee+)?r(?:rr+)?": a single letter once or 3+ times, a run of n letters n+ times.
static func _stretch(w: String) -> String:
	var out := ""
	var i := 0
	while i < w.length():
		var j := i
		while j < w.length() and w[j] == w[i]:
			j += 1
		var c := w[i]
		out += c + ("(?:%s%s+)?" % [c, c] if j - i == 1 else "{%d,}" % (j - i))
		i = j
	return out


static func _strip_separators(s: String) -> String:
	var out := ""
	for ch in s:
		if not SEPARATORS.contains(ch):
			out += ch
	return out


## Digit runs followed by a letter read as letters; "1" reads as `one` ("i" or "l").
static func _leet(s: String, one: String) -> String:
	var out := ""
	var i := 0
	while i < s.length():
		if not _is_digit(s[i]):
			out += s[i]
			i += 1
			continue
		var j := i
		while j < s.length() and _is_digit(s[j]):
			j += 1
		var run := s.substr(i, j - i)
		if j < s.length():
			for d in run:
				out += one if d == "1" else str(LEET.get(d, d))
		else:
			out += run
		i = j
	return out


static func _cut_allowed(s: String) -> String:
	for w in ALLOW:
		s = s.replace(w, "")
	return s


## Lowercase words of `nickname`: split on separators and lower-to-upper case changes, and on digits when
## `split_digits` is true.
static func _split(nickname: String, split_digits: bool) -> Array[String]:
	var out: Array[String] = []
	var cur := ""
	var prev_lower := false
	for ch in nickname:
		if SEPARATORS.contains(ch) or (split_digits and _is_digit(ch)):
			if cur != "":
				out.append(cur.to_lower())
			cur = ""
			prev_lower = false
			continue
		var upper := ch >= "A" and ch <= "Z"
		if upper and prev_lower and cur != "":
			out.append(cur.to_lower())
			cur = ""
		cur += ch
		prev_lower = ch >= "a" and ch <= "z"
	if cur != "":
		out.append(cur.to_lower())
	return out


static func _is_digit(ch: String) -> bool:
	return ch >= "0" and ch <= "9"
