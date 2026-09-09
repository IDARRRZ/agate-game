extends AnimatedSprite2D

# Sampah Plastik Laut — jenis PLASTIK (Act 2 underwater)
# Root AnimatedSprite2D + child Area2D untuk deteksi player

var trash_type: String = "plastik"

func _ready() -> void:
	add_to_group("trash")
	var area = get_node_or_null("Area2D")
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.has_method("Player"):
		if body.has_method("register_nearby_trash"):
			body.register_nearby_trash(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.has_method("Player"):
		if body.has_method("unregister_nearby_trash"):
			body.unregister_nearby_trash(self)