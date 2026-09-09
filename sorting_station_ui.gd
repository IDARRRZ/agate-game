extends CanvasLayer

# Sorting Station UI — drag sampah dari tas ke bin yang benar
# Di-instantiate otomatis oleh trash_bin.gd (3 bin di dunia.tscn)
# Highlight bin sesuai bin_type yang dipicu player

signal ui_closed

@onready var slot_plastik = $Panel/Content/BagSection/SlotPlastik
@onready var slot_logam = $Panel/Content/BagSection/SlotLogam
@onready var slot_organik = $Panel/Content/BagSection/SlotOrganik
@onready var feedback_label: Label = $Panel/Content/BinsSection/FeedbackLabel
@onready var close_btn: Button = $Panel/CloseButton

@onready var bin_plastik: TextureButton = $Panel/Content/BinsSection/Row/BinPlastik
@onready var bin_logam: TextureButton = $Panel/Content/BinsSection/Row/BinLogam
@onready var bin_organik: TextureButton = $Panel/Content/BinsSection/Row/BinOrganik

var _slots: Array = []
var _feedback_token: int = 0

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_slots = [slot_plastik, slot_logam, slot_organik]

	# Drag source slot harus STOP agar bisa di-drag
	for s in _slots:
		s.mouse_filter = Control.MOUSE_FILTER_STOP

	for bin in [bin_plastik, bin_logam, bin_organik]:
		if bin and not bin.drop_received.is_connected(_on_bin_drop):
			bin.drop_received.connect(_on_bin_drop)

	close_btn.pressed.connect(close_ui)
	GameManager.trash_carried_changed.connect(refresh_bag)

	# Process mode recursive — pastikan SEMUA child Control di UI tetap aktif
	# walaupun parent (TrashBin Area2D) di-pause saat player freeze
	_set_process_recursive(self, Node.PROCESS_MODE_ALWAYS)

func _set_process_recursive(node: Node, mode: ProcessMode) -> void:
	node.process_mode = mode
	for child in node.get_children():
		_set_process_recursive(child, mode)

func open_ui(highlight_bin: String = "") -> void:
	GameManager.highlighted_bin = highlight_bin
	visible = true
	refresh_bag()
	_apply_highlight(highlight_bin)

func close_ui() -> void:
	if not visible:
		return
	visible = false
	feedback_label.text = ""
	GameManager.highlighted_bin = ""
	_clear_highlight()
	ui_closed.emit()

func refresh_bag() -> void:
	for s in _slots:
		s.refresh()
	# Re-apply highlight kalau UI masih terbuka
	if visible and GameManager.highlighted_bin != "":
		_apply_highlight(GameManager.highlighted_bin)

func _apply_highlight(bin_type: String) -> void:
	_clear_highlight()
	if bin_type == "":
		return
	var target_bin: TextureButton = null
	match bin_type:
		"plastik":
			target_bin = bin_plastik
		"logam":
			target_bin = bin_logam
		"organik":
			target_bin = bin_organik
	if target_bin:
		target_bin.modulate = Color(1.3, 1.3, 0.6, 1.0)  # kuning glow
		target_bin.scale = Vector2(1.15, 1.15)
		print("[SortingUI] Highlight bin: ", bin_type)

func _clear_highlight() -> void:
	for b in [bin_plastik, bin_logam, bin_organik]:
		if is_instance_valid(b):
			b.modulate = Color.WHITE
			b.scale = Vector2(1.0, 1.0)

func _on_bin_drop(bin_type: String, trash_type: String) -> void:
	if GameManager.get_carried_count() <= 0:
		show_feedback("Tas sudah kosong!", false)
		return
	var correct: bool = GameManager.sort_trash(trash_type, bin_type)

	if correct:
		show_feedback("Benar! %s tersortir dengan tepat." % trash_type.capitalize(), true)
	else:
		show_feedback("Salah! %s bukan untuk bin itu." % trash_type.capitalize(), false)

	refresh_bag()

	# Tas kosong → auto close setelah feedback terbaca
	if GameManager.get_carried_count() <= 0:
		await get_tree().create_timer(0.9).timeout
		if visible and GameManager.get_carried_count() <= 0:
			close_ui()

func show_feedback(msg: String, ok: bool) -> void:
	_feedback_token += 1
	var token := _feedback_token
	feedback_label.text = msg
	feedback_label.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.4) if ok else Color(1.0, 0.45, 0.45)
	)
	await get_tree().create_timer(1.6).timeout
	if token == _feedback_token and feedback_label:
		feedback_label.text = ""
