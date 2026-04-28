extends Area2D

@export var heal_amount_per_second: float = 10.0
@export var sit_animation_name: String = "Sit"

var player: Node = null
var is_player_sitting: bool = false
var heal_timer: float = 0.0
var current_inventory_ui: Node = null

@onready var interact_prompt: Label = $PromptLayer/InteractPrompt

const inventory_ui_scene = preload("res://menus/InventoryUI.tscn")

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interact_prompt.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		interact_prompt.visible = true
		show_sit_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		is_player_sitting = false
		interact_prompt.visible = false
		stop_sitting()

func show_sit_prompt() -> void:
	await get_tree().process_frame
	while player != null and not is_player_sitting:
		if Input.is_action_just_pressed("interact"):
			sit_at_altar()
			break
		await get_tree().process_frame

func sit_at_altar() -> void:
	if player == null:
		return
	
	is_player_sitting = true
	interact_prompt.visible = false
	
	save_game()
	play_sit_animation()
	open_inventory()
	
	GameManager.set_player_hp(GameManager.get_player_max_hp())

func play_sit_animation() -> void:
	if player == null:
		return

	if player.has_method("sit_at_altar"):
		player.call("sit_at_altar")
		return
	
	if player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")
		if sprite and sprite.sprite_frames.has_animation(sit_animation_name):
			sprite.play(sit_animation_name)

func open_inventory() -> void:
	if current_inventory_ui:
		current_inventory_ui.queue_free()
	
	current_inventory_ui = inventory_ui_scene.instantiate()
	current_inventory_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	current_inventory_ui.tree_exited.connect(_on_inventory_closed)
	get_tree().root.add_child(current_inventory_ui)
	
	if current_inventory_ui.has_method("set_at_altar"):
		current_inventory_ui.set_at_altar(true)
	
	get_tree().paused = true

func _on_inventory_closed() -> void:
	current_inventory_ui = null
	stop_sitting()
	if player != null:
		interact_prompt.visible = true
		show_sit_prompt()

func start_healing() -> void:
	while is_player_sitting and player != null:
		await get_tree().create_timer(1.0).timeout
		
		if is_player_sitting and player != null:
			heal_player(heal_amount_per_second)

func heal_player(amount: float) -> void:
	if player == null:
		return
	
	var current_hp = GameManager.get_player_hp()
	var max_hp = GameManager.get_player_max_hp()
	
	current_hp = min(current_hp + amount, max_hp)
	GameManager.set_player_hp(current_hp)
	
	if current_hp >= max_hp:
		stop_sitting()

func stop_sitting() -> void:
	is_player_sitting = false

	if player and player.has_method("stop_sitting_at_altar"):
		player.call("stop_sitting_at_altar")
		return
	
	if player and player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")
		if sprite:
			sprite.play("Idle")

func save_game() -> void:
	if player == null:
		return
	
	var save_data = SaveData.new()
	
	save_data.hp = GameManager.get_player_hp()
	save_data.max_hp = GameManager.get_player_max_hp()
	save_data.mp = GameManager.get_player_mp()
	save_data.max_mp = GameManager.get_player_max_mp()
	save_data.attack = GameManager.get_player_attack()
	save_data.unlocked_abilities = GameManager.get_unlocked_abilities().duplicate()
	
	save_data.position = player.global_position
	save_data.level = get_tree().current_scene.name
	save_data.level_path = get_tree().current_scene.scene_file_path
	save_data.saved_at = Time.get_datetime_string_from_system(false, true)
	
	var charm_inventory = GameManager.get_charm_inventory()
	
	var unlocked_charms_array = []
	for charm_id in charm_inventory.unlocked_charms.keys():
		if charm_inventory.unlocked_charms[charm_id]:
			unlocked_charms_array.append(charm_id)
	
	save_data.unlocked_charms = unlocked_charms_array
	save_data.equipped_charm_ids = charm_inventory.equipped_charm_ids.duplicate()
	
	var error = ResourceSaver.save(save_data, GameManager.get_save_path())
	if error == OK:
		print("Game autosaved successfully!")
	else:
		print("Error saving game: ", error)
