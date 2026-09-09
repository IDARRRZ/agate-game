extends CanvasLayer

# Zone Progress UI — label di pojok layar, menampilkan % bersih tiap zone.
# Disimpan di dunia.tscn.

@onready var container: VBoxContainer = $Panel/ZoneList
@onready var zone_template: Label = null

const ZONE_DISPLAY = {
	"beach": "Beach/Shallow",
	"coral_reef": "Coral Reef",
	"open_ocean": "Open Ocean",
	"deep_sea": "Deep Sea",
}

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.zone_progress_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	for zone in GameManager.ZONE_ORDER:
		var lbl := Label.new()
		var pct := GameManager.get_zone_clean_percent(zone)
		var unlocked := GameManager.is_zone_unlocked(zone)
		var status := "OK" if unlocked else "LOCKED"
		lbl.text = "[%s] %s — %.0f%% (%s)" % [
			zone_label_short(zone),
			ZONE_DISPLAY[zone],
			pct,
			status,
		]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override(
			"font_color",
			Color(0.5, 1.0, 0.5) if pct >= 100.0 else (
				Color(1, 1, 1) if unlocked else Color(0.7, 0.7, 0.7)
			)
		)
		container.add_child(lbl)

func zone_label_short(z: String) -> String:
	match z:
		"beach": return "Beach"
		"coral_reef": return "Coral"
		"open_ocean": return "Ocean"
		"deep_sea": return "Deep"
	return z