extends Node
class_name CharmData

enum charm_list {
	VITALITY_CHARM,
	SHARP_EDGE,
	MYSTIC_WELL,
	MANA_FLOW,
	GUARDIAN_AURA,
	SWIFT_REFLEXES,
	IRON_RESOLVE,
	ARCANE_KNOWLEDGE
}

const INFO: Dictionary = {
	charm_list.VITALITY_CHARM: {
		"name": "Vitality Charm",
		"description": "Increases your maximum health",
		"icon": preload("res://icons/wings-icon.png"),
		"stat_buffs": {"max_hp": 20}
	},
	charm_list.SHARP_EDGE: {
		"name": "Sharp Edge",
		"description": "Enhances your attack power",
		"icon": preload("res://icons/wings-icon.png"),
		"stat_buffs": {"attack": 5}
	},
	charm_list.MYSTIC_WELL: {
		"name": "Mystic Well",
		"description": "Expands your magical reserves",
		"icon": preload("res://icons/wings-icon.png"),
		"stat_buffs": {"max_mp": 10}
	},
	charm_list.MANA_FLOW: {
		"name": "Mana Flow",
		"description": "Enhances magical regeneration",
		"icon": preload("res://icons/wings-icon.png"),
		"stat_buffs": {"mp_regen": 1.5}
	},
	charm_list.GUARDIAN_AURA: {
		"name": "Guardian Aura",
		"description": "Slowly regenerate health over time",
		"icon": preload("res://icons/wings-icon.png"),
		"stat_buffs": {"max_hp": 10}
	},
	charm_list.SWIFT_REFLEXES: {
		"name": "Swift Reflexes",
		"description": "Improve your reaction time and speed",
		"icon": preload("res://icons/wings-icon.png"),
		"stat_buffs": {"attack": 3}
	},
	charm_list.IRON_RESOLVE: {
		"name": "Iron Resolve",
		"description": "Fortify your body and spirit",
		"icon": preload("res://icons/wings-icon.png"),
		"stat_buffs": {"max_hp": 15, "attack": 2}
	},
	charm_list.ARCANE_KNOWLEDGE: {
		"name": "Arcane Knowledge",
		"description": "Channel magical and physical power",
		"icon": preload("res://icons/wings-icon.png"),
		"stat_buffs": {"max_mp": 15, "attack": 3}
	},
}

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass
