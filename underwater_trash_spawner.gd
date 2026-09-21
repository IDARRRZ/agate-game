extends Node2D

# Underwater Trash Spawner — spawn 3 jenis sampah di posisi acak area perairan
# Spawning di-defer agar physics space siap sebelum query validasi.
# Jumlah trash & area spawn mengikuti zone (deep sea lebih banyak, area lebih luas).

const TRASH_SCENES: Array[PackedScene] = [
	preload("res://sampah_buah.tscn"),
	preload("res://sampah_logam.tscn"),
	preload("res://plastik_laut.tscn")
]

@export var spawn_count: int = 26
@export var spawn_area_min: Vector2 = Vector2(80, 150)
@export var spawn_area_max: Vector2 = Vector2(1750, 1180)
@export var max_attempts: int = 10

var _respawn_timer: float = 0.0
const RESPAWN_CHECK_INTERVAL := 8.0
const MIN_TRASH_THRESHOLD := 6

func _ready() -> void:
	call_deferred("_spawn_all")

func _process(delta: float) -> void:
	_respawn_timer += delta
	if _respawn_timer >= RESPAWN_CHECK_INTERVAL:
		_respawn_timer = 0.0
		_check_respawn()

func _check_respawn() -> void:
	var current_trash_count := get_tree().get_nodes_in_group("trash").size()
	if current_trash_count < MIN_TRASH_THRESHOLD:
		# Respawn 4 sampah baru di perairan
		for i in range(4):
			_spawn_one()
		print("[TrashSpawner] Respawn 4 sampah baru (sisa sebelumnya: ", current_trash_count, ")")

func _spawn_all() -> void:
	# Bagi sebaran sampah merata di 3 zona kedalaman
	var depths := [
		{"min_y": 180.0, "max_y": 650.0, "count": 9},   # Terumbu Karang
		{"min_y": 650.0, "max_y": 950.0, "count": 9},   # Samudra Lepas
		{"min_y": 950.0, "max_y": 1180.0, "count": 8},  # Palung Laut
	]
	for layer in depths:
		for i in range(layer["count"]):
			_spawn_in_range(layer["min_y"], layer["max_y"])

func _spawn_in_range(min_y: float, max_y: float) -> void:
	var scene: PackedScene = TRASH_SCENES.pick_random()
	var trash = scene.instantiate()
	var pos := Vector2(
		randf_range(spawn_area_min.x, spawn_area_max.x),
		randf_range(min_y, max_y)
	)
	trash.position = pos
	get_parent().add_child(trash)

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
