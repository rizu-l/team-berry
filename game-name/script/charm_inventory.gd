extends Resource
class_name CharmInventory

const MAX_EQUIPPED = 4

var unlocked_charms: Dictionary = {}
var equipped_charm_ids: Array = []

func _init():
	unlock_charm(CharmData.charm_list.VITALITY_CHARM)
	unlock_charm(CharmData.charm_list.SHARP_EDGE)
	unlock_charm(CharmData.charm_list.MYSTIC_WELL)

func unlock_charm(charm_id) -> bool:
	if not CharmData.INFO.has(charm_id):
		return false
	
	unlocked_charms[charm_id] = true
	return true

func is_charm_unlocked(charm_id) -> bool:
	return unlocked_charms.get(charm_id, false)

func equip_charm(charm_id) -> bool:
	if not is_charm_unlocked(charm_id):
		return false
	
	if equipped_charm_ids.has(charm_id):
		return false
	
	if equipped_charm_ids.size() >= MAX_EQUIPPED:
		return false
	
	equipped_charm_ids.append(charm_id)
	return true

func unequip_charm(charm_id) -> bool:
	if not equipped_charm_ids.has(charm_id):
		return false
	
	equipped_charm_ids.erase(charm_id)
	return true

func toggle_charm(charm_id) -> bool:
	if equipped_charm_ids.has(charm_id):
		return unequip_charm(charm_id)
	else:
		return equip_charm(charm_id)

func get_equipped_charms() -> Array:
	return equipped_charm_ids.duplicate()

func get_total_buffs() -> Dictionary:
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
	return equipped_charm_ids.has(charm_id)

func can_equip_charm(charm_id) -> bool:
	if not is_charm_unlocked(charm_id):
		return false
	
	if equipped_charm_ids.has(charm_id):
		return false
	
	if equipped_charm_ids.size() >= MAX_EQUIPPED:
		return false
	
	return true

func get_charm(charm_id) -> Dictionary:
	if not CharmData.INFO.has(charm_id):
		return {}

	var charm_info: Dictionary = CharmData.INFO[charm_id]
	return {
		"charm_id": charm_id,
		"display_name": charm_info.get("name", "Unknown Charm"),
		"description": charm_info.get("description", ""),
		"icon": charm_info.get("icon", null),
		"stat_buffs": charm_info.get("stat_buffs", {}),
		"effect_text": get_effect_text(charm_info.get("stat_buffs", {})),
		"is_unlocked": is_charm_unlocked(charm_id),
		"is_equipped": is_charm_equipped(charm_id),
	}

func get_effect_text(stat_buffs: Dictionary) -> String:
	var effects: Array[String] = []
	for stat in stat_buffs.keys():
		var stat_name := String(stat).capitalize().replace("_", " ")
		var value = stat_buffs[stat]
		if value is float:
			effects.append("%s +%.1f" % [stat_name, value])
		else:
			effects.append("%s +%d" % [stat_name, int(value)])
	return ", ".join(effects)

func get_all_charms() -> Array:
	var charms: Array = []
	for charm_id in CharmData.INFO.keys():
		charms.append(get_charm(charm_id))
	return charms

func get_equipped_charm_details() -> Array:
	var charms: Array = []
	for charm_id in equipped_charm_ids:
		var charm := get_charm(charm_id)
		if not charm.is_empty():
			charms.append(charm)
	return charms
