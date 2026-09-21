extends Node

# Zone Depth Detector — mendeteksi zona kedalaman laut berdasarkan posisi vertikal player (Y)
# 3 Ocean Zones (Bebas Menyelam / Free Exploration):
# Terumbu Karang (O2 drain x1.0) → Samudra Lepas (O2 drain x1.5) → Palung Laut (O2 drain x2.0)

const ZONE_THRESHOLDS := [
	{"zone": "coral_reef", "max_y": 750.0},
	{"zone": "open_ocean", "max_y": 1150.0},
	{"zone": "deep_sea", "max_y": 99999.0},
]

var _player: Node2D
var _last_zone: String = "coral_reef"
var _hint_label: Label
var _hint_timer: float = 0.0

func _ready() -> void:
	_last_zone = GameManager.current_zone
	_setup_hint_ui()

func _setup_hint_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint_label.add_theme_constant_override("outline_size", 6)
	_hint_label.position = Vector2(0, 75)
	_hint_label.size = Vector2(1152, 40)
	_hint_label.visible = false
	layer.add_child(_hint_label)

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if not _player:
			return

	if _hint_timer > 0:
		_hint_timer -= delta
		if _hint_timer <= 0:
			_hint_label.visible = false

	var y := _player.position.y
	var zone := _zone_for_y(y)

	if zone != _last_zone:
		_last_zone = zone
		GameManager.current_zone = zone
		_show_zone_enter(zone)
		print("[Depth] Zone → ", zone, " (Y=", int(y), ")")

func _zone_for_y(y: float) -> String:
	for t in ZONE_THRESHOLDS:
		if y < t["max_y"]:
			return t["zone"]
	return "deep_sea"

func _zone_display(zone: String) -> String:
	match zone:
		"coral_reef": return "Terumbu Karang"
		"open_ocean": return "Samudra Lepas"
		"deep_sea": return "Palung Laut"
		_: return zone

func _show_zone_enter(zone: String) -> void:
	var drain: float = GameManager.get_zone_o2_drain(zone)
	if zone == "deep_sea":
		_hint_label.text = "▸ %s — Waspada! Tekanan tinggi, O₂ terkuras x%.1f" % [_zone_display(zone), drain]
		_hint_label.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	elif zone == "open_ocean":
		_hint_label.text = "▸ %s — Samudra terbuka, O₂ terkuras x%.1f" % [_zone_display(zone), drain]
		_hint_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	else:
		_hint_label.text = "▸ %s — O₂ normal (x%.1f)" % [_zone_display(zone), drain]
		_hint_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.8))
	_hint_label.visible = true
	_hint_timer = 2.5
