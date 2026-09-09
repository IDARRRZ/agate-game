extends Control

# Mini-game Plastik — "Cetak Ulang"
# Marker sweep bolak-balik; klik saat marker di dalam zona hijau.

signal finished(success: bool)

const SWEEP_SPEED := 0.9  # kecepatan normalisasi per detik (t 0→1→0)

@onready var track: ColorRect = $Track
@onready var zone_mark: ColorRect = $ZoneMark
@onready var marker: ColorRect = $Marker
@onready var act_button: Button = $ActButton

var _playing: bool = false
var _t: float = 0.0
var _dir: float = 1.0
var _zone_start: float = 0.4
var _zone_width: float = 0.2

func _ready() -> void:
	act_button.pressed.connect(_on_act_pressed)
	visible = false

func start() -> void:
	_zone_width = randf_range(0.16, 0.24)
	_zone_start = randf_range(0.06, 0.94 - _zone_width)
	_t = randf_range(0.0, 1.0)
	_dir = 1.0 if randf() > 0.5 else -1.0
	_layout_zone()
	_update_marker()
	_playing = true
	visible = true

func stop() -> void:
	_playing = false

func _process(delta: float) -> void:
	if not _playing:
		return
	_t += _dir * SWEEP_SPEED * delta
	if _t >= 1.0:
		_t = 1.0
		_dir = -1.0
	elif _t <= 0.0:
		_t = 0.0
		_dir = 1.0
	_update_marker()

func _layout_zone() -> void:
	var track_w := track.size.x
	zone_mark.position.x = track.position.x + _zone_start * track_w
	zone_mark.size.x = _zone_width * track_w

func _update_marker() -> void:
	var track_w := track.size.x
	marker.position.x = track.position.x + (_t * track_w) - marker.size.x * 0.5

func _on_act_pressed() -> void:
	if not _playing:
		return
	_playing = false
	var success := _t >= _zone_start and _t <= (_zone_start + _zone_width)
	finished.emit(success)