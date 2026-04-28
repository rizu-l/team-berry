extends Resource
class_name SaveData

# Player stats
@export var hp: int = 100
@export var max_hp: int = 100
@export var mp: float = 100.0
@export var max_mp: float = 100.0
@export var attack: int = 10
@export var unlocked_abilities: Dictionary = {}

# Position and level
@export var position: Vector2 = Vector2.ZERO
@export var level: String = "Level1"
@export var level_path: String = "res://Stages/stage_1.tscn"
@export var saved_at: String = ""
@export var play_time_seconds: float = 0.0

# Charm inventory - track unlocked and equipped charms
@export var unlocked_charms: Array = []  # Array of unlocked charm enum values
@export var equipped_charm_ids: Array = []  # Array of equipped charm enum values

func _init(p_hp = 100, p_max_hp = 100, p_mp = 100.0, p_max_mp = 100.0, p_attack = 10):
	hp = p_hp
	max_hp = p_max_hp
	mp = p_mp
	max_mp = p_max_mp
	attack = p_attack
