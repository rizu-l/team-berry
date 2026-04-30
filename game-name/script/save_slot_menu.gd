extends Control

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var slot_buttons: Array[Button] = [
	$Panel/VBoxContainer/Slot1Button,
	$Panel/VBoxContainer/Slot2Button,
	$Panel/VBoxContainer/Slot3Button,
]
@onready var back_button: Button = $Panel/VBoxContainer/BackButton

var is_load_mode: bool = true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_button.pressed.connect(queue_free)
	for index in range(slot_buttons.size()):
		var slot := index + 1
		slot_buttons[index].pressed.connect(_on_slot_pressed.bind(slot))
	refresh_slots()

func setup(load_mode: bool) -> void:
	is_load_mode = load_mode
	if is_inside_tree():
		refresh_slots()

func refresh_slots() -> void:
	title_label.text = "LOAD GAME" if is_load_mode else "NEW GAME"
	for index in range(slot_buttons.size()):
		var slot := index + 1
		var save_data := GameManager.get_save_data(slot)
		var button := slot_buttons[index]
		button.text = get_slot_text(slot, save_data)
		button.disabled = is_load_mode and save_data == null

func get_slot_text(slot: int, save_data: SaveData) -> String:
	if save_data == null:
		return "SLOT %d\nEMPTY" % slot

	var ability_count := save_data.unlocked_abilities.size()
	var charm_count := save_data.unlocked_charms.size()
	var saved_time := save_data.saved_at
	if saved_time == "":
		saved_time = "Unknown time"

	return "SLOT %d\n%s\nHP %d/%d  MP %d/%d  ATK %d\nAbilities %d  Charms %d\n%s" % [
		slot,
		save_data.level,
		save_data.hp,
		save_data.max_hp,
		int(save_data.mp),
		int(save_data.max_mp),
		save_data.attack,
		ability_count,
		charm_count,
		saved_time,
	]

func _on_slot_pressed(slot: int) -> void:
	queue_free()
	if is_load_mode:
		GameManager.start_loaded_game(slot)
	else:
		GameManager.start_new_game(slot)
