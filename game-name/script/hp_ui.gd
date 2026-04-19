extends Control

@onready var hp_bar: TextureProgressBar = $HPBar
@onready var hp_label: Label = $Label
@onready var mp_ui: Control = get_node_or_null("../MPUI") as Control
@onready var mp_bar: TextureProgressBar = get_node_or_null("../MPUI/TextureProgressBar") as TextureProgressBar
@onready var mp_label: Label = get_node_or_null("../MPUI/Label") as Label
@onready var boss_ui: Control = get_node_or_null("../BossUI") as Control
@onready var boss_name_label: Label = get_node_or_null("../BossUI/BossName") as Label
@onready var boss_bar: TextureProgressBar = get_node_or_null("../BossUI/BossBar") as TextureProgressBar

func _ready() -> void:
	update_hp_display()

func _process(_delta: float) -> void:
	update_hp_display()

func update_hp_display() -> void:
	var current_hp: int = GameManager.get_player_hp()
	var max_hp: int = GameManager.get_player_max_hp()
	var current_mp: float = GameManager.get_player_mp()
	var max_mp: float = GameManager.get_player_max_mp()

	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = str(current_hp)

	if mp_bar != null:
		mp_bar.max_value = max_mp
		mp_bar.value = current_mp

	if mp_label != null:
		mp_label.text = str(int(round(current_mp)))

	update_boss_display()

func update_boss_display() -> void:
	if boss_ui == null:
		return

	var boss := get_tree().get_first_node_in_group("bosses") as EnemyBase
	if boss == null or boss.is_dead:
		boss_ui.visible = false
		return

	boss_ui.visible = true

	if boss_name_label != null:
		boss_name_label.text = boss.enemy_name

	if boss_bar != null:
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp
