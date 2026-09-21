extends Node2D

# Referensi tombol via Unique Name (sesuai di scene tree)
@onready var start_btn = $Control/Button
@onready var exit_btn = $Control/Button2

func _ready() -> void:
	# Connect signals
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)

func _on_start_pressed() -> void:
	if Engine.has_singleton("AudioManager") or get_tree().root.has_node("AudioManager"):
		AudioManager.play_sfx("click")
	var dcm = get_node_or_null("/root/DayCycleManager")
	if dcm:
		dcm.current_day = 1
		dcm.current_time_hours = dcm.MORNING_HOUR
		dcm.pending_sleep_on_surface = false
		dcm.is_sleeping = false
	print("[MMM] Starting Game...")
	get_tree().change_scene_to_file("res://dunia.tscn")

func _on_exit_pressed() -> void:
	# Play Sound
	if Engine.has_singleton("AudioManager") or get_tree().root.has_node("AudioManager"):
		AudioManager.play_sfx("click")
		
	# Quit
	print("[MMM] Exiting Game...")
	get_tree().quit()
