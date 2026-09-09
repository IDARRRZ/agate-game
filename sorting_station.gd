extends Area2D

# Sorting Station (LEGACY) — single-area trigger yang dipakai di iterasi awal.
# Sejak plan Opsi-D-task-1, diganti dengan 3 TrashBin individual di dunia.tscn.
# File ini dipertahankan supaya sorting_station.tscn lama di dunia.tscn tidak crash.
# Behavior: diam, hanya print kalau player masuk area.

var player_in_area: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		print("[SortingStation:LEGACY] Player masuk area sorting. Gunakan 3 TrashBin di dekatnya.")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false
