extends Area2D

# Sea Exit — kembali ke surface (dunia)
# Saat kembali, current_zone tetap di zone yang baru saja dikunjungi.

@export var target_scene: String = "res://dunia.tscn"

var player_in_area: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_mask = 3  # detect player (layer 1+2)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = true
		print("[SeaExit] Player detected! PRESS 'H' TO SURFACE")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_area = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_area and event is InputEventKey and event.keycode == KEY_H and event.pressed:
		print("[SeaExit] H Pressed! Changing scene...")
		player_in_area = false
		GameManager.spawn_at_bridge = true
		get_tree().change_scene_to_file(target_scene)
