extends "res://src/ui/stub_ui.gd"
## Wireframe 1.3 Download Resources. DownloadDataLayer (color-cube-match-puzzle) as in splash.gd: the Slider and
## loading text show the download progress. The game's choice is DownloadDataLayer's own dialog,
## PopupLoginNoInternet: title, two-line message (subtitle, size needed), Cancel as Skip and Ok as Download in its
## button row. The panel grows by the two network options, each a copy of PopupEditNameLayer's input field art
## with its text style and a check (on) or cross (off), spaced like that prefab's label and field. Not wired to logic.

const UnityUI := preload("res://src/ui/unity_ui.gd")
const Splash := preload("res://src/ui/splash.gd")

const POP := "PopupLoginNoInternet"


func _sample() -> Dictionary:
	return SampleData.DOWNLOAD


func _build() -> void:
	# scenes/download_data.tscn holds the panel grown by the two options (PopupEditNameLayer's input field art, text
	# left in the Text Area, check on / cross off), each a field height + 17 below the message.
	var pct := int(view.get("percent", 0))
	var progress := tr("boot_download_progress") % [pct, int(view.get("done_mb", 0)), int(view.get("total_mb", 0))]
	ui = Splash.loading_screen(self, pct / 100.0, progress, str(view.get("version", "")))
	# loading_screen hides the dialog; a scene does not keep an inactive prefab node shown, so Cancel is shown here too.
	ui.show(POP, true)
	ui.show(POP + "/Panel/Content/Button/Cancel", true)
	ui.text(POP + "/Panel/Image/txtHeader", tr("boot_download_title"))
	ui.text(POP + "/Panel/Content/Description", "%s\n%s" % [tr("boot_download_sub"), tr("boot_download_need") % int(view.get("total_mb", 0))])
	ui.text(POP + "/Panel/Content/Button/Cancel/Out", tr("boot_skip"))
	ui.on_click(POP + "/Panel/Content/Button/Cancel", _send.bind("skip"))
	ui.text(POP + "/Panel/Content/Button/Ok/Out", tr("boot_download_go"))
	ui.on_click(POP + "/Panel/Content/Button/Ok", _send.bind("download"))
	ui.on_click(POP + "/Panel/Top/btnTurnOff", _send.bind("close"))
	UnityUI.set_text(%OptionWifi.get_node("Label"), tr("boot_download_wifi"))
	UnityUI.set_text(%OptionCell.get_node("Label"), tr("boot_download_cell"))
	ui.relayout(POP + "/Panel")
