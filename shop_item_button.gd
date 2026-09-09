extends Button

@export var item_id: String = "besi"
@export var item_name: String = "Besi"
@export var price: int = 20
@export var icon_texture: Texture2D

const SELL_RATE := 0.7

func _ready() -> void:
	custom_minimum_size = Vector2(100, 100)
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	expand_icon = true
	
	if icon_texture:
		icon = icon_texture
	
	pressed.connect(_on_pressed)
	
	GameManager.coins_updated.connect(_on_coins_updated)
	GameManager.inventory_updated.connect(_on_inventory_updated)
	
	update_text()
	
	for child in get_children():
		if child is Label or child is TextureRect:
			child.visible = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_on_sell()
			get_viewport().set_input_as_handled()

func _on_pressed() -> void:
	if GameManager.spend_coins(price):
		GameManager.add_item(item_id)
		if Engine.has_singleton("AudioManager") or get_tree().root.has_node("AudioManager"):
			AudioManager.play_sfx("buy")
		print("Bought ", item_name)
		update_text()
	else:
		if Engine.has_singleton("AudioManager") or get_tree().root.has_node("AudioManager"):
			AudioManager.play_sfx("error")
		print("Not enough coins for ", item_name)

func _on_sell() -> void:
	if not GameManager.inventory.has(item_id) or GameManager.inventory[item_id] <= 0:
		AudioManager.play_sfx("error")
		_show_shop_msg("Tidak ada %s untuk dijual!" % item_name)
		return
	if not GameManager.remove_item(item_id, 1):
		AudioManager.play_sfx("error")
		return
	var refund := int(floor(price * SELL_RATE))
	GameManager.add_coins(refund)
	AudioManager.play_sfx("buy")
	_show_shop_msg("Dijual 1 %s +%d coin (70%%)" % [item_name, refund])
	print("Sold ", item_name, " refund ", refund)
	update_text()

func _show_shop_msg(msg: String) -> void:
	var shop = get_tree().root.find_child("shop_manager", true, false)
	if shop and shop.has_method("show_message"):
		shop.show_message(msg)

func _on_coins_updated(_coins: int) -> void:
	update_text()

func _on_inventory_updated() -> void:
	update_text()

func update_text() -> void:
	var count = 0
	if GameManager.inventory.has(item_id):
		count = GameManager.inventory[item_id]
	
	text = "%s (%d C)\n[%d]\nRMB jual" % [item_name, price, count]
