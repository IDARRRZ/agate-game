extends Area2D

const SORTING_UI_SCENE := preload("res://sorting_station_ui.tscn")

@export var bin_type: String = "plastik"
@export var icon_texture: Texture2D

var player_in_range: bool = false
var player_ref: Node = null
var ui: CanvasLayer = null
var prompt_label: Label = null

func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 1
	collision_mask = 3
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	ui = SORTING_UI_SCENE.instantiate()
	add_child(ui)
	if ui.has_signal("ui_closed"):
		ui.ui_closed.connect(_on_ui_closed)
	if icon_texture:
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.texture = icon_texture

	_setup_prompt()

func _setup_prompt() -> void:
	prompt_label = Label.new()
	prompt_label.text = "[R] Pilah Sampah"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-70, -75)
	prompt_label.size = Vector2(140, 26)
	prompt_label.add_theme_font_size_override("font_size", 13)
	prompt_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.visible = false
	prompt_label.z_index = 20
	add_child(prompt_label)

func _input(event: InputEvent) -> void:
	var is_r = event.is_action_pressed("interact_sort")
	if not is_r and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			is_r = true
	if not is_r:
		return
	var p = get_tree().get_first_node_in_group("player")
	var dist = 9999.0
	if p:
		dist = global_position.distance_to(p.global_position)
	print("[TrashBin] R received bin=", bin_type, " in_range=", player_in_range, " dist=", int(dist), " ui_vis=", ui.visible if is_instance_valid(ui) else "null")
	if not player_in_range:
		if p and dist < 150.0:
			player_in_range = true
			player_ref = p
			print("[TrashBin] fallback jarak <150 -> in_range true")
		else:
			print("[TrashBin] ignore R out of range")
			return
	toggle_ui()
	get_viewport().set_input_as_handled()

func toggle_ui() -> void:
	if not is_instance_valid(ui):
		print("[TrashBin] ERROR ui null")
		return
	if ui.visible:
		print("[TrashBin] toggle close")
		close_ui()
	else:
		print("[TrashBin] toggle open")
		open_ui()

func open_ui() -> void:
	var carried := GameManager.get_carried_count()
	print("[TrashBin] open_ui carried=", carried)
	if carried <= 0:
		print("[TrashBin] Tas kosong — bawa 5 dari laut dulu (Marina). UI tetap terbuka untuk lihat.")
	GameManager.highlighted_bin = bin_type
	ui.open_ui(bin_type)
	_set_player_moving(false)
	print("[TrashBin] UI dibuka via R — bin ", bin_type, " carried=", carried)

func close_ui() -> void:
	if is_instance_valid(ui) and ui.visible:
		ui.close_ui()
		print("[TrashBin] close_ui called")

func _on_ui_closed() -> void:
	GameManager.highlighted_bin = ""
	_set_player_moving(true)
	print("[TrashBin] UI ditutup")

func _set_player_moving(can_move: bool) -> void:
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
	if player_ref:
		player_ref.set("can_move", can_move)
		if not can_move:
			player_ref.set("velocity", Vector2.ZERO)
			if player_ref.has_method("change_state"):
				player_ref.change_state("idle")

func _on_body_entered(body: Node2D) -> void:
	print("[TrashBin] body_entered ", body.name, " bin=", bin_type)
	if body.is_in_group("player") or body.name == "player":
		player_in_range = true
		player_ref = body
		if prompt_label:
			prompt_label.visible = true
		print("[TrashBin] Dekat bin ", bin_type, " — tekan R untuk sortir")

func _on_body_exited(body: Node2D) -> void:
	print("[TrashBin] body_exited ", body.name, " bin=", bin_type)
	if body.is_in_group("player") or body.name == "player":
		player_in_range = false
		if prompt_label:
			prompt_label.visible = false
		if is_instance_valid(ui) and ui.visible:
			close_ui()
