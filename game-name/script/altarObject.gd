extends Area2D
# Altar that player can sit at to rest, heal, and save

@export var heal_amount_per_second: float = 10.0
@export var sit_animation_name: String = "Sit"  # Animation name for sitting

var player: Node = null
var is_player_sitting: bool = false
var heal_timer: float = 0.0
var current_inventory_ui: Control = null

@onready var interact_prompt: Label = $InteractPrompt

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
	"""Wait for player to press E to sit"""
	await get_tree().process_frame
	while player != null and not is_player_sitting:
		if Input.is_action_just_pressed("ui_interact"):
			sit_at_altar()
			break
		await get_tree().process_frame

func sit_at_altar() -> void:
	"""Player sits at altar - autosave immediately, then play animation and open inventory"""
	if player == null:
		return
	
	is_player_sitting = true
	interact_prompt.visible = false
	
	# AUTOSAVE IMMEDIATELY
	save_game()
	
	# Play sit animation
	play_sit_animation()
	
	# Open inventory
	open_inventory()
	
	# Start healing (optional, just for flavor)
	start_healing()

func play_sit_animation() -> void:
	"""Play the sit animation on the player"""
	if player == null or not player.has_method("play_animation"):
		return
	
	# If player has AnimatedSprite2D, play sit animation
	if player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")
		if sprite and sprite.sprite_frames.has_animation(sit_animation_name):
			sprite.play(sit_animation_name)

func open_inventory() -> void:
	"""Open the inventory UI"""
	if current_inventory_ui:
		current_inventory_ui.queue_free()
	
	current_inventory_ui = inventory_ui_scene.instantiate()
	get_tree().root.add_child(current_inventory_ui)
	
	# Tell inventory we're at an altar (enables equip/unequip)
	if current_inventory_ui.has_method("set_at_altar"):
		current_inventory_ui.set_at_altar(true)
	
	# Pause the game
	get_tree().paused = true

func start_healing() -> void:
	"""Heal the player while sitting"""
	while is_player_sitting and player != null:
		await get_tree().create_timer(1.0).timeout
		
		if is_player_sitting and player != null:
			heal_player(heal_amount_per_second)

func heal_player(amount: float) -> void:
	"""Heal the player"""
	if player == null:
		return
	
	# Use GameManager to heal
	var current_hp = GameManager.get_player_hp()
	var max_hp = GameManager.get_player_max_hp()
	
	# Heal
	current_hp = min(current_hp + amount, max_hp)
	GameManager.set_player_hp(current_hp)
	
	# Stop healing if fully healed
	if current_hp >= max_hp:
		stop_sitting()

func stop_sitting() -> void:
	"""Player stops sitting"""
	is_player_sitting = false
	
	# Resume normal animation
	if player and player.has_node("AnimatedSprite2D"):
		var sprite = player.get_node("AnimatedSprite2D")
		if sprite:
			sprite.play("Idle")

func save_game() -> void:
	"""Save the game state using Godot Resources"""
	if player == null:
		return
	
	# Create SaveData resource
	var save_data = SaveData.new()
	
	# Save player stats from GameManager
	save_data.hp = GameManager.get_player_hp()
	save_data.max_hp = GameManager.get_player_max_hp()
	save_data.mp = GameManager.get_player_mp()
	save_data.max_mp = GameManager.get_player_max_mp()
	save_data.attack = GameManager.get_player_attack()
	save_data.unlocked_abilities = GameManager.get_unlocked_abilities().duplicate()
	
	# Save position and level
	save_data.position = player.global_position
	save_data.level = get_tree().current_scene.name
	
	# Save charm inventory
	var charm_inventory = GameManager.get_charm_inventory()
	
	# Save unlocked charms as array of keys (like abilities)
	var unlocked_charms_array = []
	for charm_id in charm_inventory.unlocked_charms.keys():
		if charm_inventory.unlocked_charms[charm_id]:
			unlocked_charms_array.append(charm_id)
	
	save_data.unlocked_charms = unlocked_charms_array
	save_data.equipped_charm_ids = charm_inventory.equipped_charm_ids.duplicate()
	
	# Save to file using ResourceSaver
	var error = ResourceSaver.save(save_data, "user://autosave.tres")
	if error == OK:
		print("Game autosaved successfully!")
	else:
		print("Error saving game: ", error)
