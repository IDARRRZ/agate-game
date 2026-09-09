extends CharacterBody2D

var is_chatting: bool = false
var player_in_chat_zone: bool = false
var player: Node = null

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"

func _ready() -> void:
	if not dialogue_resource:
		if ResourceLoader.exists("res://marina.dialogue"):
			dialogue_resource = load("res://marina.dialogue")

	var area = get_node_or_null("area_chat_detection")
	if not area:
		area = get_node_or_null("chat_detection_area")
	if area:
		area.collision_mask = 3
		area.monitoring = true
		if not area.body_entered.is_connected(_on_chat_detection_area_body_entered):
			area.body_entered.connect(_on_chat_detection_area_body_entered)
		if not area.body_exited.is_connected(_on_chat_detection_area_body_exited):
			area.body_exited.connect(_on_chat_detection_area_body_exited)
	else:
		push_warning("[Marina] Tidak ada Area2D chat detection!")

	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _unhandled_input(event: InputEvent) -> void:
	if is_chatting or not player_in_chat_zone:
		return
	var is_e = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E)
	if not is_e:
		return
	start_dialogue()
	get_viewport().set_input_as_handled()

func start_dialogue() -> void:
	print("[Marina] Starting Marina dialogue...")
	is_chatting = true

	var dialogue_title = dialogue_start

	if not GameManager.coral_repaired:
		dialogue_title = "coral_first"
	elif GameManager.marina_quest_active and not GameManager.marina_quest_completed:
		dialogue_title = "quest_progress"
	elif GameManager.marina_quest_completed:
		dialogue_title = "quest_done"
	elif not GameManager.marina_met:
		dialogue_title = "start"
	else:
		dialogue_title = "meet_again"

	if dialogue_resource:
		print("[Marina] Dialogue showing: ", dialogue_title)
		DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_title)
	else:
		print("[Marina] ERROR: dialogue_resource is null!")
		is_chatting = false

func _on_dialogue_ended(_resource) -> void:
	print("[Marina] Dialogue ended")
	is_chatting = false

func _on_chat_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "player":
		player = body
		player_in_chat_zone = true
		print("[Marina] Player masuk area chat")

func _on_chat_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "player":
		player_in_chat_zone = false
		print("[Marina] Player keluar area chat")
