extends CharacterBody2D

const speed = 30
var current_state = IDLE

var dir = Vector2.RIGHT
var start_pos

var is_roaming = false
var is_chatting = false

var player
var player_in_chat_zone = false
var _ending_triggered: bool = false
var _showing_poem: bool = false

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"

enum {
	IDLE
}

func _ready():
	randomize()
	start_pos = position
	$AnimatedSprite2D.play("idle")
	
	if not dialogue_resource:
		if ResourceLoader.exists("res://tina_dialogue.dialogue"):
			dialogue_resource = load("res://tina_dialogue.dialogue")
		elif ResourceLoader.exists("res://npc_dialogue.dialogue"):
			dialogue_resource = load("res://npc_dialogue.dialogue")
	
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	
	var area = get_node_or_null("area_chat_detection")
	if not area:
		area = get_node_or_null("chat_detection_area")
	if area:
		area.collision_mask = 3
		area.monitoring = true
		area.monitorable = true
		if not area.body_entered.is_connected(_on_chat_detection_area_body_entered):
			area.body_entered.connect(_on_chat_detection_area_body_entered)
		if not area.body_exited.is_connected(_on_chat_detection_area_body_exited):
			area.body_exited.connect(_on_chat_detection_area_body_exited)
		print("[Tina] Area OK: ", area.name)

func choose(array):
	array.shuffle()
	return array.front()

func _unhandled_input(event: InputEvent) -> void:
	if is_chatting or not player_in_chat_zone:
		return
	var is_e = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E)
	if not is_e:
		return
	start_dialogue()
	get_viewport().set_input_as_handled()

func start_dialogue():
	print("Starting Tina dialogue...")
	is_chatting = true
	$AnimatedSprite2D.play("idle")

	var dialogue_title = "start"

	if GameManager.is_all_zones_clean():
		dialogue_title = "ending"
	elif GameManager.coral_repaired:
		if GameManager.marina_quest_completed:
			dialogue_title = "marina_quest_done"
		elif GameManager.marina_met and GameManager.marina_quest_active:
			dialogue_title = "marina_quest_active"
		elif GameManager.marina_met:
			dialogue_title = "quest_completed_first"
		else:
			dialogue_title = "go_meet_marina"
	elif GameManager.quest_failed:
		dialogue_title = "quest_failed"
	elif GameManager.quest_completed:
		dialogue_title = "quest_completed_first"
	elif GameManager.quest_active:
		if GameManager.can_complete_quest():
			dialogue_title = "quest_ready_complete"
		else:
			dialogue_title = "quest_in_progress"

	if dialogue_resource:
		print("Tina dialogue showing: ", dialogue_title)
		DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_title)
		is_chatting = true
	else:
		print("ERROR: dialogue_resource is null!")
		is_chatting = false

func _on_dialogue_ended(_resource):
	print("Tina dialogue ended")
	is_chatting = false

	if _showing_poem:
		_showing_poem = false
		print("[Tina] Puisi selesai dibaca! Menyimpan file dan keluar.")
		GameManager.save_poem_to_txt()
		return

	if GameManager.is_all_zones_clean() and not _ending_triggered:
		_ending_triggered = true
		_showing_poem = true
		print("[Tina] Ending triggered! Menampilkan puisi...")
		var trigger = get_tree().root.find_child("NarrationTrigger", true, false)
		if trigger and trigger.has_method("show_ending"):
			trigger.show_ending()
		else:
			GameManager.save_poem_to_txt()

func _on_chat_detection_area_body_entered(body: Node2D) -> void:
	print("Body entered Tina zone: ", body.name)
	if body.is_in_group("player") or body.name == "player":
		player = body
		player_in_chat_zone = true
		print("[Tina] Player IN zone")

func _on_chat_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "player":
		player_in_chat_zone = false
		print("[Tina] Player OUT zone")


func _on_timer_timeout() -> void:
	pass # Replace with function body.
