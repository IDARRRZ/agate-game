extends Node2D

var max_o2: float = 60.0
var current_o2: float = 60.0
var drain_rate: float = 1.0
var is_active: bool = false

signal o2_changed(value: float)
signal o2_depleted
signal o2_low_warning

# Faktor polusi (GDD Bab 4.D.1):
# >50% polusi → O2 habis 20% lebih cepat; >75% → 40% lebih cepat
const MULT_MID := 1.2
const MULT_HIGH := 1.4

var _warning_emitted: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Drain rate gabungan: zone × polusi
# Zone: Beach 1×, Coral Reef 1.2×, Open Ocean 1.5×, Deep Sea 2× (GDD Bab 6.D)
func get_zone_multiplier() -> float:
	return GameManager.get_zone_o2_drain(GameManager.current_zone)

func get_pollution_multiplier() -> float:
	var level := AirQuality.pollution_level
	if level >= 75.0:
		return MULT_HIGH
	if level >= 50.0:
		return MULT_MID
	return 1.0

func _process(delta: float) -> void:
	if not is_active:
		return
	
	var mult := get_zone_multiplier() * get_pollution_multiplier()
	current_o2 -= drain_rate * mult * delta
	current_o2 = clampf(current_o2, 0.0, max_o2)
	
	var frame_index = int(round((current_o2 / max_o2) * 11))
	frame_index = clampi(frame_index, 0, 11)
	anim.frame = frame_index
	
	_update_tint(mult)
	o2_changed.emit(current_o2)
	
	# Threshold warning: O₂ < 25%
	if current_o2 / max_o2 <= 0.25 and not _warning_emitted:
		o2_low_warning.emit()
		_warning_emitted = true
	
	# Reset flag jika O₂ naik lagi (misal future upgrade)
	if current_o2 / max_o2 > 0.25:
		_warning_emitted = false
	
	if current_o2 <= 0.0:
		is_active = false
		o2_depleted.emit()

func _update_tint(mult: float) -> void:
	# Bar memerah saat polusi membuat O2 terkuras lebih cepat
	if mult >= MULT_HIGH:
		anim.modulate = Color(1.0, 0.55, 0.55)
	elif mult >= MULT_MID:
		anim.modulate = Color(1.0, 0.8, 0.8)
	else:
		anim.modulate = Color(1, 1, 1)

func start_oxygen() -> void:
	max_o2 = GameManager.get_max_o2()  # 60/90/120 sesuai upgrade O2 Tank
	current_o2 = max_o2
	is_active = true
	_warning_emitted = false
	anim.modulate = Color(1, 1, 1)
	anim.frame = 11

func stop_oxygen() -> void:
	is_active = false
