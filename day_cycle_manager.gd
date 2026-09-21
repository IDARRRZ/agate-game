extends Node

const TIME_SPEED := 2.5
const MORNING_HOUR := 6.0
const SUNSET_START := 16.5
const NIGHT_SLEEP := 19.5

var current_day: int = 1
var current_time_hours: float = MORNING_HOUR
var is_sleeping: bool = false
var pending_sleep_on_surface: bool = false

var sunset_canvas: CanvasLayer
var sunset_rect: ColorRect

var sleep_canvas: CanvasLayer
var sleep_rect: ColorRect
var sleep_label: Label
var sleep_sublabel: Label

var hud_canvas: CanvasLayer
var hud_panel: PanelContainer
var hud_label: Label

signal day_changed(new_day: int)
signal time_updated(hour: int, minute: int, time_str: String)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_sunset_layer()
	_setup_hud()
	_setup_sleep_layer()
	_update_hud()
	print("[DayCycle] Initialized — Day ", current_day, " at 06:00")

func _setup_sunset_layer() -> void:
	sunset_canvas = CanvasLayer.new()
	sunset_canvas.layer = 2
	add_child(sunset_canvas)
	sunset_rect = ColorRect.new()
	sunset_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sunset_rect.color = Color(0, 0, 0, 0)
	sunset_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sunset_canvas.add_child(sunset_rect)

func _setup_hud() -> void:
	hud_canvas = CanvasLayer.new()
	hud_canvas.layer = 85
	add_child(hud_canvas)
	hud_panel = PanelContainer.new()
	hud_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hud_panel.offset_left = -230.0
	hud_panel.offset_top = 14.0
	hud_panel.offset_right = -16.0
	hud_panel.offset_bottom = 50.0
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.14, 0.19, 0.85)
	style.set_corner_radius_all(8)
	style.border_color = Color(0.25, 0.4, 0.55, 0.6)
	style.set_border_width_all(1)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	hud_panel.add_theme_stylebox_override("panel", style)
	hud_label = Label.new()
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_label.add_theme_font_size_override("font_size", 14)
	hud_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	hud_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hud_label.add_theme_constant_override("outline_size", 3)
	hud_panel.add_child(hud_label)
	hud_canvas.add_child(hud_panel)
	hud_panel.visible = false

func _setup_sleep_layer() -> void:
	sleep_canvas = CanvasLayer.new()
	sleep_canvas.layer = 120
	add_child(sleep_canvas)
	sleep_rect = ColorRect.new()
	sleep_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	sleep_rect.color = Color(0, 0, 0, 0)
	sleep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sleep_canvas.add_child(sleep_rect)
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sleep_canvas.add_child(center)
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)
	sleep_label = Label.new()
	sleep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_label.add_theme_font_size_override("font_size", 24)
	sleep_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	sleep_label.modulate.a = 0.0
	vbox.add_child(sleep_label)
	sleep_sublabel = Label.new()
	sleep_sublabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_sublabel.add_theme_font_size_override("font_size", 18)
	sleep_sublabel.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	sleep_sublabel.modulate.a = 0.0
	vbox.add_child(sleep_sublabel)

func _is_darat() -> bool:
	var s = get_tree().current_scene
	if not s:
		return false
	return s.name == "Dunia" or s.name == "dunia"

func _process(delta: float) -> void:
	if is_sleeping:
		return
	if not _is_darat():
		if hud_panel:
			hud_panel.visible = false
		if sunset_rect:
			sunset_rect.color = Color(0, 0, 0, 0)
		return
	if hud_panel:
		hud_panel.visible = true
	if pending_sleep_on_surface:
		pending_sleep_on_surface = false
		_start_sleep_transition()
		return
	current_time_hours += (delta * TIME_SPEED) / 60.0
	_update_sunset_tint(delta)
	_update_hud()
	if current_time_hours >= NIGHT_SLEEP:
		_start_sleep_transition()

func _update_sunset_tint(_delta: float) -> void:
	if not sunset_rect:
		return
	if not _is_darat():
		sunset_rect.color = Color(0, 0, 0, 0)
		return
	if current_time_hours < SUNSET_START:
		sunset_rect.color = Color(0, 0, 0, 0)
	elif current_time_hours < NIGHT_SLEEP:
		var progress: float = (current_time_hours - SUNSET_START) / (NIGHT_SLEEP - SUNSET_START)
		sunset_rect.color = Color(0.92, 0.42, 0.10, progress * 0.28)
	else:
		sunset_rect.color = Color(0.92, 0.42, 0.10, 0.28)

func _update_hud() -> void:
	if not hud_label or not hud_panel:
		return
	if not _is_darat():
		hud_panel.visible = false
		return
	hud_panel.visible = true
	var total_minutes := int(current_time_hours * 60.0)
	var hour := (total_minutes / 60) % 24
	var minute := total_minutes % 60
	var time_str := "%02d:%02d" % [hour, minute]
	var phase_icon := "☀️"
	var phase_name := "Siang"
	if hour < 11:
		phase_icon = "🌅"
		phase_name = "Pagi"
	elif hour < 15:
		phase_icon = "☀️"
		phase_name = "Siang"
	elif hour < 18:
		phase_icon = "🌇"
		phase_name = "Sore"
	else:
		phase_icon = "🌙"
		phase_name = "Senja"
	hud_label.text = "📅 Hari %d  •  %s %s [%s]" % [current_day, phase_icon, time_str, phase_name]
	time_updated.emit(hour, minute, time_str)

func _start_sleep_transition() -> void:
	if not _is_darat():
		pending_sleep_on_surface = true
		current_time_hours = NIGHT_SLEEP
		return
	is_sleeping = true
	print("[DayCycle] Malam tiba... Memulai transisi tidur hari ke-", current_day)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set("can_move", false)
		player.set("velocity", Vector2.ZERO)
		if player.has_method("change_state"):
			player.change_state("idle")
	sleep_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	sleep_label.text = "Malam telah berlalu dengan tenang..."
	sleep_sublabel.text = "🌅 Hari ke-%d — 06:00 Pagi" % [current_day + 1]
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sleep_rect, "color", Color(0, 0, 0, 1.0), 1.0)
	tween.tween_property(sleep_label, "modulate:a", 1.0, 0.8).set_delay(0.4)
	tween.tween_property(sleep_sublabel, "modulate:a", 1.0, 0.8).set_delay(0.7)
	await tween.finished
	await get_tree().create_timer(1.8).timeout
	current_day += 1
	current_time_hours = MORNING_HOUR
	day_changed.emit(current_day)
	_update_hud()
	if sunset_rect:
		sunset_rect.color = Color(0, 0, 0, 0)
	var tween_in = create_tween().set_parallel(true)
	tween_in.tween_property(sleep_rect, "color", Color(0, 0, 0, 0.0), 1.0)
	tween_in.tween_property(sleep_label, "modulate:a", 0.0, 0.6)
	tween_in.tween_property(sleep_sublabel, "modulate:a", 0.0, 0.6)
	await tween_in.finished
	sleep_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_sleeping = false
	if is_instance_valid(player):
		player.set("can_move", true)
	print("[DayCycle] Bangun pagi hari ke-", current_day)
