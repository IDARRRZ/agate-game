extends Label

var _layer: CanvasLayer

func _ready() -> void:
	if not get_parent() is CanvasLayer:
		_layer = CanvasLayer.new()
		_layer.layer = 85
		get_parent().call_deferred("add_child", _layer)
		call_deferred("_reparent_to_layer")
	_style_self()
	GameManager.coins_updated.connect(update_display)
	update_display(GameManager.coins)

func _reparent_to_layer() -> void:
	if _layer and is_instance_valid(_layer):
		reparent(_layer)
		position = Vector2(16, 14)

func _style_self() -> void:
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_color", Color(1, 0.88, 0.2))
	add_theme_color_override("font_outline_color", Color(0, 0, 0))
	add_theme_constant_override("outline_size", 4)
	position = Vector2(16, 14)

func update_display(amount: int) -> void:
	text = "💰 " + str(amount) + " Koin"
