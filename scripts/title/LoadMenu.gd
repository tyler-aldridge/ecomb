extends Control

signal closed
signal file_chosen(save_id: String)
signal delete_requested(save_id: String)

@onready var list: ItemList       = $VBoxContainer/SavesList
@onready var load_btn: Button     = $VBoxContainer/ButtonContainer/LoadButton
@onready var delete_btn: Button   = $VBoxContainer/ButtonContainer/DeleteButton
@onready var close_btn: Button    = $VBoxContainer/ButtonContainer/CloseButton
@onready var dialog_overlay: ColorRect = $DialogOverlay

const MAX_SAVE_SLOTS = 3

func _ready() -> void:
	# Hide overlay initially
	if dialog_overlay:
		dialog_overlay.hide()
	
	# Disable tooltips on the list
	if list:
		list.tooltip_text = ""
	
	# Load actual save data from GameManager
	refresh_save_list()
	
	# Disable load and delete buttons initially
	if load_btn:
		load_btn.disabled = true
	if delete_btn:
		delete_btn.disabled = true
	
	# Connect buttons
	if load_btn:
		load_btn.pressed.connect(_on_load_pressed)
		
	if delete_btn:
		delete_btn.pressed.connect(_on_delete_pressed)
		
	if close_btn:
		close_btn.pressed.connect(_on_close_pressed)
	
	# Connect list selection
	if list:
		list.item_selected.connect(_on_save_selected)

func show_delete_overlay():
	if dialog_overlay:
		dialog_overlay.show()

func hide_delete_overlay():
	if dialog_overlay:
		dialog_overlay.hide()

func refresh_save_list():
	list.clear()
	
	for slot in range(MAX_SAVE_SLOTS):
		var save_info = GameManager.get_save_info(slot)
		
		if save_info.exists:
			var slot_letter = char(65 + slot)
			var display_text = "Save %s — %s" % [slot_letter, save_info.time]
			list.add_item(display_text)
			list.set_item_tooltip_enabled(slot, false)
		else:
			var slot_letter = char(65 + slot)
			list.add_item("Save %s — Empty" % slot_letter)
			list.set_item_tooltip_enabled(slot, false)

func _on_save_selected(_index: int):
	# Enable both load and delete buttons when any save is selected
	# (For testing - you can add save_info.exists check later)
	if load_btn:
		load_btn.disabled = false
	if delete_btn:
		delete_btn.disabled = false

func _on_load_pressed():
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.size() > 0:
		var slot_idx: int = selected[0]
		emit_signal("file_chosen", "slot_%d" % slot_idx)

func _on_delete_pressed():
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.size() > 0:
		var slot_idx: int = selected[0]
		show_delete_overlay()  # Show our overlay
		emit_signal("delete_requested", "slot_%d" % slot_idx)

func _on_close_pressed():
	emit_signal("closed")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		emit_signal("closed")
