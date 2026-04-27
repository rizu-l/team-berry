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

func _ready():
	RenderingServer.set_default_clear_color(Color(0.30,0.30,0.30,1.00))
	
	# Initialize charm inventory
	charm_inventory = CharmInventory.new()
	
	# Add all charm definitions
	var all_charms = CharmDefinitions.create_all_charms()
	for charm in all_charms:
		charm_inventory.add_charm(charm)

func reset_player_data() -> void:
	player_data = DEFAULT_PLAYER_DATA.duplicate(true)

# ============ PLAYER STATS ============

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

func get_charm_inventory() -> CharmInventory:
	"""Get the charm inventory"""
	return charm_inventory

func unlock_charm(charm_id: String) -> void:
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

func get_equipped_charms() -> Array[CharmData]:
	"""Get all equipped charms"""
	if charm_inventory:
		return charm_inventory.get_equipped_charms()
	return []

func get_charm_buffs() -> Dictionary:
	"""Get total buffs from equipped charms"""
	if charm_inventory:
		return charm_inventory.get_total_buffs()
	return {}

# ============ SAVE/LOAD ============

func get_save_data() -> Dictionary:
	"""Get current game state as save data"""
	var save_data = {
		"player": {
			"hp": player_data["hp"],
			"max_hp": player_data["max_hp"],
			"mp": player_data["mp"],
			"max_mp": player_data["max_mp"],
			"attack": player_data["attack"],
			"unlocked_abilities": player_data["unlocked_abilities"].keys()
		},
		"charm_inventory": {
			"equipped_charm_ids": charm_inventory.equipped_charm_ids,
			"charms": {}
		}
	}
	
	# Save charm states
	for charm_id in charm_inventory.charms.keys():
		var charm = charm_inventory.charms[charm_id]
		save_data["charm_inventory"]["charms"][charm_id] = {
			"is_unlocked": charm.is_unlocked,
			"is_equipped": charm.is_equipped
		}
	
	return save_data

func load_game(save_data: Dictionary) -> void:
	"""Load game state from save file"""
	if save_data.has("player"):
		var player_info = save_data["player"]
		player_data["hp"] = player_info.get("hp", 100)
		player_data["max_hp"] = player_info.get("max_hp", 100)
		player_data["mp"] = player_info.get("mp", 100.0)
		player_data["max_mp"] = player_info.get("max_mp", 100.0)
		player_data["attack"] = player_info.get("attack", 10)
		
		# Load abilities
		var abilities = player_info.get("unlocked_abilities", [])
		for ability in abilities:
			unlock_ability(ability)
	
	# Load charm inventory
	if save_data.has("charm_inventory") and charm_inventory:
		load_charm_inventory(save_data["charm_inventory"])

func load_charm_inventory(charm_data: Dictionary) -> void:
	"""Load charm inventory from save data"""
	# Load charm states
	if charm_data.has("charms"):
		for charm_id in charm_data["charms"].keys():
			var charm = charm_inventory.get_charm(charm_id)
			if charm:
				var saved_state = charm_data["charms"][charm_id]
				charm.is_unlocked = saved_state.get("is_unlocked", false)
				charm.is_equipped = saved_state.get("is_equipped", false)
	
	# Load equipped charms list
	if charm_data.has("equipped_charm_ids"):
		charm_inventory.equipped_charm_ids = charm_data["equipped_charm_ids"]
