extends Control
class_name InventoryUI

@onready var stat_label = $VBoxContainer/StatsPanel/StatsLabel
@onready var equipped_container = $VBoxContainer/EquippedCharmsPanel/VBoxContainer
@onready var available_charms_container = $VBoxContainer/AvailableCharmsPanel/VBoxContainer/ScrollContainer/VBoxContainer
@onready var tooltip = $Tooltip
@onready var close_button = $VBoxContainer/CloseButton
@onready var save_button = $VBoxContainer/SaveButton

var charm_inventory: CharmInventory
var is_at_altar: bool = false
var charm_slot_buttons: Array = []
var charm_list_buttons: Array = []

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	save_button.pressed.connect(_on_save_pressed)
	
	# Hide tooltip initially
	tooltip.visible = false
	
	# Initialize charm inventory from GameManager
	charm_inventory = GameManager.get_charm_inventory()
	
	# Create charm slots for equipped charms
	create_charm_slots()
	
	# Create charm list for available charms
	create_charm_list()
	
	# Update display
	update_stats_display()
	update_equipped_display()

func create_charm_slots() -> void:
	"""Create 4 charm slot buttons for equipped charms"""
	# Clear existing
	for child in equipped_container.get_children():
		child.queue_free()
	
	charm_slot_buttons.clear()
	
	for i in range(4):
		var slot_button = Button.new()
		slot_button.custom_min_size = Vector2(150, 50)
		slot_button.text = "[Empty Slot %d]" % (i + 1)
		slot_button.pressed.connect(_on_charm_slot_pressed.bindv([i]))
		slot_button.mouse_entered.connect(_on_charm_slot_hover.bindv([i]))
		slot_button.mouse_exited.connect(_on_tooltip_hide)
		
		equipped_container.add_child(slot_button)
		charm_slot_buttons.append(slot_button)

func create_charm_list() -> void:
	"""Create list of all available charms"""
	# Clear existing
	for child in available_charms_container.get_children():
		child.queue_free()
	
	charm_list_buttons.clear()
	
	var all_charms = charm_inventory.get_all_charms()
	
	for charm in all_charms:
		var charm_button = Button.new()
		charm_button.custom_min_size = Vector2(200, 40)
		
		# Show charm name with lock icon if locked
		if charm.is_unlocked:
			charm_button.text = charm.display_name
			if charm.is_equipped:
				charm_button.text += " [EQUIPPED]"
		else:
			charm_button.text = "? - Unknown Charm"
		
		charm_button.pressed.connect(_on_charm_clicked.bindv([charm.charm_id]))
		charm_button.mouse_entered.connect(_on_charm_hover.bindv([charm.charm_id]))
		charm_button.mouse_exited.connect(_on_tooltip_hide)
		
		available_charms_container.add_child(charm_button)
		charm_list_buttons.append(charm_button)

func update_stats_display() -> void:
	"""Update the stats panel"""
	var hp = GameManager.get_player_hp()
	var max_hp = GameManager.get_player_max_hp()
	var mp = GameManager.get_player_mp()
	var max_mp = GameManager.get_player_max_mp()
	var attack = GameManager.get_player_attack()
	var mp_regen = 3.0  # Get from player or GameManager
	
	var total_buffs = charm_inventory.get_total_buffs()
	
	var stats_text = "BASE STATS:\n"
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
	"""Update the equipped charm slots"""
	var equipped = charm_inventory.get_equipped_charms()
	
	for i in range(4):
		if i < equipped.size():
			charm_slot_buttons[i].text = equipped[i].display_name
		else:
			charm_slot_buttons[i].text = "[Empty Slot %d]" % (i + 1)

func _on_charm_clicked(charm_id: String) -> void:
	"""Handle charm click"""
	var charm = charm_inventory.get_charm(charm_id)
	
	if not charm:
		return
	
	if not charm.is_unlocked:
		return
	
	if not is_at_altar:
		return
	
	# Toggle equip/unequip
	charm_inventory.toggle_charm(charm_id)
	
	# Update display
	update_equipped_display()
	create_charm_list()
	update_stats_display()

func _on_charm_slot_pressed(slot_index: int) -> void:
	"""Handle equipped charm slot click"""
	if not is_at_altar:
		return
	
	var equipped = charm_inventory.get_equipped_charms()
	
	if slot_index < equipped.size():
		# Unequip this charm
		var charm_id = equipped[slot_index].charm_id
		charm_inventory.unequip_charm(charm_id)
		
		# Update display
		update_equipped_display()
		create_charm_list()
		update_stats_display()

func _on_charm_slot_hover(slot_index: int) -> void:
	"""Show tooltip for equipped charm"""
	var equipped = charm_inventory.get_equipped_charms()
	
	if slot_index < equipped.size():
		var charm = equipped[slot_index]
		show_tooltip(charm.display_name, charm.description)

func _on_charm_hover(charm_id: String) -> void:
	"""Show tooltip for charm in list"""
	var charm = charm_inventory.get_charm(charm_id)
	
	if charm:
		show_tooltip(charm.display_name, charm.description)

func show_tooltip(name: String, description: String) -> void:
	"""Display tooltip"""
	tooltip.text = "%s\n%s" % [name, description]
	tooltip.visible = true

func _on_tooltip_hide() -> void:
	"""Hide tooltip"""
	tooltip.visible = false

func set_at_altar(at_altar: bool) -> void:
	"""Set whether player is at altar (enables equip/unequip)"""
	is_at_altar = at_altar
	save_button.visible = at_altar

func _on_close_pressed() -> void:
	"""Close inventory"""
	get_tree().paused = false
	queue_free()

func _on_save_pressed() -> void:
	"""Save game"""
	if is_at_altar:
		save_game()
		show_tooltip("Saved!", "Game saved successfully")
		await get_tree().create_timer(2.0).timeout
		get_tree().paused = false
		queue_free()

func save_game() -> void:
	"""Save the game state using Godot Resources"""
	var player = get_tree().get_first_node_in_group("player")
	
	if player == null:
		return
	
	# Create SaveData resource
	var save_data = SaveData.new()
	
	# Save player stats from GameManager
	save_data.hp = GameManager.get_player_hp()
	save_data.max_hp = GameManager.get_player_max_hp()
	save_data.mp = GameManager.get_player_mp()
	save_data.max_mp = GameManager.get_player_max_mp()
	save_data.attack = GameManager.get_player_attack()
	save_data.unlocked_abilities = GameManager.get_unlocked_abilities().duplicate()
	
	# Save position and level
	save_data.position = player.global_position
	save_data.level = get_tree().current_scene.name
	
	# Save charm inventory
	save_data.equipped_charm_ids = charm_inventory.equipped_charm_ids.duplicate()
	
	for charm_id in charm_inventory.charms.keys():
		var charm = charm_inventory.charms[charm_id]
		save_data.charms[charm_id] = {
			"is_unlocked": charm.is_unlocked,
			"is_equipped": charm.is_equipped
		}
	
	# Save to file using ResourceSaver
	var error = ResourceSaver.save(save_data, "user://autosave.tres")
	if error == OK:
		print("Game saved successfully!")
	else:
		print("Error saving game: ", error)
