extends Area2D

const RECYCLING_UI_SCENE := preload("res://recycling_ui.tscn")

var player_in_area: bool = false
var player_ref: Node = null
var ui: CanvasLayer = null
var prompt_label: Label = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	collision_mask = 3
	monitoring = true
	monitorable = true
	ui = RECYCLING_UI_SCENE.instantiate()
	add_child(ui)
	if ui.has_signal("ui_closed"):
		ui.ui_closed.connect(_on_ui_closed)
	_setup_prompt()

func _setup_prompt() -> void:
	prompt_label = Label.new()
	prompt_label.text = "[G] Daur Ulang"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(-70, -80)
	prompt_label.size = Vector2(140, 26)
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.visible = false
	prompt_label.z_index = 20
	add_child(prompt_label)

func _input(event: InputEvent) -> void:
	var is_g = event.is_action_pressed("interact_recycle")
	if not is_g and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_G:
		is_g = true
	if not is_g:
		return
	if not player_in_area:
		var p = get_tree().get_first_node_in_group("player")
		if p and global_position.distance_to(p.global_position) < 100.0:
			player_in_area = true
			player_ref = p
		else:
			return
	toggle_ui()
	get_viewport().set_input_as_handled()

func toggle_ui() -> void:
	if not is_instance_valid(ui):
		print("[RecyclingStation] ERROR ui null")
		return
	if ui.visible:
		close_ui()
	else:
		open_ui()

func open_ui() -> void:
	ui.open_ui()
	_set_player_moving(false)
	print("[RecyclingStation] UI dibuka")

func close_ui() -> void:
	ui.close_ui()

func _on_ui_closed() -> void:
	_set_player_moving(true)
	print("[RecyclingStation] UI ditutup")

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
	print("[RecyclingStation] body_entered ", body.name)
	if body.is_in_group("player") or body.name == "player":
		player_in_area = true
		player_ref = body
		if prompt_label:
			prompt_label.visible = true
		print("[RecyclingStation] Dekat mesin — tekan G untuk daur ulang")

func _on_body_exited(body: Node2D) -> void:
	print("[RecyclingStation] body_exited ", body.name)
	if body.is_in_group("player") or body.name == "player":
		player_in_area = false
		if prompt_label:
			prompt_label.visible = false
		if is_instance_valid(ui) and ui.visible:
			close_ui()
