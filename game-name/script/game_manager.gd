extends Node
const DEFAULT_PLAYER_DATA := {
	"max_hp": 100,
	"hp": 100,
	"max_mp": 100.0,
	"mp": 100.0,
	"attack": 10,
	"unlocked_abilities": {}
}
var player_data: Dictionary = DEFAULT_PLAYER_DATA.duplicate(true)
var charm_inventory: CharmInventory
var current_save_slot: int = 1
var pending_player_position: Vector2 = Vector2.ZERO
var has_pending_player_position: bool = false

const FIRST_LEVEL_PATH := "res://Stages/stage_1.tscn"

func _ready():
	RenderingServer.set_default_clear_color(Color(0.30,0.30,0.30,1.00))
	
	# Initialize charm inventory
	charm_inventory = CharmInventory.new()

func reset_player_data() -> void:
	player_data = DEFAULT_PLAYER_DATA.duplicate(true)
	has_pending_player_position = false
	charm_inventory = CharmInventory.new()


func get_player_hp() -> int:
	return player_data["hp"]

func set_player_hp(value: int) -> void:
	player_data["hp"] = clampi(value, 0, player_data["max_hp"])

func get_player_max_hp() -> int:
	return player_data["max_hp"]

func set_player_max_hp(value: int) -> void:
	player_data["max_hp"] = max(value, 1)
	player_data["hp"] = clampi(player_data["hp"], 0, player_data["max_hp"])

func get_player_mp() -> float:
	return player_data["mp"]

func set_player_mp(value: float) -> void:
	player_data["mp"] = clampf(value, 0.0, player_data["max_mp"])

func get_player_max_mp() -> float:
	return player_data["max_mp"]

func set_player_max_mp(value: float) -> void:
	player_data["max_mp"] = maxf(value, 0.0)
	player_data["mp"] = clampf(player_data["mp"], 0.0, player_data["max_mp"])

func get_player_attack() -> int:
	return player_data["attack"]

func set_player_attack(value: int) -> void:
	player_data["attack"] = max(value, 0)

func get_unlocked_abilities() -> Dictionary:
	return player_data["unlocked_abilities"]

func has_ability(ability) -> bool:
	return player_data["unlocked_abilities"].has(ability)

func unlock_ability(ability) -> void:
	player_data["unlocked_abilities"][ability] = true

# ============ CHARM SYSTEM ============

func is_charm_unlocked(charm_id) -> bool:
	"""Check if a charm is unlocked"""
	if charm_inventory:
		return charm_inventory.is_charm_unlocked(charm_id)
	return false

func unlock_charm(charm_id) -> void:
	"""Unlock a charm"""
	if charm_inventory:
		charm_inventory.unlock_charm(charm_id)

func equip_charm(charm_id: String) -> bool:
	"""Equip a charm"""
	if charm_inventory:
		return charm_inventory.equip_charm(charm_id)
	return false

func unequip_charm(charm_id: String) -> bool:
	"""Unequip a charm"""
	if charm_inventory:
		return charm_inventory.unequip_charm(charm_id)
	return false

func get_equipped_charms() -> Array:
	"""Get all equipped charms"""
	if charm_inventory:
		return charm_inventory.get_equipped_charms()
	return []

func get_charm_buffs() -> Dictionary:
	"""Get total buffs from equipped charms"""
	if charm_inventory:
		return charm_inventory.get_total_buffs()
	return {}

func get_charm_inventory() -> CharmInventory:
	if charm_inventory == null:
		charm_inventory = CharmInventory.new()
	return charm_inventory

# ============ SAVE/LOAD ============

func get_save_path(slot: int = current_save_slot) -> String:
	return "user://save_slot_%d.tres" % clampi(slot, 1, 3)

func set_current_save_slot(slot: int) -> void:
	current_save_slot = clampi(slot, 1, 3)

func load_game(slot: int = current_save_slot) -> bool:
	"""Load game state from SaveData resource file"""
	set_current_save_slot(slot)
	var save_path = get_save_path()
	
	# Check if save file exists
	if not ResourceLoader.exists(save_path):
		print("No save file found")
		return false
	
	# Load the SaveData resource
	var save_data = ResourceLoader.load(save_path) as SaveData
	if save_data == null:
		print("Failed to load save file")
		return false
	
	# Load player stats
	player_data["hp"] = save_data.hp
	player_data["max_hp"] = save_data.max_hp
	player_data["mp"] = save_data.mp
	player_data["max_mp"] = save_data.max_mp
	player_data["attack"] = save_data.attack
	player_data["unlocked_abilities"] = save_data.unlocked_abilities.duplicate()
	
	charm_inventory = CharmInventory.new()
	load_charm_inventory(save_data)

	pending_player_position = save_data.position
	has_pending_player_position = true
	
	print("Game loaded successfully from: ", save_path)
	return true

func get_save_data(slot: int) -> SaveData:
	var save_path := get_save_path(slot)
	if not ResourceLoader.exists(save_path):
		return null
	return ResourceLoader.load(save_path) as SaveData

func start_new_game(slot: int) -> void:
	set_current_save_slot(slot)
	reset_player_data()
	get_tree().change_scene_to_file(FIRST_LEVEL_PATH)

func start_loaded_game(slot: int) -> void:
	if not load_game(slot):
		return
	var save_data := get_save_data(slot)
	var next_scene := FIRST_LEVEL_PATH
	if save_data != null and save_data.level_path != "":
		next_scene = save_data.level_path
	get_tree().change_scene_to_file(next_scene)

func apply_pending_player_position(player: Node2D) -> void:
	if not has_pending_player_position:
		return
	player.global_position = pending_player_position
	has_pending_player_position = false

func load_charm_inventory(save_data: SaveData) -> void:
	"""Load charm inventory from SaveData (mirrors ability loading pattern)"""
	# Load unlocked charms (loop array and call unlock_charm)
	var unlocked_charms_array = save_data.unlocked_charms
	for charm_id in unlocked_charms_array:
		unlock_charm(charm_id)
	
	# Load equipped charms
	charm_inventory.equipped_charm_ids = save_data.equipped_charm_ids.duplicate()
