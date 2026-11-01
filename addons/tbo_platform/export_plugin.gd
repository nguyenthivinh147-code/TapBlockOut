@tool
extends EditorExportPlugin
## Đưa AAR tbo_platform và dependency Maven vào bản Gradle (chỉ preset bật use_gradle_build).
## Preset APK thường (Android Demo) không bị đụng tới.

const BIN_DIR := "res://addons/tbo_platform/bin/"
const CONFIG_PATH := "res://android_config.json"
const VALUES_FILE := "res://android/build/res/values/tbo_platform.xml"

## Phiên bản chốt theo android/plugins/tbo_platform/build.gradle.kts (Firebase BoM 35.1.0).
const DEPENDENCIES: PackedStringArray = [
	"com.applovin:applovin-sdk:13.7.0",
	"com.google.android.ump:user-messaging-platform:4.0.0",
	"com.google.firebase:firebase-analytics:24.0.0",
	"com.google.firebase:firebase-config:24.0.1",
	"com.google.firebase:firebase-crashlytics:21.0.1",
	"com.adjust.sdk:adjust-android:5.8.1",
	"com.google.android.gms:play-services-ads-identifier:18.2.0",
	"com.android.installreferrer:installreferrer:2.2",
	"com.google.android.play:review:2.0.2",
	"com.google.android.gms:play-services-games-v2:22.1.0",
]


func _get_name() -> String:
	return "TboPlatform"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _use_gradle() -> bool:
	var preset := get_export_preset()
	return preset != null and bool(preset.get("gradle_build/use_gradle_build"))


func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	if not _use_gradle():
		return PackedStringArray()
	var path := BIN_DIR + ("tbo_platform-debug.aar" if debug else "tbo_platform-release.aar")
	if not FileAccess.file_exists(path):
		push_warning("tbo_platform: thiếu %s, chạy tools/build_plugin.sh" % path)
		return PackedStringArray()
	return PackedStringArray([path])


func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	if not _use_gradle():
		return PackedStringArray()
	return DEPENDENCIES


func _get_android_dependencies_maven_repos(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	# google() và mavenCentral() đã có sẵn trong template Godot.
	return PackedStringArray()


## Play Games SDK đọc App ID từ manifest; chỉ thêm khi đã cấu hình play_games_app_id.
func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	if not _use_gradle() or _read_app_id() == "":
		return ""
	return '<meta-data android:name="com.google.android.gms.games.APP_ID" android:value="@string/game_services_project_id" />'


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if not _use_gradle():
		return
	_write_values()


## play_games_app_id (chỉ chữ số) từ res://android_config.json, "" nếu thiếu hoặc không hợp lệ.
func _read_app_id() -> String:
	if not FileAccess.file_exists(CONFIG_PATH):
		return ""
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not (parsed is Dictionary):
		return ""
	var app_id := str((parsed as Dictionary).get("play_games_app_id", "")).strip_edges()
	return app_id if app_id.is_valid_int() else ""


## Ghi App ID vào resource string của template Gradle (ghi đè giá trị "0" của thư viện).
## Thiếu cấu hình thì xoá file ghi đè.
func _write_values() -> void:
	var build_dir := ProjectSettings.globalize_path("res://android/build")
	if not DirAccess.dir_exists_absolute(build_dir):
		return
	var app_id := _read_app_id()
	var target := ProjectSettings.globalize_path(VALUES_FILE)
	if app_id == "":
		if FileAccess.file_exists(VALUES_FILE):
			DirAccess.remove_absolute(target)
		return
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var f := FileAccess.open(VALUES_FILE, FileAccess.WRITE)
	if f == null:
		push_warning("tbo_platform: không ghi được %s" % VALUES_FILE)
		return
	f.store_string('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n\t<string name="game_services_project_id" translatable="false">%s</string>\n</resources>\n' % app_id)
	f.close()
