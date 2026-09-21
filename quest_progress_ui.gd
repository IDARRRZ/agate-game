extends CanvasLayer

# Quest Progress UI — menampilkan progres quest aktif
# Dual mode: Act 1 (Tina quest) atau Act 2 (Marina quest)

@onready var counter_label: Label = $MarginContainer/Label

enum QuestMode { NONE, TINA, MARINA }
var current_mode: QuestMode = QuestMode.NONE

func _ready() -> void:
	# Use call_deferred to ensure GameManager is ready
	call_deferred("_connect_signals")

	# Start hidden
	visible = false
	if counter_label:
		counter_label.add_theme_font_size_override("font_size", 15)
		counter_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		counter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		counter_label.add_theme_constant_override("outline_size", 4)
	print("[QuestUI] Ready, starting hidden")

func _connect_signals() -> void:
	# Connect to GameManager signals
	if GameManager:
		GameManager.quest_started.connect(_on_quest_started)
		GameManager.trash_collected.connect(_on_trash_collected)
		GameManager.quest_completed_signal.connect(_on_quest_completed)
		GameManager.quest_failed_signal.connect(_on_quest_failed)
		GameManager.timer_updated.connect(_on_timer_updated)
		GameManager.marina_quest_progress_changed.connect(_on_marina_progress)
		GameManager.zone_progress_changed.connect(_on_zone_progress_changed)
		print("[QuestUI] Signals connected!")
	else:
		print("[QuestUI] ERROR: GameManager not found!")

func _on_quest_started(_spawn_count: int) -> void:
	print("[QuestUI] Tina quest started - showing UI")
	current_mode = QuestMode.TINA
	visible = true
	update_display()

func _on_trash_collected(_count: int) -> void:
	update_display()

func _on_timer_updated(_time_left: float) -> void:
	if current_mode == QuestMode.TINA:
		update_display()

func _on_quest_completed() -> void:
	if current_mode != QuestMode.TINA:
		return
	if counter_label:
		counter_label.text = "[SUKSES] Quest Selesai! +100"
	await get_tree().create_timer(2.0).timeout
	visible = false
	current_mode = QuestMode.NONE

func _on_quest_failed() -> void:
	if current_mode != QuestMode.TINA:
		return
	if counter_label:
		counter_label.text = "[GAGAL] Waktu Habis!"
	await get_tree().create_timer(2.0).timeout
	visible = false
	current_mode = QuestMode.NONE

func _on_zone_progress_changed() -> void:
	if current_mode == QuestMode.TINA:
		return
	if GameManager.is_all_zones_clean():
		visible = true
		if counter_label:
			counter_label.text = "🏆 SELURUH LAUT 100% PULIH! Bicaralah dengan Tina [E]!"
			counter_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2))
	elif GameManager.marina_quest_completed:
		visible = true
		if counter_label:
			var active_z := GameManager.get_current_healing_zone()
			var z_name := GameManager.get_zone_display_name(active_z)
			var z_pct := GameManager.get_zone_clean_percent(active_z)
			counter_label.text = "🌊 %s: %.0f%% (Target 100%%)" % [z_name, z_pct]
			counter_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))

func _on_marina_progress(_collected: int, _target: int, _sort_correct: int, _sort_target: int) -> void:
	# Hanya tampilkan UI kalau Tina quest tidak aktif
	if current_mode == QuestMode.TINA:
		return
	current_mode = QuestMode.MARINA
	visible = true
	update_marina_display()

func update_display() -> void:
	if current_mode == QuestMode.MARINA:
		update_marina_display()
		return
	if counter_label:
		var trash_text = "Sampah: " + str(GameManager.trash_count) + "/" + str(GameManager.target_trash)
		var timer_text = "Waktu: " + GameManager.get_formatted_time()
		counter_label.text = trash_text + " | " + timer_text
	else:
		print("[QuestUI] ERROR: counter_label is null!")

func update_marina_display() -> void:
	if counter_label:
		var c = GameManager.marina_quest_collected
		var t = GameManager.marina_quest_target
		var sc = GameManager.marina_quest_sort_correct
		var st = GameManager.marina_quest_sort_target
		counter_label.text = "[Marina] Sampah: %d/%d | Sortir: %d/%d" % [c, t, sc, st]
		# Auto-hide kalau quest selesai
		if GameManager.marina_quest_completed:
			counter_label.text = "[SUKSES] Quest Marina Selesai! +%d" % GameManager.QUEST_REWARD
			await get_tree().create_timer(2.5).timeout
			visible = false
			current_mode = QuestMode.NONE
