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
	ARCANE_KNOWLEDGE,
	MIDAS_CHARM,
	RULER_CHARM,
	SENTRY_CHARM,
	SOUL_CRUSHER
}

const INFO: Dictionary = {
	charm_list.VITALITY_CHARM: {
		"name": "Vitality Charm",
		"description": "Increases your maximum health",
		"icon": preload("res://assets/charms/vitality.png"),
		"stat_buffs": {"max_hp": 20}
	},
	charm_list.SHARP_EDGE: {
		"name": "Sharp Edge",
		"description": "Enhances your attack power",
		"icon": preload("res://assets/charms/release_v1.2-single_48.png"),
		"stat_buffs": {"attack": 5}
	},
	charm_list.MYSTIC_WELL: {
		"name": "Mystic Well",
		"description": "Expands your magical reserves",
		"icon": preload("res://assets/charms/release_v1.2-single_2.png"),
		"stat_buffs": {"max_mp": 10}
	},
	charm_list.MANA_FLOW: {
		"name": "Mana Flow",
		"description": "Enhances magical regeneration",
		"icon": preload("res://assets/charms/release_v1.2-single_68.png"),
		"stat_buffs": {"mp_regen": 1.5}
	},
	charm_list.GUARDIAN_AURA: {
		"name": "Guardian Aura",
		"description": "Slowly regenerate health over time",
		"icon": preload("res://assets/charms/release_v1.2-single_57.png"),
		"stat_buffs": {"max_hp": 10}
	},
	charm_list.SWIFT_REFLEXES: {
		"name": "Swift Reflexes",
		"description": "Improve your reaction time and speed",
		"icon": preload("res://assets/charms/release_v1.2-single_78.png"),
		"stat_buffs": {"attack": 3}
	},
	charm_list.IRON_RESOLVE: {
		"name": "Iron Resolve",
		"description": "Fortify your body and spirit",
		"icon": preload("res://assets/charms/release_v1.2-single_60.png"),
		"stat_buffs": {"max_hp": 15, "attack": 2}
	},
	charm_list.ARCANE_KNOWLEDGE: {
		"name": "Arcane Knowledge",
		"description": "Channel magical and physical power",
		"icon": preload("res://assets/charms/release_v1.2-single_87.png"),
		"stat_buffs": {"max_mp": 15, "attack": 3}
	},
	charm_list.MIDAS_CHARM: {
		"name": "Midas Charm",
		"description": "A gilded charm that strengthens magic and ambition",
		"icon": preload("res://assets/charms/midas.png"),
		"stat_buffs": {"max_mp": 8, "attack": 1}
	},
	charm_list.RULER_CHARM: {
		"name": "Ruler Charm",
		"description": "A royal charm that rewards precise strikes",
		"icon": preload("res://assets/charms/ruler.png"),
		"stat_buffs": {"attack": 4}
	},
	charm_list.SENTRY_CHARM: {
		"name": "Sentry Charm",
		"description": "A watchful charm that reinforces your defenses",
		"icon": preload("res://assets/charms/sentry.png"),
		"stat_buffs": {"max_hp": 8, "max_mp": 5}
	},
	charm_list.SOUL_CRUSHER: {
		"name": "Soul Crusher",
		"description": "A fierce charm that greatly increases attack power",
		"icon": preload("res://assets/charms/soul_crusher.png"),
		"stat_buffs": {"attack": 8}
	},
}

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass
