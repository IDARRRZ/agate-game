extends Control

# Mini-game Logam — "Lebur Logam"
# Tahan tombol → suhu naik; lepas → turun.
# Kumpulkan akumulasi 3 detik di dalam band (60–80) selama jendela 5 detik.

signal finished(success: bool)

const TEMP_MIN := 0.0
const TEMP_MAX := 100.0
const BAND_LOW := 60.0
const BAND_HIGH := 80.0
const RATE_UP := 70.0    # suhu per detik saat menahan
const RATE_DOWN := 55.0  # peluruhan per detik saat dilepas
const WINDOW_TIME := 5.0 # durasi tantangan
const GOAL_ACCUM := 3.0  # akumulasi minimal dalam band

@onready var gauge_bg: ColorRect = $GaugeBG
@onready var gauge_fill: ColorRect = $GaugeFill
@onready var band_mark: ColorRect = $BandMark
@onready var timer_label: Label = $TimerLabel
@onready var hold_button: Button = $HoldButton

var _playing: bool = false
var _holding: bool = false
var _temp: float = 20.0
var _accum: float = 0.0
var _time_left: float = WINDOW_TIME

func _ready() -> void:
	hold_button.button_down.connect(_on_hold_down)
	hold_button.button_up.connect(_on_hold_up)
	visible = false

func start() -> void:
	_temp = randf_range(10.0, 30.0)
	_accum = 0.0
	_time_left = WINDOW_TIME
	_holding = false
	_layout_band()
	_update_gauge()
	timer_label.text = "%.1f" % _time_left
	_playing = true
	visible = true

func stop() -> void:
	_playing = false

func _process(delta: float) -> void:
	if not _playing:
		return

	_time_left -= delta

	if _holding:
		_temp += RATE_UP * delta
	else:
		_temp -= RATE_DOWN * delta
	_temp = clampf(_temp, TEMP_MIN, TEMP_MAX)

	var in_band := _temp >= BAND_LOW and _temp <= BAND_HIGH
	if in_band:
		_accum += delta

	_update_gauge()
	timer_label.text = "%.1f" % maxf(_time_left, 0.0)

	if _time_left <= 0.0:
		_playing = false
		finished.emit(_accum >= GOAL_ACCUM)

func _update_gauge() -> void:
	var frac := (_temp - TEMP_MIN) / (TEMP_MAX - TEMP_MIN)
	var h := gauge_bg.size.y * frac
	gauge_fill.size.y = h
	gauge_fill.position.y = gauge_bg.position.y + gauge_bg.size.y - h

func _layout_band() -> void:
	var bg_h := gauge_bg.size.y
	var span := BAND_HIGH - BAND_LOW
	band_mark.position.y = gauge_bg.position.y + (TEMP_MAX - BAND_HIGH) / (TEMP_MAX - TEMP_MIN) * bg_h
	band_mark.size.y = span / (TEMP_MAX - TEMP_MIN) * bg_h

func _on_hold_down() -> void:
	_holding = true

func _on_hold_up() -> void:
	_holding = false