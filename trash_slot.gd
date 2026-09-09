extends PanelContainer

# Trash Slot — sumber drag di Sorting Station UI
# Drag hanya bisa jika stok jenis ini > 0. Mengembalikan {"type": trash_type}.

@export var trash_type: String = ""
@export var icon_texture: Texture2D

func get_count() -> int:
	if trash_type == "" or not GameManager.carried_trash.has(trash_type):
		return 0
	return GameManager.carried_trash[trash_type]

func refresh() -> void:
	var count_label = get_node_or_null("HBox/CountLabel")
	if count_label:
		count_label.text = "x%d" % get_count()

func _get_drag_data(_at_position: Vector2) -> Variant:
	if get_count() <= 0:
		return null

	var data = {"type": trash_type}

	# Preview icon kecil yang mengikuti cursor saat drag
	if icon_texture:
		var preview = TextureRect.new()
		preview.texture = icon_texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.custom_minimum_size = Vector2(48, 48)
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.modulate = Color(1, 1, 1, 0.85)
		set_drag_preview(preview)

	return data