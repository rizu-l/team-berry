extends CanvasLayer
class_name InventoryUI

const CUSTOM_FONT := preload("res://icons/ARCADECLASSIC.TTF")
const SLOT_SIZE := Vector2(560, 92)
const CHARM_BUTTON_SIZE := Vector2(580, 86)

@onready var root_control: Control = $Root
@onready var stat_label: Label = $Root/Panel/VBoxContainer/Content/StatsPanel/StatsLabel
@onready var equipped_container: VBoxContainer = $Root/Panel/VBoxContainer/Content/RightColumn/EquippedCharmsPanel/EquippedList
@onready var available_charms_container: VBoxContainer = $Root/Panel/VBoxContainer/Content/RightColumn/AvailableCharmsPanel/ScrollContainer/AvailableList
@onready var tooltip: Label = $Root/Panel/VBoxContainer/Tooltip
@onready var close_button: Button = $Root/Panel/VBoxContainer/Buttons/CloseButton
@onready var save_button: Button = $Root/Panel/VBoxContainer/Buttons/SaveButton

var charm_inventory: CharmInventory
var is_at_altar: bool = false
var charm_slot_buttons: Array = []
var charm_list_buttons: Array = []

func _ready():
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	close_button.pressed.connect(_on_close_pressed)
	save_button.pressed.connect(_on_save_pressed)
	
	tooltip.visible = false
	
	charm_inventory = GameManager.get_charm_inventory()
	
	create_charm_slots()
	create_charm_list()
	update_stats_display()
	update_equipped_display()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

func create_charm_slots() -> void:
	for child in equipped_container.get_children():
		child.queue_free()
	
	charm_slot_buttons.clear()
	
	for i in range(4):
		var slot_button = Button.new()
		slot_button.custom_minimum_size = SLOT_SIZE
		slot_button.add_theme_font_override("font", CUSTOM_FONT)
		slot_button.add_theme_font_size_override("font_size", 24)
		slot_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		slot_button.expand_icon = true
		slot_button.text = "Empty Slot %d" % (i + 1)
		slot_button.pressed.connect(_on_charm_slot_pressed.bindv([i]))
		slot_button.mouse_entered.connect(_on_charm_slot_hover.bindv([i]))
		slot_button.mouse_exited.connect(_on_tooltip_hide)
		
		equipped_container.add_child(slot_button)
		charm_slot_buttons.append(slot_button)

func create_charm_list() -> void:
	for child in available_charms_container.get_children():
		child.queue_free()
	
	charm_list_buttons.clear()
	
	var all_charms = charm_inventory.get_all_charms()
	
	for charm in all_charms:
		var charm_button = Button.new()
		charm_button.custom_minimum_size = CHARM_BUTTON_SIZE
		charm_button.add_theme_font_override("font", CUSTOM_FONT)
		charm_button.add_theme_font_size_override("font_size", 24)
		charm_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		charm_button.expand_icon = true
		charm_button.icon = charm["icon"]
		
		charm_button.text = get_charm_button_text(charm)
		if not charm["is_unlocked"]:
			charm_button.modulate = Color(0.45, 0.45, 0.45, 1.0)
		
		charm_button.pressed.connect(_on_charm_clicked.bindv([charm["charm_id"]]))
		charm_button.mouse_entered.connect(_on_charm_hover.bindv([charm["charm_id"]]))
		charm_button.mouse_exited.connect(_on_tooltip_hide)
		
		available_charms_container.add_child(charm_button)
		charm_list_buttons.append(charm_button)

func update_stats_display() -> void:
	var hp = GameManager.get_player_hp()
	var max_hp = GameManager.get_player_max_hp()
	var mp = GameManager.get_player_mp()
	var max_mp = GameManager.get_player_max_mp()
	var attack = GameManager.get_player_attack()
	var mp_regen = GameManager.get_player_mp_regen()
	
	var total_buffs = charm_inventory.get_total_buffs()
	
	var stats_text = "PLAYER STATS:\n"
	stats_text += "HP: %d / %d\n" % [hp, max_hp]
	stats_text += "MP: %.0f / %.0f\n" % [mp, max_mp]
	stats_text += "Attack: %d\n" % attack
	stats_text += "MP Regen: %.1f\n\n" % mp_regen
	stats_text += "CHARM BUFFS:\n"
	stats_text += "Max HP: +%d\n" % total_buffs["max_hp"]
	stats_text += "Attack: +%d\n" % total_buffs["attack"]
	stats_text += "Max MP: +%d\n" % total_buffs["max_mp"]
	stats_text += "MP Regen: +%.1f" % total_buffs["mp_regen"]
	
	stat_label.text = stats_text

func update_equipped_display() -> void:
	var equipped = charm_inventory.get_equipped_charm_details()
	
	for i in range(4):
		if i < equipped.size():
			charm_slot_buttons[i].text = "%s\n%s" % [
				equipped[i]["display_name"],
				equipped[i]["effect_text"],
			]
			charm_slot_buttons[i].icon = equipped[i]["icon"]
		else:
			charm_slot_buttons[i].text = "Empty Slot %d" % (i + 1)
			charm_slot_buttons[i].icon = null

func _on_charm_clicked(charm_id) -> void:
	var charm = charm_inventory.get_charm(charm_id)
	
	if charm.is_empty():
		return
	
	if not charm["is_unlocked"]:
		show_tooltip(charm["display_name"], "Locked\n%s" % charm["effect_text"])
		return
	
	if not is_at_altar:
		show_tooltip(charm["display_name"], "Rest at an altar to equip charms.")
		return
	
	if charm["is_equipped"]:
		GameManager.unequip_charm(charm_id)
	else:
		if not GameManager.equip_charm(charm_id):
			show_tooltip(charm["display_name"], "No empty charm slots.")
			return
	
	update_equipped_display()
	create_charm_list()
	update_stats_display()

func _on_charm_slot_pressed(slot_index: int) -> void:
	if not is_at_altar:
		show_tooltip("Charm Slot", "Rest at an altar to unequip charms.")
		return
	
	var equipped = charm_inventory.get_equipped_charms()
	
	if slot_index < equipped.size():
		var charm_id = equipped[slot_index]
		GameManager.unequip_charm(charm_id)
		
		update_equipped_display()
		create_charm_list()
		update_stats_display()

func _on_charm_slot_hover(slot_index: int) -> void:
	var equipped = charm_inventory.get_equipped_charm_details()
	
	if slot_index < equipped.size():
		var charm = equipped[slot_index]
		show_tooltip(charm["display_name"], "%s\n%s" % [charm["description"], charm["effect_text"]])

func _on_charm_hover(charm_id) -> void:
	var charm = charm_inventory.get_charm(charm_id)
	
	if not charm.is_empty():
		show_tooltip(charm["display_name"], "%s\n%s" % [charm["description"], charm["effect_text"]])

func show_tooltip(charm_name: String, description: String) -> void:
	tooltip.text = "%s\n%s" % [charm_name, description]
	tooltip.visible = true

func get_charm_button_text(charm: Dictionary) -> String:
	var status := ""
	if charm["is_equipped"]:
		status = "  [Equipped]"
	elif not charm["is_unlocked"]:
		status = "  [Locked]"

	return "%s%s\n%s" % [
		charm["display_name"],
		status,
		charm["effect_text"],
	]

func _on_tooltip_hide() -> void:
	tooltip.visible = false

func set_at_altar(at_altar: bool) -> void:
	is_at_altar = at_altar
	save_button.visible = at_altar

func _on_close_pressed() -> void:
	get_tree().paused = false
	queue_free()

func _on_save_pressed() -> void:
	if is_at_altar:
		save_game()
		show_tooltip("Saved!", "Game saved successfully")
		await get_tree().create_timer(2.0, true).timeout
		get_tree().paused = false
		queue_free()

func save_game() -> void:
	var player = get_tree().get_first_node_in_group("player")
	
	if player == null:
		return
	
	var save_data = SaveData.new()
	
	save_data.hp = GameManager.get_player_hp()
	save_data.max_hp = GameManager.get_player_max_hp()
	save_data.mp = GameManager.get_player_mp()
	save_data.max_mp = GameManager.get_player_max_mp()
	save_data.attack = GameManager.get_player_attack()
	save_data.unlocked_abilities = GameManager.get_unlocked_abilities().duplicate()
	
	save_data.position = player.global_position
	save_data.level = get_tree().current_scene.name
	save_data.level_path = get_tree().current_scene.scene_file_path
	save_data.saved_at = Time.get_datetime_string_from_system(false, true)
	
	var unlocked_charms_array = []
	for charm_id in charm_inventory.unlocked_charms.keys():
		if charm_inventory.unlocked_charms[charm_id]:
			unlocked_charms_array.append(charm_id)
	save_data.unlocked_charms = unlocked_charms_array
	save_data.equipped_charm_ids = charm_inventory.equipped_charm_ids.duplicate()
	
	var error = ResourceSaver.save(save_data, GameManager.get_save_path())
	if error == OK:
		print("Game saved successfully!")
	else:
		print("Error saving game: ", error)
