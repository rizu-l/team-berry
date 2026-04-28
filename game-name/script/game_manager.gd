extends Node
const DEFAULT_PLAYER_DATA := {
	"base_max_hp": 100,
	"hp": 100,
	"base_max_mp": 100.0,
	"mp": 100.0,
	"base_attack": 10,
	"base_mp_regen": 3.0,
	"unlocked_abilities": {}
}
var player_data: Dictionary = DEFAULT_PLAYER_DATA.duplicate(true)
var charm_inventory: CharmInventory
var current_save_slot: int = 1
var pending_player_position: Vector2 = Vector2.ZERO
var has_pending_player_position: bool = false
var player_stats_initialized: bool = false

const FIRST_LEVEL_PATH := "res://Stages/stage_1.tscn"

func _ready():
	RenderingServer.set_default_clear_color(Color(0.30,0.30,0.30,1.00))
	charm_inventory = CharmInventory.new()

func reset_player_data() -> void:
	player_data = DEFAULT_PLAYER_DATA.duplicate(true)
	has_pending_player_position = false
	charm_inventory = CharmInventory.new()
	player_stats_initialized = false

func initialize_player_defaults(
	base_max_hp: int,
	current_hp: int,
	base_max_mp: float,
	current_mp: float,
	base_attack: int,
	base_mp_regen: float
) -> void:
	if player_stats_initialized:
		return

	player_data["base_max_hp"] = max(base_max_hp, 1)
	player_data["base_max_mp"] = maxf(base_max_mp, 0.0)
	player_data["base_attack"] = max(base_attack, 0)
	player_data["base_mp_regen"] = maxf(base_mp_regen, 0.0)
	player_stats_initialized = true
	set_player_hp(current_hp)
	set_player_mp(current_mp)

func refresh_player_stats() -> void:
	player_data["hp"] = clampi(int(player_data["hp"]), 0, get_player_max_hp())
	player_data["mp"] = clampf(float(player_data["mp"]), 0.0, get_player_max_mp())

func get_player_hp() -> int:
	return player_data["hp"]

func set_player_hp(value: int) -> void:
	player_data["hp"] = clampi(value, 0, get_player_max_hp())

func get_player_max_hp() -> int:
	return max(1, int(player_data.get("base_max_hp", DEFAULT_PLAYER_DATA["base_max_hp"])) + int(get_charm_buffs().get("max_hp", 0)))

func set_player_max_hp(value: int) -> void:
	var charm_bonus := int(get_charm_buffs().get("max_hp", 0))
	player_data["base_max_hp"] = max(value - charm_bonus, 1)
	refresh_player_stats()

func get_player_mp() -> float:
	return player_data["mp"]

func set_player_mp(value: float) -> void:
	player_data["mp"] = clampf(value, 0.0, get_player_max_mp())

func get_player_max_mp() -> float:
	return maxf(0.0, float(player_data.get("base_max_mp", DEFAULT_PLAYER_DATA["base_max_mp"])) + float(get_charm_buffs().get("max_mp", 0.0)))

func set_player_max_mp(value: float) -> void:
	var charm_bonus := float(get_charm_buffs().get("max_mp", 0.0))
	player_data["base_max_mp"] = maxf(value - charm_bonus, 0.0)
	refresh_player_stats()

func get_player_attack() -> int:
	return max(0, int(player_data.get("base_attack", DEFAULT_PLAYER_DATA["base_attack"])) + int(get_charm_buffs().get("attack", 0)))

func set_player_attack(value: int) -> void:
	var charm_bonus := int(get_charm_buffs().get("attack", 0))
	player_data["base_attack"] = max(value - charm_bonus, 0)

func get_player_mp_regen() -> float:
	return maxf(0.0, float(player_data.get("base_mp_regen", DEFAULT_PLAYER_DATA["base_mp_regen"])) + float(get_charm_buffs().get("mp_regen", 0.0)))

func set_player_mp_regen(value: float) -> void:
	var charm_bonus := float(get_charm_buffs().get("mp_regen", 0.0))
	player_data["base_mp_regen"] = maxf(value - charm_bonus, 0.0)

func get_unlocked_abilities() -> Dictionary:
	return player_data["unlocked_abilities"]

func has_ability(ability) -> bool:
	return player_data["unlocked_abilities"].has(ability)

func unlock_ability(ability) -> void:
	player_data["unlocked_abilities"][ability] = true

func is_charm_unlocked(charm_id) -> bool:
	if charm_inventory:
		return charm_inventory.is_charm_unlocked(charm_id)
	return false

func unlock_charm(charm_id) -> void:
	if charm_inventory:
		charm_inventory.unlock_charm(charm_id)

func equip_charm(charm_id) -> bool:
	if charm_inventory:
		var equipped := charm_inventory.equip_charm(charm_id)
		if equipped:
			refresh_player_stats()
		return equipped
	return false

func unequip_charm(charm_id) -> bool:
	if charm_inventory:
		var unequipped := charm_inventory.unequip_charm(charm_id)
		if unequipped:
			refresh_player_stats()
		return unequipped
	return false

func get_equipped_charms() -> Array:
	if charm_inventory:
		return charm_inventory.get_equipped_charms()
	return []

func get_charm_buffs() -> Dictionary:
	if charm_inventory:
		return charm_inventory.get_total_buffs()
	return {}

func get_charm_inventory() -> CharmInventory:
	if charm_inventory == null:
		charm_inventory = CharmInventory.new()
	return charm_inventory

func get_save_path(slot: int = current_save_slot) -> String:
	return "user://save_slot_%d.tres" % clampi(slot, 1, 3)

func set_current_save_slot(slot: int) -> void:
	current_save_slot = clampi(slot, 1, 3)

func load_game(slot: int = current_save_slot) -> bool:
	set_current_save_slot(slot)
	var save_path = get_save_path()
	
	if not ResourceLoader.exists(save_path):
		print("No save file found")
		return false
	
	var save_data = ResourceLoader.load(save_path) as SaveData
	if save_data == null:
		print("Failed to load save file")
		return false
	
	charm_inventory = CharmInventory.new()
	load_charm_inventory(save_data)
	player_stats_initialized = true
	set_player_max_hp(save_data.max_hp)
	set_player_max_mp(save_data.max_mp)
	set_player_attack(save_data.attack)
	player_data["hp"] = save_data.hp
	player_data["mp"] = save_data.mp
	player_data["unlocked_abilities"] = save_data.unlocked_abilities.duplicate()
	refresh_player_stats()

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
	var unlocked_charms_array = save_data.unlocked_charms
	for charm_id in unlocked_charms_array:
		unlock_charm(charm_id)
	
	charm_inventory.equipped_charm_ids = save_data.equipped_charm_ids.duplicate()
