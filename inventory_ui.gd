extends CanvasLayer

@onready var item_grid = $Panel/ItemGrid
@onready var close_btn = $Panel/Button
@onready var panel = $Panel
@onready var coin_label = $Panel/CoinLabel # New Reference

# Preload textures (Hardcoded for simplicity, or load dynamically)
# Gunakan path yang valid dari project
var textures = {
	"besi": preload("res://Besi.png"),
	"pasir": preload("res://Pasir.png"),
	"cable_ties": preload("res://Cable.png")
}

func _ready():
	# Connect signals
	if close_btn:
		close_btn.pressed.connect(close_inventory)
	
	# Listen to global updates
	if GameManager.has_signal("inventory_updated"):
		GameManager.inventory_updated.connect(update_ui)
		
	# Listen to coin updates too
	if GameManager.has_signal("coins_updated"):
		GameManager.coins_updated.connect(func(_coins): update_ui())
	
	# Hide initially
	visible = false
	
func _unhandled_input(event):
	if event.is_action_pressed("open_inventory") or (event is InputEventKey and event.pressed and event.keycode == KEY_T):
		toggle_inventory()

func toggle_inventory():
	visible = not visible
	if visible:
		update_ui()
		# Optional: Pause game
		# get_tree().paused = true

func close_inventory():
	visible = false
	# get_tree().paused = false

func update_ui():
	# Update Coin Label
	if coin_label:
		coin_label.text = "Koin: " + str(GameManager.coins)
	
	# Clear existing children
	for child in item_grid.get_children():
		child.queue_free()
	
	# Populate based on GameManager inventory
	for item_name in GameManager.inventory:
		var amount = GameManager.inventory[item_name]
		
		# Only show if amount > 0 (or show all with 0 if desired)
		# Tampilkan semua agar player tahu apa yg harus dicari
		create_item_slot(item_name, amount)

func create_item_slot(data_name: String, amount: int):
	var slot = VBoxContainer.new()
	slot.custom_minimum_size = Vector2(80, 80)
	
	# Icon
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(50, 50)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if textures.has(data_name):
		icon.texture = textures[data_name]
	
	# Label Path/Name
	var label = Label.new()
	label.text = "%s : %d" % [data_name.capitalize(), amount]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	
	slot.add_child(icon)
	slot.add_child(label)
	
	item_grid.add_child(slot)
