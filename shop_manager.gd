extends CanvasLayer

# Shop Manager
# Handles shop UI and purchasing items

# Shop items configuration
var shop_items = {
	"besi": {"name": "Besi", "price": 20, "description": "Material untuk repair koral"},
	"pasir": {"name": "Pasir", "price": 15, "description": "Material untuk repair koral"},
	"cable_ties": {"name": "Cable Ties", "price": 10, "description": "Material untuk repair koral"}
}

# UI References — 720×340 grid
@onready var coin_label: Label = $Panel/Margin/VBox/Header/CoinLabel
@onready var besi_btn: Button = $Panel/Margin/VBox/Content/LeftCol/Grid/BesiButton
@onready var pasir_btn: Button = $Panel/Margin/VBox/Content/LeftCol/Grid/PasirButton
@onready var cable_btn: Button = $Panel/Margin/VBox/Content/LeftCol/Grid/CableButton
@onready var close_btn: Button = $Panel/Margin/VBox/Header/CloseButton
@onready var message_label: Label = $Panel/Margin/VBox/MessageLabel
@onready var tank_button: Button = $Panel/Margin/VBox/Content/RightCol/TankRow/TankButton
@onready var bag_button: Button = $Panel/Margin/VBox/Content/RightCol/BagRow/BagButton
@onready var tank_level_label: Label = $Panel/Margin/VBox/Content/RightCol/TankRow/TankInfo/TankLevelLabel
@onready var tank_cost_label: Label = $Panel/Margin/VBox/Content/RightCol/TankRow/TankInfo/TankCostLabel
@onready var bag_level_label: Label = $Panel/Margin/VBox/Content/RightCol/BagRow/BagInfo/BagLevelLabel
@onready var bag_cost_label: Label = $Panel/Margin/VBox/Content/RightCol/BagRow/BagInfo/BagCostLabel

var upgrade_display = {
	"o2_tank": {"name": "O2 Tank", "desc": "+30 detik selam"},
	"bag": {"name": "Bag", "desc": "+5 kapasitas tas"},
}
const TYPE_NAMES = {"plastik": "Plastik", "logam": "Logam", "organik": "Organik"}

var is_open: bool = false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	setup_button(besi_btn, "res://Besi.png", "besi", 20, "Besi")
	setup_button(pasir_btn, "res://Pasir.png", "pasir", 15, "Pasir")
	setup_button(cable_btn, "res://Cable.png", "cable_ties", 10, "Cable")
	
	if close_btn:
		close_btn.pressed.connect(close_shop)
	
	if tank_button:
		tank_button.pressed.connect(buy_upgrade.bind("o2_tank"))
	if bag_button:
		bag_button.pressed.connect(buy_upgrade.bind("bag"))
	if GameManager.has_signal("upgrades_changed"):
		GameManager.upgrades_changed.connect(update_ui)
	GameManager.coins_updated.connect(_on_coins_updated)
	
	update_ui()

func setup_button(btn: Button, icon_path: String, item_id: String, price: int, item_name: String) -> void:
	if not btn: return
	
	# ATTACH CUSTOM SCRIPT DYNAMICALLY
	# Ini cara agar button punya logic sendiri sesuai request
	var component_script = load("res://shop_item_button.gd")
	if not btn.get_script(): # Only attach if not already attached
		btn.set_script(component_script)
		
	# Configure properties on the new script instance
	# Karena script baru di-attach, kita akses property-nya
	btn.item_id = item_id
	btn.item_name = item_name
	btn.price = price
	
	if ResourceLoader.exists(icon_path):
		btn.icon_texture = load(icon_path)
		
	# Trigger ready manual jika perlu, atau biarkan engine handle saat tree enter
	# Tapi karena node sudah di tree, _ready mungkin sudah lewat. 
	# Kita panggil func setup manual atau re-trigger _ready safely?
	# Script replacement di runtime agak tricky untuk _ready.
	# Mari kita panggil method manual jika ada.
	if btn.has_method("_ready"):
		btn._ready()

# ... (rest of code)

func update_ui() -> void:
	if coin_label:
		coin_label.text = "KOIN: " + str(GameManager.coins)
	if besi_btn and GameManager.inventory.has("besi"):
		besi_btn.text = "Besi (20 C) [" + str(GameManager.inventory.besi) + "]"
	if pasir_btn and GameManager.inventory.has("pasir"):
		pasir_btn.text = "Pasir (15 C) [" + str(GameManager.inventory.pasir) + "]"
	if cable_btn and GameManager.inventory.has("cable_ties"):
		cable_btn.text = "Cable Ties (10 C) [" + str(GameManager.inventory.cable_ties) + "]"
	_update_upgrade_ui("o2_tank")
	_update_upgrade_ui("bag")

func _update_upgrade_ui(id: String) -> void:
	if not tank_button or not bag_button:
		return
	var info = upgrade_display.get(id)
	if not info:
		return
	var lvl := GameManager.get_upgrade_level(id) if GameManager.has_method("get_upgrade_level") else 0
	var maxl := GameManager.get_upgrade_max_level(id) if GameManager.has_method("get_upgrade_max_level") else 2
	var btn := tank_button if id == "o2_tank" else bag_button
	var lvl_lbl := tank_level_label if id == "o2_tank" else bag_level_label
	var cost_lbl := tank_cost_label if id == "o2_tank" else bag_cost_label
	if not btn or not lvl_lbl or not cost_lbl:
		return
	if lvl >= maxl:
		btn.disabled = true
		lvl_lbl.text = "%s — Lv %d/%d (%s)" % [info.name, lvl, maxl, info.desc]
		cost_lbl.text = "Telah maksimal"
		return
	var costs: Dictionary = GameManager.get_next_upgrade_costs(id) if GameManager.has_method("get_next_upgrade_costs") else {}
	var parts: Array[String] = []
	for t in costs:
		parts.append("%d %s" % [costs[t], TYPE_NAMES.get(t, t)])
	btn.disabled = false
	lvl_lbl.text = "%s — Lv %d/%d (%s)" % [info.name, lvl, maxl, info.desc]
	cost_lbl.text = "Butuh: " + (", ".join(parts) if parts.size() > 0 else "-")
	var afford: bool = GameManager.can_afford(costs) if GameManager.has_method("can_afford") else true
	cost_lbl.add_theme_color_override("font_color", Color(1,1,1) if afford else Color(0.75,0.75,0.75))

func buy_upgrade(id: String) -> void:
	if GameManager.has_method("purchase_upgrade") and GameManager.purchase_upgrade(id):
		AudioManager.play_sfx("buy")
		show_message("%s Lv%d!" % [upgrade_display[id].name, GameManager.get_upgrade_level(id)])
		update_ui()
	else:
		AudioManager.play_sfx("error")
		show_message("Produk daur ulang tidak cukup!" if GameManager.get_upgrade_level(id) < GameManager.get_upgrade_max_level(id) else upgrade_display[id].name + " MAX!")

var _player_ref_cache = null

func _unhandled_input(event: InputEvent) -> void:
	var is_b = event.is_action_pressed("interact_shop") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B)
	if not is_b:
		return
	toggle_shop()
	get_viewport().set_input_as_handled()

func toggle_shop() -> void:
	if is_open:
		close_shop()
	else:
		open_shop()

func open_shop() -> void:
	is_open = true
	visible = true
	var panel = get_node_or_null("Panel")
	if panel:
		panel.visible = true
	update_ui()
	var p = get_tree().get_first_node_in_group("player")
	if not p:
		p = get_tree().root.find_child("player", true, false)
	if p:
		_player_ref_cache = p
		p.set("can_move", false)
		p.set("velocity", Vector2.ZERO)
		if p.has_method("change_state"):
			p.change_state("idle")
	print("[Shop] Shop opened")

signal shop_closed

# ...

func close_shop() -> void:
	is_open = false
	visible = false
	var panel = get_node_or_null("Panel")
	if panel:
		panel.visible = false
		panel.modulate.a = 1.0
	var p = _player_ref_cache
	if not is_instance_valid(p):
		p = get_tree().get_first_node_in_group("player")
	if p:
		p.set("can_move", true)
		_player_ref_cache = null
	shop_closed.emit()
	print("[Shop] Shop closed")

func buy_item(item_id: String) -> void:
	if not shop_items.has(item_id):
		show_message("Item tidak ditemukan!")
		return
	
	var item = shop_items[item_id]
	var price = item.price
	
	if GameManager.spend_coins(price):
		GameManager.add_item(item_id)
		GameManager.item_purchased.emit(item_id)
		show_message("Berhasil membeli " + item.name + "!")
		update_ui()
	else:
		show_message("Coin tidak cukup! Butuh " + str(price) + " coins")



func show_message(msg: String) -> void:
	if message_label:
		message_label.text = msg
		# Auto clear after 2 seconds
		await get_tree().create_timer(2.0).timeout
		if message_label:
			message_label.text = ""

func _on_coins_updated(_new_amount: int) -> void:
	update_ui()
