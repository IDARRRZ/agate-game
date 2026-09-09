extends CanvasLayer

# Recycling UI — pilih material, selesaikan mini-game sesuai jenisnya
# Di-instantiate otomatis oleh recycling_station.gd
# Sukses: +1 finished product. Gagal: material hilang.

signal ui_closed

@onready var count_labels = {
	"plastik": $Panel/MaterialSection/RowPlastik/CountLabel,
	"logam": $Panel/MaterialSection/RowLogam/CountLabel,
	"organik": $Panel/MaterialSection/RowOrganik/CountLabel,
}
@onready var start_buttons = {
	"plastik": $Panel/MaterialSection/RowPlastik/StartBtn,
	"logam": $Panel/MaterialSection/RowLogam/StartBtn,
	"organik": $Panel/MaterialSection/RowOrganik/StartBtn,
}
@onready var minigames = {
	"plastik": $Panel/MiniGameArea/TimingGame,
	"logam": $Panel/MiniGameArea/HeatGame,
	"organik": $Panel/MiniGameArea/MashGame,
}
@onready var material_section: VBoxContainer = $Panel/MaterialSection
@onready var feedback_label: Label = $Panel/FeedbackLabel
@onready var close_btn: Button = $Panel/CloseButton

var _busy: bool = false
var _active_type: String = ""
var _feedback_token: int = 0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	for type in start_buttons:
		start_buttons[type].pressed.connect(_on_start_pressed.bind(type))
		minigames[type].finished.connect(_on_minigame_finished.bind(type))

	close_btn.pressed.connect(close_ui)
	GameManager.recycled_material_changed.connect(refresh_counts)

func open_ui() -> void:
	visible = true
	material_section.visible = true
	_hide_games()
	refresh_counts()

func close_ui() -> void:
	if not visible:
		return
	_abort_game()
	visible = false
	feedback_label.text = ""
	ui_closed.emit()

func refresh_counts() -> void:
	for type in count_labels:
		count_labels[type].text = "x%d" % GameManager.recycled_material[type]
		start_buttons[type].disabled = _busy or GameManager.recycled_material[type] <= 0

func _hide_games() -> void:
	for type in minigames:
		minigames[type].stop()
		minigames[type].visible = false

func _abort_game() -> void:
	if _active_type != "" and minigames.has(_active_type):
		minigames[_active_type].stop()
	_busy = false
	_active_type = ""

func _on_start_pressed(type: String) -> void:
	if _busy:
		return

	# Material dikonsumsi di awal — gagal berarti hilang (aturan GDD)
	if not GameManager.consume_for_recycle(type):
		show_feedback("Material %s habis." % type.capitalize(), false)
		return

	_active_type = type
	_busy = true
	refresh_counts()

	material_section.visible = false
	var game = minigames[type]
	game.start()

func _on_minigame_finished(success: bool, type: String) -> void:
	_busy = false
	_active_type = ""
	minigames[type].stop()
	minigames[type].visible = false
	material_section.visible = true

	if success:
		GameManager.add_finished_product(type)
		AudioManager.play_sfx("success")
		show_feedback("Sukses! Produk %s +1" % type.capitalize(), true)
	else:
		AudioManager.play_sfx("error")
		show_feedback("Gagal! Material %s hilang." % type.capitalize(), false)

	refresh_counts()

func show_feedback(msg: String, ok: bool) -> void:
	_feedback_token += 1
	var token := _feedback_token
	feedback_label.text = msg
	feedback_label.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.4) if ok else Color(1.0, 0.45, 0.45)
	)
	await get_tree().create_timer(1.8).timeout
	if token == _feedback_token and feedback_label:
		feedback_label.text = ""