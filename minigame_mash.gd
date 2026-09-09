extends Control

# Mini-game Organik — "Balik Kompos"
# Klik tombol sebanyak GOAL kali sebelum waktu habis.

signal finished(success: bool)

const GOAL := 10
const TIME_LIMIT := 5.0

@onready var goal_label: Label = $GoalLabel
@onready var time_label: Label = $TimeLabel
@onready var mash_button: Button = $MashButton

var _playing: bool = false
var _clicks: int = 0
var _time_left: float = TIME_LIMIT

func _ready() -> void:
	mash_button.pressed.connect(_on_mash_pressed)
	visible = false

func start() -> void:
	_clicks = 0
	_time_left = TIME_LIMIT
	_update_goal()
	time_label.text = "%.1f" % _time_left
	_playing = true
	visible = true

func stop() -> void:
	_playing = false

func _process(delta: float) -> void:
	if not _playing:
		return

	_time_left -= delta
	time_label.text = "%.1f" % maxf(_time_left, 0.0)

	if _time_left <= 0.0:
		_playing = false
		finished.emit(_clicks >= GOAL)

func _on_mash_pressed() -> void:
	if not _playing:
		return
	_clicks += 1
	_update_goal()
	if _clicks >= GOAL:
		_playing = false
		finished.emit(true)

func _update_goal() -> void:
	goal_label.text = "%d / %d" % [_clicks, GOAL]