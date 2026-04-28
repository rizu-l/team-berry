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

func _ready():
	RenderingServer.set_default_clear_color(Color(0.30,0.30,0.30,1.00))

func reset_player_data() -> void:
	player_data = DEFAULT_PLAYER_DATA.duplicate(true)

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
