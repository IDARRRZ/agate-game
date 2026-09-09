extends Node2D

# Underwater Trash Spawner — spawn 3 jenis sampah di posisi acak area perairan
# Spawning di-defer agar physics space siap sebelum query validasi.
# Jumlah trash & area spawn mengikuti zone (deep sea lebih banyak, area lebih luas).

const TRASH_SCENES: Array[PackedScene] = [
	preload("res://sampah_buah.tscn"),
	preload("res://sampah_logam.tscn"),
	preload("res://plastik_laut.tscn")
]

@export var spawn_count: int = 12
@export var spawn_area_min: Vector2 = Vector2(150, 250)
@export var spawn_area_max: Vector2 = Vector2(1150, 620)
@export var max_attempts: int = 10

# Spawn tambahan khusus zone lebih dalam (Open Ocean / Deep Sea)
const EXTRA_TRASH_BY_ZONE := {
	"beach": 0,
	"coral_reef": 0,
	"open_ocean": 6,
	"deep_sea": 12,
}

func _ready() -> void:
	# Tambah jumlah trash sesuai zone aktif
	var zone: String = GameManager.current_zone
	spawn_count += EXTRA_TRASH_BY_ZONE.get(zone, 0)
	call_deferred("_spawn_all")

func _spawn_all() -> void:
	for i in range(spawn_count):
		_spawn_one()

func _spawn_one() -> void:
	var scene: PackedScene = TRASH_SCENES.pick_random()
	var trash = scene.instantiate()
	var pos := _random_valid_position()
	if pos == Vector2.INF:
		# Fallback: jika validasi gagal semua, tetap spawn di titik acak dalam area
		pos = Vector2(
			randf_range(spawn_area_min.x, spawn_area_max.x),
			randf_range(spawn_area_min.y, spawn_area_max.y)
		)
	trash.position = pos
	get_parent().add_child(trash)

func _random_valid_position() -> Vector2:
	for i in range(max_attempts):
		var candidate := Vector2(
			randf_range(spawn_area_min.x, spawn_area_max.x),
			randf_range(spawn_area_min.y, spawn_area_max.y)
		)
		if _is_valid_position(candidate):
			return candidate
	return Vector2.INF

func _is_valid_position(pos: Vector2) -> bool:
	var world := get_world_2d()
	if world == null:
		return true
	var space_state = world.direct_space_state
	if space_state == null:
		return true
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return space_state.intersect_point(query).is_empty()
