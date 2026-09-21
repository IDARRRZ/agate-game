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
var hint_hud: Label

func _ready() -> void:
	add_to_group("player") # Ensure detection
	var anim = get_animasi()
	if anim:
		anim.rotation = 0.0
		anim.scale = Vector2(1.0, 1.0)
		_play_idle(anim)
	
	oxygen.o2_depleted.connect(_return_to_surface)
	oxygen.o2_low_warning.connect(_on_o2_low)
	oxygen.start_oxygen()

	_setup_trash_hud()
	_update_trash_hud()
	GameManager.trash_carried_changed.connect(_update_trash_hud)
	GameManager.marina_met_changed.connect(_update_trash_hud)
	GameManager.zone_progress_changed.connect(_update_trash_hud)
	GameManager.marina_quest_progress_changed.connect(func(_a,_b,_c,_d): _update_trash_hud())

func _setup_trash_hud() -> void:
	var layer = CanvasLayer.new()
	layer.layer = 95
	add_child(layer)
	trash_hud = Label.new()
	trash_hud.name = "TrashHud"
	trash_hud.position = Vector2(16, 14)
	trash_hud.add_theme_font_size_override("font_size", 24)
	trash_hud.add_theme_color_override("font_color", Color(1, 1, 1))
	trash_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	trash_hud.add_theme_constant_override("outline_size", 4)
	layer.add_child(trash_hud)

	hint_hud = Label.new()
	hint_hud.name = "HintHud"
	hint_hud.position = Vector2(16, 44)
	hint_hud.add_theme_font_size_override("font_size", 16)
	hint_hud.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	hint_hud.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint_hud.add_theme_constant_override("outline_size", 3)
	layer.add_child(hint_hud)

func _update_trash_hud() -> void:
	if not trash_hud or not trash_hud.is_inside_tree():
		return
	if not GameManager.marina_met:
		trash_hud.text = "KUNCI: Temui Marina di karang kanan"
		trash_hud.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		if hint_hud:
			hint_hud.text = "Berenang ke kanan bawah untuk bicara dengan Marina"
			hint_hud.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	else:
		var total: int = GameManager.get_carried_count()
		if GameManager.marina_quest_active and not GameManager.marina_quest_completed:
			var target: int = GameManager.marina_quest_target
			var collected: int = GameManager.marina_quest_collected
			trash_hud.text = "Sampah Tas: %d/%d  |  Quest Marina: %d/%d" % [total, GameManager.bag_capacity, collected, target]
			trash_hud.add_theme_color_override("font_color", Color(1, 1, 1))
			if hint_hud:
				if collected >= target:
					hint_hud.text = "✅ Target 5/5 terpenuhi! Berenang ke pintu keluar (kiri atas [H]) untuk memilah."
					hint_hud.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
				else:
					hint_hud.text = "Ambil sampah laut dengan menekan [F] saat mendekatinya."
					hint_hud.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
		else:
			trash_hud.text = "Sampah Tas: %d/%d" % [total, GameManager.bag_capacity]
			trash_hud.add_theme_color_override("font_color", Color(1, 1, 1))
			if hint_hud:
				if GameManager.is_all_zones_clean():
					hint_hud.text = "🏆 Seluruh Samudra 100% Bersih! Bicaralah dengan Tina di dermaga [E]!"
					hint_hud.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
				elif total >= GameManager.bag_capacity:
					hint_hud.text = "Tas penuh! Kembali ke darat (pintu keluar kiri atas) untuk memilah."
					hint_hud.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
				else:
					var active_z := GameManager.get_current_healing_zone()
					var z_name := GameManager.get_zone_display_name(active_z)
					var z_pct := GameManager.get_zone_clean_percent(active_z)
					hint_hud.text = "Pulihkan: %s (%.0f%%)  |  Ambil sampah [F], bawa ke darat [R]" % [z_name, z_pct]
					hint_hud.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))

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
			_play_idle(anim)
	
	# Move
	move_and_slide()
	
	# Rotate sprite to face movement direction
	update_sprite_rotation(delta)

func _play_idle(anim: AnimatedSprite2D) -> void:
	if not anim or not anim.sprite_frames:
		return
	if anim.sprite_frames.has_animation("idle_swim"):
		anim.play("idle_swim")
	elif anim.sprite_frames.has_animation("swim_idle"):
		anim.play("swim_idle")

func update_swim_animation() -> void:
	var anim = get_animasi()
	if not anim or is_hurt_playing or not anim.sprite_frames:
		return
	
	# Jika berenang ke atas
	if facing_direction.y < -0.4 and abs(facing_direction.y) > abs(facing_direction.x):
		if anim.sprite_frames.has_animation("swim_up"):
			if anim.animation != "swim_up":
				anim.play("swim_up")
			return
	
	# Berenang maju / horizontal
	var forward_anim := "swim_idle" if anim.sprite_frames.has_animation("swim_idle") else "swim"
	if anim.sprite_frames.has_animation(forward_anim) and anim.animation != forward_anim:
		anim.play(forward_anim)

func update_sprite_rotation(_delta: float = 0.0) -> void:
	var anim = get_animasi()
	if not anim or is_hurt_playing:
		return
	
	# Rotasi selalu tegak natural (0.0) agar pixel art rapi tanpa miring atau distorsi
	anim.rotation = 0.0
	anim.scale.y = 1.0
	
	# Balik arah kiri / kanan sesuai arah hadap
	if facing_direction.x < -0.05:
		anim.scale.x = -1.0
	elif facing_direction.x > 0.05:
		anim.scale.x = 1.0

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
			update_swim_animation()
		else:
			_play_idle(anim)

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
		# Fallback jika tidak ada animasi repair
		update_swim_animation()

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
