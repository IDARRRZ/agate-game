extends CharacterBody2D

# Player Swimming Controller
# Smooth 360 degree movement underwater

const SPEED = 150.0
const ACCELERATION = 400.0
const FRICTION = 300.0

# State
var input_direction: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT

# Repair/Interact system
var nearby_coral: Array = []

# Trash collection (Act 2 underwater)
var nearby_trash: Array = []

# Hurt system
var hurt_timer: float = 0.0
var is_hurt_active: bool = false
var is_hurt_playing: bool = false
const HURT_INTERVAL: float = 2.0

@onready var oxygen = $Oxygen

# HUD label untuk jumlah sampah dibawa
var trash_hud: Label

func _ready() -> void:
	add_to_group("player") # Ensure detection
	var anim = get_animasi()
	if anim:
		anim.play("swim_idle")
	
	oxygen.o2_depleted.connect(_return_to_surface)
	oxygen.o2_low_warning.connect(_on_o2_low)
	oxygen.start_oxygen()

	_setup_trash_hud()
	_update_trash_hud()
	GameManager.trash_carried_changed.connect(_update_trash_hud)
	GameManager.marina_met_changed.connect(_update_trash_hud)

func _setup_trash_hud() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	trash_hud = Label.new()
	trash_hud.name = "TrashHud"
	trash_hud.position = Vector2(12, 12)
	trash_hud.add_theme_font_size_override("font_size", 28)
	trash_hud.add_theme_color_override("font_color", Color(1, 1, 1))
	trash_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	trash_hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(trash_hud)

func _update_trash_hud() -> void:
	if trash_hud and trash_hud.is_inside_tree():
		if GameManager.marina_met:
			var total = GameManager.get_carried_count()
			trash_hud.text = "Sampah: %d/%d" % [total, GameManager.bag_capacity]
			trash_hud.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			trash_hud.text = "KUNCI: Temui Marina"
			trash_hud.add_theme_color_override("font_color", Color(1, 0.85, 0.2))

func _on_o2_low():
	is_hurt_active = true
	hurt_timer = 0.0

func _return_to_surface():
	is_hurt_active = false
	GameManager.spawn_at_bridge = true
	get_tree().change_scene_to_file("res://dunia.tscn")

func get_animasi():
	return $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	# Hurt periodic timer
	if is_hurt_active:
		hurt_timer += delta
		if hurt_timer >= HURT_INTERVAL:
			hurt_timer = 0.0
			play_hurt_animation()
	
	# Get input direction (WASD / Arrow keys)
	input_direction = Vector2.ZERO
	input_direction.x = Input.get_axis("ui_left", "ui_right")
	input_direction.y = Input.get_axis("ui_up", "ui_down")
	
	# Normalize untuk 360 degree movement yang konsisten
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()
		facing_direction = input_direction
		
		# Smooth acceleration
		velocity = velocity.move_toward(input_direction * SPEED, ACCELERATION * delta)
		
		# Update animation dan rotation
		update_swim_animation()
	else:
		# Smooth deceleration (friction in water)
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		
		# Idle animation saat berhenti
		var anim = get_animasi()
		if anim and velocity.length() < 10 and not is_hurt_playing:
			anim.play("swim_idle")
	
	# Move
	move_and_slide()
	
	# Rotate sprite to face movement direction
	update_sprite_rotation()

func update_swim_animation() -> void:
	var anim = get_animasi()
	if not anim:
		return
	if is_hurt_playing:
		return
	# Play swimming animation
	if anim.animation != "swim":
		anim.play("swim")

func update_sprite_rotation() -> void:
	var anim = get_animasi()
	if not anim:
		return
	
	# Rotate sprite berdasarkan arah gerak
	if velocity.length() > 10:
		var angle = facing_direction.angle()
		
		# Flip horizontal jika menghadap kiri
		if facing_direction.x < 0:
			anim.scale.x = -1
			# Adjust rotation untuk sprite yang di-flip
			anim.rotation = -angle - PI
		else:
			anim.scale.x = 1
			anim.rotation = angle

func play_hurt_animation() -> void:
	var anim = get_animasi()
	if not anim or not anim.sprite_frames.has_animation("hurt_swim"):
		return
	
	is_hurt_playing = true
	
	var frames = anim.sprite_frames
	frames.set_animation_loop("hurt_swim", false)
	anim.stop()
	anim.play("hurt_swim")
	
	await anim.animation_finished
	
	is_hurt_playing = false
	
	if is_instance_valid(anim):
		if velocity.length() > 10:
			anim.play("swim")
		else:
			anim.play("swim_idle")

func _input(event: InputEvent) -> void:
	# F key - repair coral, atau collect sampah jika dekat sampah
	if event.is_action_pressed("pickup"):
		if nearby_coral.size() > 0:
			try_repair_coral()
		elif nearby_trash.size() > 0:
			try_pickup_trash()
	
	# M1 - collect trash dulu; jika tidak ada, repair animation
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if nearby_trash.size() > 0:
				try_pickup_trash()
			else:
				var facing_horizontal = abs(facing_direction.x) > abs(facing_direction.y)
				if facing_horizontal:
					play_repair_animation()

func play_repair_animation() -> void:
	var anim = get_animasi()
	if not anim:
		return
	
	# Pastikan tidak loop
	var frames = anim.sprite_frames
	if frames and frames.has_animation("repair"):
		frames.set_animation_loop("repair", false)
		anim.stop()
		anim.play("repair")
	else:
		# Fallback ke swim jika tidak ada animasi repair
		anim.play("swim")

func try_repair_coral() -> void:
	if nearby_coral.size() > 0:
		var coral = nearby_coral[0]
		if is_instance_valid(coral) and coral.has_method("repair"):
			play_repair_animation()
			coral.repair()
			print("[PlayerSwim] Coral repaired!")

# Coral detection
func register_nearby_coral(coral: Node) -> void:
	if not nearby_coral.has(coral):
		nearby_coral.append(coral)
		print("[PlayerSwim] Coral nearby - Press F to repair")

func unregister_nearby_coral(coral: Node) -> void:
	nearby_coral.erase(coral)

# Trash detection & pickup
func register_nearby_trash(trash: Node) -> void:
	if not nearby_trash.has(trash):
		nearby_trash.append(trash)

func unregister_nearby_trash(trash: Node) -> void:
	nearby_trash.erase(trash)

func try_pickup_trash() -> void:
	if nearby_trash.size() == 0:
		return

	# Gate: koleksi sampah hanya bisa setelah Marina membuka Act 2
	if not GameManager.marina_met:
		AudioManager.play_sfx("error")
		print("[PlayerSwim] Kunci: Bicaralah dengan Marina dulu")
		return

	# Hint: jika quest Marina belum diambil
	if not GameManager.marina_quest_active and not GameManager.marina_quest_completed:
		print("[PlayerSwim] Hint: Bicara dengan Marina untuk mengambil quest pertama.")

	var trash = nearby_trash[0]
	if not is_instance_valid(trash):
		nearby_trash.erase(trash)
		return

	var trash_type: String = ""
	if "trash_type" in trash:
		trash_type = str(trash.trash_type)
	if GameManager.collect_underwater_trash(trash_type):
		AirQuality.on_collect_trash()
		trash.queue_free()
		nearby_trash.erase(trash)
		AudioManager.play_sfx("pickup")
		print("[PlayerSwim] Sampah diambil: ", trash_type)
	else:
		AudioManager.play_sfx("error")
