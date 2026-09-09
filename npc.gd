extends CharacterBody2D

const speed = 30
var current_state = IDLE

var dir = Vector2.RIGHT
var start_pos

var is_roaming = true
var is_chatting = false

var player
var player_in_chat_zone = false

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"

enum {
	IDLE,
	NEW_DIR,
	MOVE
}

func _ready():
	randomize()
	start_pos = position
	$Timer.start()
	$AnimatedSprite2D.play("idle")

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
		push_warning("[NPC] Tidak ada Area2D chat detection!")

func _unhandled_input(event: InputEvent) -> void:
	if is_chatting or not player_in_chat_zone:
		return
	var is_e = event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E)
	if not is_e:
		return
	start_dialogue()
	get_viewport().set_input_as_handled()

func choose(array):
	array.shuffle()
	return array.front()

func _physics_process(delta):
	if is_roaming and !is_chatting:
		move(delta)

func move(delta):
	velocity = dir * speed
	move_and_slide()
	update_animation()

func update_animation():
	if velocity.length() == 0:
		$AnimatedSprite2D.play("idle")
	else:
		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0:
				$AnimatedSprite2D.play("walk_e")
			else:
				$AnimatedSprite2D.play("walk_w")
		else:
			if velocity.y > 0:
				$AnimatedSprite2D.play("walk_s")
			else:
				$AnimatedSprite2D.play("walk_n")

func start_dialogue():
	is_chatting = true
	is_roaming = false
	velocity = Vector2.ZERO
	$AnimatedSprite2D.play("idle")

	var dialogue_title = dialogue_start

	if dialogue_resource:
		DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_title)
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _on_dialogue_ended(_resource):
	is_chatting = false
	is_roaming = true
	DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)

func _on_chat_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "player":
		player = body
		player_in_chat_zone = true

func _on_chat_detection_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "player":
		player_in_chat_zone = false

func _on_timer_timeout() -> void:
	match current_state:
		IDLE:
			current_state = NEW_DIR
			velocity = Vector2.ZERO
			$AnimatedSprite2D.play("idle")
		NEW_DIR:
			current_state = MOVE
			dir = choose([Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN])
		MOVE:
			current_state = IDLE
