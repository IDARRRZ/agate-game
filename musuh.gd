extends CharacterBody2D

# Musuh dasar (hiu / swordfish) — chase player, damage O2 + knockback
# Hanya aktif di Open Ocean & Deep Sea (GDD BAB 5.B) — dicek oleh spawner/scene

const DAMAGE_O2 := 30.0
const CHASE_SPEED := 70.0
const KNOCKBACK_FORCE := 220.0
const ATTACK_COOLDOWN := 0.6

@export var chase_range: float = 220.0
@export var damage_cooldown: float = 0.8

var player_ref: Node = null
var _last_attack_time: float = 0.0

func _ready() -> void:
	add_to_group("musuh")
	# Connect ke detection area (sub-node di scene)
	var area = get_node_or_null("DetectionArea")
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player_ref):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist > chase_range:
		# Return to idle, drift slowly
		velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
	else:
		# Chase
		var dir: Vector2 = (player_ref.global_position - global_position).normalized()
		velocity = velocity.move_toward(dir * CHASE_SPEED, 200.0 * delta)

	# Face movement direction
	if velocity.length() > 5.0:
		scale.x = -1.0 if velocity.x < 0 else 1.0

	move_and_slide()

	# Damage on contact
	if has_overlapping_player() and _can_attack():
		_attack_player()

func has_overlapping_player() -> bool:
	var area = get_node_or_null("HurtArea")
	if not area:
		return false
	for body in area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false

func _can_attack() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return (now - _last_attack_time) >= damage_cooldown

func _attack_player() -> void:
	_last_attack_time = Time.get_ticks_msec() / 1000.0
	if not is_instance_valid(player_ref):
		return

	# Damage O2
	player_ref.oxygen.current_o2 = maxf(0.0, player_ref.oxygen.current_o2 - DAMAGE_O2)
	AudioManager.play_sfx("error")

	# Trigger hurt flash
	if player_ref.has_method("play_hurt_animation"):
		player_ref.play_hurt_animation()

	# Knockback
	if "velocity" in player_ref:
		var kb_dir: Vector2 = (player_ref.global_position - global_position).normalized()
		player_ref.velocity = kb_dir * KNOCKBACK_FORCE

	print("[Musuh] Hit player — O2 -30")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body == player_ref:
		player_ref = null