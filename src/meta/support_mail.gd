extends RefCounted
## Support mail (design.md mục 8 "Mail hỗ trợ"), like CustomerSupportButton of color-cube-match-puzzle. Subject
## "<product> - <version> - <version code> - v<level version> - Android - USERID: <device id>" (the OS part only on
## Android and iOS), body "Hi there!. My account is <nickname>"; testers (is_tester) also get the SDK status lines.
## Pure: the caller passes every value (Settings._on_support).

## Unity's LevelDataVersionManager.CurrentLevelVersion, 0 without the manager. Levels ship inside the app here, so
## there is no level data version: always 0.
const LEVEL_VERSION := 0
## OS.get_name() -> the subject's OS part (Unity: "- Android ", "- IOS ").
const OS_TAGS := {"Android": "Android", "iOS": "IOS"}


## info: {product, version, version_code, os (OS.get_name()), device_id}.
static func subject(info: Dictionary) -> String:
	var s := "%s - %s - %s - v%d " % [str(info.get("product", "")), str(info.get("version", "")),
		str(info.get("version_code", "")), LEVEL_VERSION]
	var tag := str(OS_TAGS.get(str(info.get("os", "")), ""))
	if tag != "":
		s += "- %s " % tag
	return s + "- USERID: " + str(info.get("device_id", "")).strip_edges()


## sdk is empty for players. Testers pass Platform.support_status():
## {max, interstitial, rewarded, firebase, adjust, adjust_env, adjust_token}. The game has no banner ad, so Unity's
## "Banner:" line is left out.
static func body(player_name: String, sdk: Dictionary = {}) -> String:
	var b := "Hi there!. My account is %s" % player_name
	if sdk.is_empty():
		return b
	b += "\n--- SDK Status ---\n"
	b += "Max SDK Initialized: %s\n" % _flag(sdk.get("max", false))
	b += "Interstitial: %s\n" % str(sdk.get("interstitial", ""))
	b += "Rewarded: %s\n" % str(sdk.get("rewarded", ""))
	b += "Firebase Initialized: %s\n" % _flag(sdk.get("firebase", false))
	b += "Adjust SDK Initialized: %s\n" % _flag(sdk.get("adjust", false))
	b += "Adjust Environment: %s\n" % str(sdk.get("adjust_env", ""))
	b += "Adjust Token: %s\n" % str(sdk.get("adjust_token", ""))
	return b


## Unity's PlayerData.IsNative: development builds and the devices in Config.TESTER_DEVICES (DeviceIdTesting).
static func is_tester(debug_build: bool, device_id: String, testers: Array) -> bool:
	var id := device_id.strip_edges()
	return debug_build or (id != "" and testers.has(id))


## mailto link, subject and body percent-encoded (Uri.EscapeDataString).
static func url(email: String, subject_text: String, body_text: String) -> String:
	return "mailto:%s?subject=%s&body=%s" % [email, subject_text.uri_encode(), body_text.uri_encode()]


## C# bool.ToString(): "True" / "False".
static func _flag(v: Variant) -> String:
	return "True" if bool(v) else "False"
