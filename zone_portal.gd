extends Area2D

# Zone Portal — berada di dunia.tscn, pindahkan player ke zone berikutnya
# Cek unlock otomatis (GDD BAB 6.C). Jika zone terkunci → tampilkan hint, jangan masuk.

@export var target_scene: String = "res://bawah_laut.tscn"
@export var zone_label: String = "Zone Berikutnya"  # teks UI opsional

var player_in_area: bool = false
var player_ref: Node = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_mask = 3
	monitoring = true

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "player":
		player_in_area = true
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "player":
		player_in_area = false
		player_ref = null

func _input(event: InputEvent) -> void:
	# Backward compat: H key masih jalan
	if not player_in_area:
		return
	if not (event is InputEventKey and event.keycode == KEY_H and event.pressed):
		return
	_advance_zone()

func _advance_zone() -> void:
	var next_zone: String = GameManager.get_next_zone()
	if not GameManager.is_zone_unlocked(next_zone):
		print("[ZonePortal] Zone ", next_zone, " terkunci — butuh ", GameManager.ZONE_UNLOCK_REQ[next_zone] * 100, "% di zone sebelumnya")
		_show_locked_hint(next_zone)
		return

	GameManager.current_zone = next_zone
	GameManager.spawn_at_bridge = false
	print("[ZonePortal] Pindah ke zone: ", next_zone)
	get_tree().change_scene_to_file(target_scene)

func _show_locked_hint(zone: String) -> void:
	# Tampilkan hint lewat pollution overlay (canvas layer) atau cukup print
	# Sederhananya: print. Bisa diperluas dengan popup UI nanti.
	pass