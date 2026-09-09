extends CanvasLayer

# Air Quality Overlay — Pollution Manager
# Global pollution: 0% (bersih) → 100% (game over)
# Menggunakan ColorRect overlay dengan transisi warna per threshold

@onready var overlay: ColorRect = $ColorRect

# ============================================================
# POLLUTION STATE
# ============================================================

## Level polusi global: 0.0 (bersih) → 100.0 (game over)
var pollution_level: float = 0.0

## Grace period di awal game (60 detik polusi frozen)
const GRACE_PERIOD: float = 60.0
var grace_timer: float = GRACE_PERIOD
var is_grace_active: bool = true

## Rate polusi naik (per detik)
const NATURAL_RATE: float = 0.01        # +0.01%/s → +0.1%/10s
const REJECTED_RATE: float = 0.04       # +0.04%/s → +0.4%/10s (setelah tolak quest)
var current_rate: float = NATURAL_RATE

## Game over
var is_game_over: bool = false

## Transition
var target_color: Color = Color(0, 0, 0, 0)
const LERP_SPEED: float = 4.0

# ============================================================
# SIGNALS
# ============================================================

signal pollution_changed(level: float)
signal threshold_reached(threshold: int)
signal game_over()

# ============================================================
# INIT
# ============================================================

func _ready() -> void:
	# Connect ke GameManager
	if GameManager and GameManager.has_signal("quest_completed_signal"):
		GameManager.quest_completed_signal.connect(_on_quest_completed)
	if GameManager and GameManager.has_signal("quest_failed_signal"):
		GameManager.quest_failed_signal.connect(_on_quest_failed)
	
	# Initial state
	pollution_level = 0.0
	is_grace_active = true
	grace_timer = GRACE_PERIOD
	target_color = Color(0, 0, 0, 0)
	
	if overlay:
		overlay.color = Color(0, 0, 0, 0)
	
	print("[AirQuality] Grace period: ", GRACE_PERIOD, "s")

# ============================================================
# MAIN LOOP
# ============================================================

var _last_active_time: float = 0.0
const NEGLECT_DELAY: float = 120.0

func _is_darat() -> bool:
	var scene = get_tree().current_scene
	if not scene:
		return false
	return scene.name == "dunia" or scene.name == "Dunia"

func _process(delta: float) -> void:
	if is_game_over:
		return
	if not _is_darat():
		return
	
	if is_grace_active:
		grace_timer -= delta
		if grace_timer <= 0.0:
			is_grace_active = false
			grace_timer = 0.0
			print("[AirQuality] Grace selesai! Polusi AI darat mulai.")
		return
	
	var has_active = GameManager.quest_active or GameManager.marina_quest_active
	if has_active:
		_last_active_time = Time.get_ticks_msec() / 1000.0
	
	var neglected: bool = not has_active and (Time.get_ticks_msec() / 1000.0 - _last_active_time) > NEGLECT_DELAY
	current_rate = REJECTED_RATE if neglected else NATURAL_RATE
	
	pollution_level += current_rate * delta
	pollution_level = clampf(pollution_level, 0.0, 100.0)
	
	check_threshold()
	target_color = get_overlay_color(pollution_level)
	if overlay:
		overlay.color = overlay.color.lerp(target_color, LERP_SPEED * delta)
	if pollution_level >= 100.0:
		_game_over()

# ============================================================
# POLLUTION METHODS
# ============================================================

## Tambah polusi (dari aksi buruk player)
func add_pollution(amount: float) -> void:
	if is_game_over or is_grace_active:
		return
	pollution_level = clampf(pollution_level + amount, 0.0, 100.0)
	pollution_changed.emit(pollution_level)
	check_threshold()
	print("[AirQuality] +", amount, "% → ", pollution_level, "%")

## Kurangi polusi (dari aksi baik player)
func reduce_pollution(amount: float) -> void:
	if is_game_over or is_grace_active:
		return
	pollution_level = clampf(pollution_level - amount, 0.0, 100.0)
	pollution_changed.emit(pollution_level)
	print("[AirQuality] -", amount, "% → ", pollution_level, "%")

## Dipanggil saat player tolak quest dari Tina
func on_reject_quest() -> void:
	if is_game_over or is_grace_active:
		return
	add_pollution(0.5)
	# Rate naik 4x lipat (sampai player ambil quest)
	current_rate = REJECTED_RATE
	print("[AirQuality] Tolak quest! Rate naik: ", current_rate, "/s")

## Dipanggil saat player ambil quest (reset rate)
func on_accept_quest() -> void:
	current_rate = NATURAL_RATE
	print("[AirQuality] Quest diterima. Rate: ", current_rate, "/s")

## Dipanggil saat collect trash
func on_collect_trash() -> void:
	reduce_pollution(0.5)

## Dipanggil saat sortir benar
func on_sort_correct() -> void:
	reduce_pollution(1.0)

## Dipanggil saat sortir salah
func on_sort_wrong() -> void:
	add_pollution(1.0)

# ============================================================
# THRESHOLD CHECK
# ============================================================

var _last_threshold: int = 0

func check_threshold() -> void:
	var current_threshold: int = 0
	
	if pollution_level >= 75.0:
		current_threshold = 75
	elif pollution_level >= 50.0:
		current_threshold = 50
	elif pollution_level >= 25.0:
		current_threshold = 25
	
	if current_threshold > _last_threshold:
		threshold_reached.emit(current_threshold)
		_last_threshold = current_threshold
		print("[AirQuality] THRESHOLD ", current_threshold, "%!")
	
	# Reset threshold tracking saat pollution turun di bawah
	if pollution_level < 20.0:
		_last_threshold = 0

# ============================================================
# COLOR MAPPING
# ============================================================

func get_overlay_color(level: float) -> Color:
	if level < 5.0:
		return Color(0, 0, 0, 0)              # Bersih total
	elif level < 15.0:
		return Color(0.1, 0.1, 0.1, 0.15)     # Sedikit keruh
	elif level < 25.0:
		return Color(0.1, 0.1, 0.1, 0.30)     # Keruh
	elif level < 50.0:
		return Color(0.05, 0.05, 0.05, 0.50)  # Agak gelap
	elif level < 75.0:
		return Color(0, 0, 0, 0.70)            # Gelap
	elif level < 90.0:
		return Color(0, 0, 0, 0.85)            # Sangat gelap
	else:
		return Color(0, 0, 0, 0.95)             # Hampir hitam

# ============================================================
# GAME OVER
# ============================================================

func _game_over() -> void:
	is_game_over = true
	pollution_level = 100.0

	if overlay:
		var tween = create_tween()
		tween.tween_property(overlay, "color", Color(0, 0, 0, 1), 0.5)

	await get_tree().create_timer(1.0).timeout

	restart()
	GameManager.reset_for_respawn()

	get_tree().change_scene_to_file("res://dunia.tscn")

## Restart game (reset semua state)
func restart() -> void:
	pollution_level = 0.0
	grace_timer = GRACE_PERIOD
	is_grace_active = true
	is_game_over = false
	current_rate = NATURAL_RATE
	_last_threshold = 0
	target_color = Color(0, 0, 0, 0)
	
	if overlay:
		overlay.color = Color(0, 0, 0, 0)
	
	print("[AirQuality] Restarted")

# ============================================================
# QUEST COMPLETION (reuse dari existing)
# ============================================================

func _on_quest_completed() -> void:
	reduce_pollution(5.0)
	print("[AirQuality] Quest selesai! Pollution -5%")

func _on_quest_failed() -> void:
	is_grace_active = false
	grace_timer = 0.0
	pollution_level = clampf(pollution_level + 10.0, 0.0, 100.0)
	current_rate = REJECTED_RATE
	pollution_changed.emit(pollution_level)
	print("[AirQuality] Quest gagal! +10% pollution, rate: ", current_rate, "/s")

# DEBUG: hanya print state, tidak ada P/N input
