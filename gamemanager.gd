extends Node

# Quest State
var quest_active: bool = false
var quest_completed: bool = false
var quest_failed: bool = false
var quest_times_completed: int = 0

# Trash Collection
var trash_count: int = 0
var target_trash: int = 10

# Timer
var quest_time_limit: float = 180.0  # 3 minutes default
var time_remaining: float = 0.0
var timer_active: bool = false

# Score
var score: int = 0

# === COIN SYSTEM ===
var coins: int = 0
const SAVE_PATH = "user://coins.txt"
const QUEST_REWARD = 100  # Coin reward per quest

# Spawn Position Management
var spawn_at_bridge: bool = false
var intro_shown: bool = false

# === INVENTORY (Simple) ===
var inventory = {
	"besi": 0,
	"pasir": 0,
	"cable_ties": 0
}

# === UNDERWATER TRASH BAG (Act 2) ===
# Sampah yang dibawa saat menyelam, dipilah di Sorting Station
var carried_trash = {
	"plastik": 0,
	"logam": 0,
	"organik": 0
}
var bag_capacity: int = 10

# Bin yang sedang di-highlight di Sorting UI (kosong = tidak ada highlight)
var highlighted_bin: String = ""

# Material hasil sortir benar — dipakai Phase C (Recycling)
var recycled_material = {
	"plastik": 0,
	"logam": 0,
	"organik": 0
}

# Produk jadi hasil recycle sukses — dipakai Phase D (Upgrade Shop)
var finished_products = {
	"plastik": 0,
	"logam": 0,
	"organik": 0
}

# === UPGRADE EQUIPMENT (Phase D) ===
const O2_BASE := 60.0
const O2_PER_LEVEL := 30.0
const O2_MAX_LEVEL := 2
const BAG_BASE := 10
const BAG_PER_LEVEL := 5
const BAG_MAX_LEVEL := 2

# Biaya per level (index = level saat ini): dibayar dengan finished_products
const UPGRADE_COSTS = {
	"o2_tank": [
		{"plastik": 2, "logam": 1},
		{"logam": 3, "plastik": 1},
	],
	"bag": [
		{"organik": 2, "plastik": 1},
		{"organik": 3, "logam": 1},
	],
}

var o2_tank_level: int = 0
var bag_level: int = 0

# === MARINA QUEST (Act 2: daily quest dari guru sorting) ===
# Setelah quest daratan Tina + repair coral, player bertemu Marina.
# Marina memberi quest kumpulkan 5 sampah (campuran) dari laut,
# lalu sortir dengan benar. Act 2 bebas loop setelah ini.
var marina_quest_active: bool = false
var marina_quest_completed: bool = false
var marina_quest_target: int = 5
var marina_quest_collected: int = 0
var marina_quest_sort_correct: int = 0
var marina_quest_sort_target: int = 3

# === 3 OCEAN ZONE SYSTEM (Dermaga → Laut) ===
# Coral Reef (Free dari awal, area Marina) → Open Ocean (100% clean) → Deep Sea (100% clean)
const ZONE_ORDER := ["coral_reef", "open_ocean", "deep_sea"]
const ZONE_UNLOCK_REQ := {
	"coral_reef": 0.0,    # unlock / free dari awal
	"open_ocean": 1.0,    # unlock setelah Coral Reef 100% clean
	"deep_sea": 1.0,      # unlock setelah Open Ocean 100% clean
}
const ZONE_O2_DRAIN := {
	"coral_reef": 1.0,
	"open_ocean": 1.5,
	"deep_sea": 2.0,
}
const CLEAN_PER_SORT := 10.0   # setiap sort benar = +10% zone clean (10 sort benar = 1 zone 100% clean)

var zone_progress := {
	"coral_reef": 0.0,
	"open_ocean": 0.0,
	"deep_sea": 0.0,
}
var current_zone: String = "coral_reef"

func get_carried_count() -> int:
	return carried_trash["plastik"] + carried_trash["logam"] + carried_trash["organik"]

func collect_underwater_trash(trash_type: String) -> bool:
	if trash_type == "" or not carried_trash.has(trash_type):
		return false
	if get_carried_count() >= bag_capacity:
		print("[GameManager] Bag penuh! Kapasitas: ", bag_capacity)
		return false
	carried_trash[trash_type] += 1
	trash_carried_changed.emit()
	# Trigger quest progress Marina (jika quest aktif)
	register_marina_collect()
	print("[GameManager] Sampah laut: ", trash_type, " | ", get_carried_count(), "/", bag_capacity)
	return true

func reset_carried_trash() -> void:
	carried_trash = {"plastik": 0, "logam": 0, "organik": 0}
	trash_carried_changed.emit()
	print("[GameManager] Karung sampah laut dikosongkan")

# === SORTING (Phase B) ===
# Sortir sampah ke bin. BENAR: -1% polusi + material. SALAH: +1% polusi.
func sort_trash(trash_type: String, bin_type: String) -> bool:
	if trash_type == "" or not carried_trash.has(trash_type):
		return false
	if carried_trash[trash_type] <= 0:
		return false

	carried_trash[trash_type] -= 1
	trash_carried_changed.emit()

	if trash_type == bin_type:
		if recycled_material.has(bin_type):
			recycled_material[bin_type] += 1
		AirQuality.on_sort_correct()
		AudioManager.play_sfx("success")
		# Sort benar → naikkan progress pemulihan laut secara sekuensial
		add_sequential_clean(CLEAN_PER_SORT)
		# Trigger quest progress Marina (jika quest aktif)
		register_marina_sort(true)
		print("[GameManager] Sort BENAR: ", trash_type, " | material: ", recycled_material[bin_type])
		return true
	else:
		AirQuality.on_sort_wrong()
		AudioManager.play_sfx("error")
		print("[GameManager] Sort SALAH: ", trash_type, " dibuang ke bin ", bin_type)
		return false

func get_recycled_count() -> int:
	return recycled_material["plastik"] + recycled_material["logam"] + recycled_material["organik"]

# === RECYCLING (Phase C) ===
# Mini-game: konsumsi 1 material → sukses = +1 finished product, gagal = material hilang
func consume_for_recycle(trash_type: String) -> bool:
	if trash_type == "" or not recycled_material.has(trash_type):
		return false
	if recycled_material[trash_type] <= 0:
		return false
	recycled_material[trash_type] -= 1
	recycled_material_changed.emit()
	return true

func add_finished_product(trash_type: String) -> void:
	if finished_products.has(trash_type):
		finished_products[trash_type] += 1
		print("[GameManager] Produk jadi: ", trash_type, " | total: ", get_finished_count())

func get_finished_count() -> int:
	return finished_products["plastik"] + finished_products["logam"] + finished_products["organik"]

# === UPGRADE FUNCTIONS (Phase D) ===
func get_max_o2() -> float:
	return O2_BASE + o2_tank_level * O2_PER_LEVEL

func get_upgrade_level(id: String) -> int:
	match id:
		"o2_tank":
			return o2_tank_level
		"bag":
			return bag_level
	return 0

func get_upgrade_max_level(id: String) -> int:
	match id:
		"o2_tank":
			return O2_MAX_LEVEL
		"bag":
			return BAG_MAX_LEVEL
	return 0

func get_next_upgrade_costs(id: String) -> Dictionary:
	var level := get_upgrade_level(id)
	if level >= get_upgrade_max_level(id) or not UPGRADE_COSTS.has(id):
		return {}
	return UPGRADE_COSTS[id][level]

const COIN_UPGRADE_PRICE := 50

func can_afford(costs: Dictionary) -> bool:
	var has_prod := true
	for type in costs:
		if not finished_products.has(type) or finished_products[type] < costs[type]:
			has_prod = false
			break
	if has_prod:
		return true
	return coins >= COIN_UPGRADE_PRICE

func pay_costs(costs: Dictionary) -> bool:
	var has_prod := true
	for type in costs:
		if not finished_products.has(type) or finished_products[type] < costs[type]:
			has_prod = false
			break
	if has_prod:
		for type in costs:
			finished_products[type] -= costs[type]
		recycled_material_changed.emit()
		return true
	if coins >= COIN_UPGRADE_PRICE:
		return spend_coins(COIN_UPGRADE_PRICE)
	return false

func purchase_upgrade(id: String) -> bool:
	var level := get_upgrade_level(id)
	if level >= get_upgrade_max_level(id):
		print("[GameManager] Upgrade ", id, " sudah MAX")
		return false

	var costs: Dictionary = get_next_upgrade_costs(id)
	if not pay_costs(costs):
		print("[GameManager] Produk tidak cukup untuk upgrade ", id, " — butuh ", costs)
		return false

	match id:
		"o2_tank":
			o2_tank_level += 1
		"bag":
			bag_level += 1
			bag_capacity = BAG_BASE + bag_level * BAG_PER_LEVEL

	upgrades_changed.emit()
	print("[GameManager] Upgrade ", id, " → Lv", level + 1, " | biaya: ", costs)
	return true

# === ZONE FUNCTIONS (Phase F1) ===
func get_zone_clean_percent(zone: String) -> float:
	if not zone_progress.has(zone):
		return 0.0
	return zone_progress[zone]

func add_zone_clean(zone: String, pct: float) -> void:
	if not zone_progress.has(zone):
		return
	zone_progress[zone] = clampf(zone_progress[zone] + pct, 0.0, 100.0)
	zone_progress_changed.emit()
	print("[GameManager] Zone ", zone, " cleanliness: ", zone_progress[zone], "%")

func add_sequential_clean(pct: float) -> Dictionary:
	var target_zone: String = get_current_healing_zone()
	if target_zone == "":
		return {"zone": "deep_sea", "pct": 100.0, "completed": false, "all_clean": true}
	
	var old_val: float = zone_progress[target_zone]
	zone_progress[target_zone] = clampf(zone_progress[target_zone] + pct, 0.0, 100.0)
	zone_progress_changed.emit()
	var is_completed: bool = (old_val < 100.0 and zone_progress[target_zone] >= 100.0)
	var all_clean: bool = is_all_zones_clean()
	
	print("[GameManager] Sequential clean: ", target_zone, " -> ", zone_progress[target_zone], "%")
	return {
		"zone": target_zone,
		"pct": zone_progress[target_zone],
		"completed": is_completed,
		"all_clean": all_clean
	}

func get_current_healing_zone() -> String:
	for z in ZONE_ORDER:
		if zone_progress[z] < 100.0:
			return z
	return ""

func get_zone_display_name(zone: String) -> String:
	match zone:
		"coral_reef": return "Terumbu Karang"
		"open_ocean": return "Samudra Lepas"
		"deep_sea": return "Palung Laut"
		_: return zone.capitalize()

func get_zone_o2_drain(zone: String) -> float:
	return ZONE_O2_DRAIN.get(zone, 1.0)

func is_zone_unlocked(zone: String) -> bool:
	if not ZONE_UNLOCK_REQ.has(zone):
		return false
	var req: float = float(ZONE_UNLOCK_REQ[zone])
	if zone == "coral_reef" or req <= 0.0:
		return true
	var prev_idx := ZONE_ORDER.find(zone) - 1
	if prev_idx < 0:
		return false
	var prev_zone: String = str(ZONE_ORDER[prev_idx])
	return zone_progress[prev_zone] >= (req * 100.0)

func is_all_zones_clean() -> bool:
	for zone in ZONE_ORDER:
		if zone_progress[zone] < 100.0:
			return false
	return true

func get_next_zone() -> String:
	var idx := ZONE_ORDER.find(current_zone)
	if idx < 0 or idx >= ZONE_ORDER.size() - 1:
		return current_zone
	return ZONE_ORDER[idx + 1]

func get_previous_zone() -> String:
	var idx := ZONE_ORDER.find(current_zone)
	if idx <= 0:
		return current_zone
	return ZONE_ORDER[idx - 1]

# Signals
signal quest_started(spawn_count: int)
signal trash_collected(new_count: int)
signal quest_completed_signal
signal quest_failed_signal
signal timer_updated(time_left: float)
signal coins_updated(new_amount: int)
signal item_purchased(item_name: String)
signal inventory_updated() # New Signal
signal trash_carried_changed
signal marina_met_changed
signal recycled_material_changed
signal upgrades_changed
signal zone_progress_changed
signal marina_quest_progress_changed(collected: int, target: int, sort_correct: int, sort_target: int)

func _process(delta: float) -> void:
	if timer_active and quest_active:
		time_remaining -= delta
		timer_updated.emit(time_remaining)
		
		if time_remaining <= 0:
			fail_quest()

func start_quest() -> void:
	quest_active = true
	quest_completed = false
	quest_failed = false
	trash_count = 0
	
	# Determine target based on how many times completed
	if quest_times_completed == 0:
		target_trash = 10
		quest_time_limit = 180.0  # 3 minutes for first quest
	else:
		target_trash = 20
		quest_time_limit = 300.0  # 5 minutes for second quest
	
	# Start timer
	time_remaining = quest_time_limit
	timer_active = true
	
	# Emit signal with spawn count
	quest_started.emit(20)
	print("[GameManager] Quest started! Target: ", target_trash, " Time: ", quest_time_limit)

func collect_trash() -> void:
	if quest_active and not quest_completed and not quest_failed and trash_count < target_trash:
		trash_count += 1
		trash_collected.emit(trash_count)
		print("[GameManager] Trash collected: ", trash_count, "/", target_trash)

func complete_quest() -> void:
	if quest_active and trash_count >= target_trash:
		quest_completed = true
		quest_active = false
		timer_active = false
		score += 100
		quest_times_completed += 1
		
		# Give coins as reward
		add_coins(QUEST_REWARD)
		
		AudioManager.play_sfx("success")
		quest_completed_signal.emit()
		print("[GameManager] Quest completed! Coins: ", coins)

func fail_quest() -> void:
	quest_failed = true
	quest_active = false
	timer_active = false
	quest_failed_signal.emit()
	print("[GameManager] Quest failed! Time ran out.")

func reset_quest() -> void:
	quest_active = false
	quest_completed = false
	quest_failed = false
	trash_count = 0
	timer_active = false
	print("[GameManager] Quest reset")

func can_complete_quest() -> bool:
	return quest_active and trash_count >= target_trash

func can_take_new_quest() -> bool:
	return not quest_active and not quest_failed and quest_times_completed < 2

func can_retry_quest() -> bool:
	return quest_failed
	
# all_quests_done already exists below

func get_formatted_time() -> String:
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	return "%d:%02d" % [minutes, seconds]

# === INVENTORY FUNCTIONS ===
func add_item(item_name: String, amount: int = 1) -> void:
	if inventory.has(item_name):
		inventory[item_name] += amount
		print("[GameManager] Added to inventory: ", item_name, " x", amount)
		inventory_updated.emit() # Emit signal

func remove_item(item_name: String, amount: int = 1) -> bool:
	if inventory.has(item_name) and inventory[item_name] >= amount:
		inventory[item_name] -= amount
		inventory_updated.emit() # Emit signal
		return true
	return false

func has_item(item_name: String, amount: int = 1) -> bool:
	return inventory.has(item_name) and inventory[item_name] >= amount

func has_coral_materials() -> bool:
	return has_item("besi") and has_item("pasir") and has_item("cable_ties")

func use_coral_materials() -> bool:
	if has_coral_materials():
		remove_item("besi")
		remove_item("pasir")
		remove_item("cable_ties")
		print("[GameManager] Coral materials used!")
		return true
	return false

# === COIN FUNCTIONS ===
func add_coins(amount: int) -> void:
	coins += amount
	coins_updated.emit(coins)
	save_coins()
	print("[GameManager] Coins added: +", amount, " Total: ", coins)

func spend_coins(amount: int) -> bool:
	if coins >= amount:
		coins -= amount
		coins_updated.emit(coins)
		save_coins()
		print("[GameManager] Coins spent: -", amount, " Remaining: ", coins)
		return true
	else:
		print("[GameManager] Not enough coins! Have: ", coins, " Need: ", amount)
		return false

func save_coins() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(str(coins))
		file.close()
		print("[GameManager] Coins saved to file")

func load_coins() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			coins = int(file.get_as_text())
			file.close()
			print("[GameManager] Coins loaded: ", coins)

func _ready() -> void:
	# === SUBMISSION BUILD: ALWAYS RESET COINS ===
	coins = 0 
	save_coins() # Reset/Overwrite file save lama agar selalu 0
	print("[GameManager] DATA RESET FOR SUBMISSION (Coins: 0)")
	
	# load_coins() # Disabled - agar tidak load data lama
	pass

func _unhandled_input(event: InputEvent) -> void:
	# DEBUG: Print inventory when 'T' is pressed
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		print_inventory_debug()

func all_quests_done() -> bool:
	return quest_times_completed >= 2

# === MARINA QUEST FUNCTIONS ===
# Flow: Player bicara Marina (Act 2) → Marina minta kumpulkan 5 sampah dari laut,
# sortir 3 dengan benar. Selesai → Marina ajari 4-zone unlock.
func start_marina_quest() -> void:
	marina_quest_active = true
	marina_quest_completed = false
	marina_quest_collected = 0
	marina_quest_sort_correct = 0
	marina_quest_progress_changed.emit(
		marina_quest_collected, marina_quest_target,
		marina_quest_sort_correct, marina_quest_sort_target
	)
	print("[GameManager] Marina quest started! Target: ", marina_quest_target, " sampah, ", marina_quest_sort_target, " sortir benar")

# Dipanggil setiap player collect trash di laut. Increment counter quest.
func register_marina_collect() -> void:
	if not marina_quest_active or marina_quest_completed:
		return
	if marina_quest_collected < marina_quest_target:
		marina_quest_collected += 1
		marina_quest_progress_changed.emit(
			marina_quest_collected, marina_quest_target,
			marina_quest_sort_correct, marina_quest_sort_target
		)
		print("[GameManager] Marina quest collect: ", marina_quest_collected, "/", marina_quest_target)
	_check_marina_quest_complete()

# Dipanggil setiap sortir benar (sudah ada di sort_trash).
func register_marina_sort(correct: bool) -> void:
	if not marina_quest_active or marina_quest_completed:
		return
	if correct and marina_quest_sort_correct < marina_quest_sort_target:
		marina_quest_sort_correct += 1
		marina_quest_progress_changed.emit(
			marina_quest_collected, marina_quest_target,
			marina_quest_sort_correct, marina_quest_sort_target
		)
		print("[GameManager] Marina quest sort: ", marina_quest_sort_correct, "/", marina_quest_sort_target)
	_check_marina_quest_complete()

func _check_marina_quest_complete() -> void:
	if marina_quest_collected >= marina_quest_target and marina_quest_sort_correct >= marina_quest_sort_target:
		marina_quest_completed = true
		marina_quest_active = false
		add_coins(QUEST_REWARD)
		AudioManager.play_sfx("success")
		print("[GameManager] Marina quest COMPLETE! +", QUEST_REWARD, " coins")

func get_marina_quest_progress() -> String:
	if marina_quest_completed:
		return "Selesai! Kamu sudah paham menyortir."
	if not marina_quest_active:
		return "Belum dimulai"
	return "Sampah: %d/%d | Sortir benar: %d/%d" % [
		marina_quest_collected, marina_quest_target,
		marina_quest_sort_correct, marina_quest_sort_target
	]

func reset_for_respawn() -> void:
	quest_active = false
	quest_completed = false
	quest_failed = false
	trash_count = 0
	time_remaining = 0.0
	timer_active = false
	spawn_at_bridge = false
	intro_shown = false
	inventory = {"besi": 0, "pasir": 0, "cable_ties": 0}
	carried_trash = {"plastik": 0, "logam": 0, "organik": 0}
	bag_capacity = 10
	highlighted_bin = ""
	recycled_material = {"plastik": 0, "logam": 0, "organik": 0}
	finished_products = {"plastik": 0, "logam": 0, "organik": 0}
	o2_tank_level = 0
	bag_level = 0
	bag_capacity = BAG_BASE
	coins = 0
	score = 0
	zone_progress = {"coral_reef": 0.0, "open_ocean": 0.0, "deep_sea": 0.0}
	current_zone = "coral_reef"
	coral_repaired = false
	marina_met = false
	marina_quest_active = false
	marina_quest_completed = false
	marina_quest_collected = 0
	marina_quest_sort_correct = 0
	print("[GameManager] Reset for respawn")

func print_inventory_debug() -> void:
	print("\n=== 🎒 CURRENT INVENTORY ===")
	print("Coins: ", coins)
	for item in inventory:
		var count = inventory[item]
		if count > 0:
			print("- ", item.capitalize(), ": ", count)
# === ENDING MECHANIC ===
var coral_repaired: bool = false
var marina_met: bool = false

func set_coral_repaired() -> void:
	coral_repaired = true
	print("[GameManager] Coral Repaired! Ending unlocked.")

func set_marina_met() -> void:
	marina_met = true
	marina_met_changed.emit()
	print("[GameManager] Marina telah ditemui!")

func save_poem_to_txt() -> void:
	var poem_content = """
	=== SURAT CINTA DARI BUMI ===
	
	Kepada Tuan Penyelamat,
	
	Maafkan aku yang dulu menangis diam-diam,
	Tersedak plastik di kerongkongan sungai,
	Terluka besi di jantung karang yang permai.
	
	Manusia sering lupa, Tuan.
	Mereka kira aku abadi, padahal aku rapuh.
	Mereka buang sisa nafsu mereka ke tubuhku,
	Hingga nafasku sesak, hingga warnaku keruh.
	
	Tapi hari ini... Tanganmu berbeda.
	Kau pungut luka-lukaku dengan cinta.
	Kau jahit kembali karangku yang patah.
	
	Terima kasih telah mendengar jeritanku yang bisu.
	Terima kasih telah menjadi manusia yang "manusia".
	
	Jagalah aku, Tuan.
	Bukan karena aku butuh disembah,
	Tapi karena akulah satu-satunya rumah
	Tempat anak cucumu nanti merebah.
	
	Salam sayang,
	Bumi & Tina.
	"""
	
	# === WEB BUILD SUPPORT ===
	# Jika running di Browser (HTML5), kita tidak bisa akses file system user langsung.
	# Solusinya: Trigger "Download" dialog browser.
	if OS.has_feature("web"):
		print("[GameManager] Detected Web Build. Triggering browser download...")
		# Convert string ke buffer (byte array)
		var buffer = poem_content.to_utf8_buffer()
		# Panggil fungsi Javascript untuk download
		JavaScriptBridge.download_buffer(buffer, "Puisi_Tina.txt")
		
		# Tunggu sebentar lalu quit
		await get_tree().create_timer(3.0, true, false, true).timeout 
		# Note: Di web, quit() mungkin hanya stop game, tidak menutup tab browser (security policy)
		return

	# === DESKTOP / NATIVE BUILD SUPPORT ===
	# Save to user documents (Lebih mudah diakses user)
	var doc_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var full_path = doc_path + "/Puisi_Tina.txt"
	
	var file = FileAccess.open(full_path, FileAccess.WRITE)
	if file:
		file.store_string(poem_content)
		file.close()
		
		# Open folder so user sees it
		OS.shell_open(doc_path)
		print("[GameManager] Poem saved to: ", full_path)
		print("[GameManager] Exiting game in 3 seconds...")
		
		# Exit game logic (Timer ignores pause state)
		await get_tree().create_timer(3.0, true, false, true).timeout 
		get_tree().quit()
	else:
		print("[GameManager] Failed to save poem to Documents. Trying user:// fallback...")
		# Fallback ke user:// jika Documents tidak bisa diakses
		file = FileAccess.open("user://Puisi_Tina.txt", FileAccess.WRITE)
		if file:
			file.store_string(poem_content)
			file.close()
			OS.shell_open(ProjectSettings.globalize_path("user://"))
			await get_tree().create_timer(3.0, true, false, true).timeout 
			get_tree().quit()
