extends Area2D

# Sampah Buah — jenis ORGANIK (Act 2 underwater)
# Registrasi ke player swim untuk pickup

var trash_type: String = "organik"

func _ready() -> void:
	add_to_group("trash")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.has_method("Player"):
		if body.has_method("register_nearby_trash"):
			body.register_nearby_trash(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.has_method("Player"):
		if body.has_method("unregister_nearby_trash"):
			body.unregister_nearby_trash(self)
