extends Resource
class_name CharmInventory

const MAX_EQUIPPED = 4

# Track unlocked and equipped charms by their enum ID
var unlocked_charms: Dictionary = {}
var equipped_charm_ids: Array = []

func _init():
	pass

func unlock_charm(charm_id) -> bool:
	"""Unlock a charm"""
	if not CharmData.INFO.has(charm_id):
		return false
	
	unlocked_charms[charm_id] = true
	return true

func is_charm_unlocked(charm_id) -> bool:
	return unlocked_charms.get(charm_id, false)

func equip_charm(charm_id) -> bool:
	if not is_charm_unlocked(charm_id):
		return false
	
	# Already equipped
	if equipped_charm_ids.has(charm_id):
		return false
	
	# No space
	if equipped_charm_ids.size() >= MAX_EQUIPPED:
		return false
	
	equipped_charm_ids.append(charm_id)
	return true

func unequip_charm(charm_id) -> bool:
	"""Unequip a charm"""
	if not equipped_charm_ids.has(charm_id):
		return false
	
	equipped_charm_ids.erase(charm_id)
	return true

func toggle_charm(charm_id) -> bool:
	"""Toggle charm equip status"""
	if equipped_charm_ids.has(charm_id):
		return unequip_charm(charm_id)
	else:
		return equip_charm(charm_id)

func get_equipped_charms() -> Array:
	"""Get all equipped charm IDs"""
	return equipped_charm_ids.duplicate()

func get_total_buffs() -> Dictionary:
	"""Calculate total buffs from equipped charms"""
	var total_buffs = {
		"max_hp": 0,
		"attack": 0,
		"mp": 0,
		"max_mp": 0,
		"mp_regen": 0.0,
	}
	
	for charm_id in equipped_charm_ids:
		if CharmData.INFO.has(charm_id):
			var charm_info = CharmData.INFO[charm_id]
			if charm_info.has("stat_buffs"):
				var buffs = charm_info["stat_buffs"]
				for stat in buffs.keys():
					if total_buffs.has(stat):
						total_buffs[stat] += buffs[stat]
	
	return total_buffs

func is_charm_equipped(charm_id) -> bool:
	"""Check if a charm is equipped"""
	return equipped_charm_ids.has(charm_id)

func can_equip_charm(charm_id) -> bool:
	"""Check if a charm can be equipped"""
	if not is_charm_unlocked(charm_id):
		return false
	
	if equipped_charm_ids.has(charm_id):
		return false
	
	if equipped_charm_ids.size() >= MAX_EQUIPPED:
		return false
	
	return true
