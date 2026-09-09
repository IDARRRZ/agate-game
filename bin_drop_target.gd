extends TextureButton

# Bin Drop Target — tempat menjatuhkan sampah di Sorting Station UI
# Saat sampah di-drop, emit drop_received(bin_type, trash_type)

@export var bin_type: String = ""

signal drop_received(bin_type: String, trash_type: String)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"):
		return false
	var t: String = str(data["type"])
	return t != "" and GameManager.carried_trash.has(t) and GameManager.carried_trash[t] > 0

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var trash_type := str(data["type"])
	if trash_type == "" or not GameManager.carried_trash.has(trash_type) or GameManager.carried_trash[trash_type] <= 0:
		return
	drop_received.emit(bin_type, trash_type)