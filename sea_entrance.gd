extends Area2D

# Sea Entrance — pindah ke zone laut tertentu
# Bisa berfungsi sebagai "advance zone" jika player unlock zone berikutnya.

@export var target_scene: String = "res://bawah_laut.tscn"
@export var enter_zone: String = "beach"   # zone yang dituju saat masuk
@export var is_advance_portal: bool = false # true = portal untuk advance ke zone berikutnya

var player_in_area: bool = false
var player_ref: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_mask = 3  # detect player (layer 1+2)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		player_ref = body
		print("[SeaEntrance] Player masuk area - Tekan H untuk menyelam")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
		player_ref = null

func _input(event: InputEvent) -> void:
	if player_in_area and event is InputEventKey and event.keycode == KEY_H and event.pressed:
		var target_zone := _resolve_target_zone()
		if target_zone == "":
			return
		GameManager.current_zone = target_zone
		GameManager.spawn_at_bridge = false
		print("[SeaEntrance] Menyelam ke zone: ", target_zone)
		get_tree().change_scene_to_file(target_scene)

func _resolve_target_zone() -> String:
	if is_advance_portal:
		var next_zone := GameManager.get_next_zone()
		if GameManager.is_zone_unlocked(next_zone) and next_zone != GameManager.current_zone:
			return next_zone
		print("[SeaEntrance] Zone berikutnya terkunci atau sudah zone terakhir")
		return ""
	return enter_zone