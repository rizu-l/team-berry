extends Area2D
# Attach to your altar object

@export var heal_amount_per_second: float = 20.0
@onready var interact_prompt: Label = $InteractPrompt

var player: Node = null
var is_player_sitting: bool = false
var heal_timer: float = 0.0

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		interact_prompt.visible = true  # Show the label
		show_sit_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		is_player_sitting = false
		interact_prompt.visible = false  # Hide the label

func show_sit_prompt() -> void:
	"""Wait for player to press E to sit"""
	await get_tree().process_frame
	while player != null and not is_player_sitting:
		if Input.is_action_just_pressed("ui_interact"):
			sit_at_altar()
			break
		await get_tree().process_frame

func sit_at_altar() -> void:
	"""Player sits at altar"""
	if player == null:
		return
	
	is_player_sitting = true
	hide_altar_message()
	show_altar_message("Resting...", 0.0)  # Message stays while resting
	
	# Save immediately
	save_game()
	
	# Start healing
	start_healing()

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
	show_altar_message("Fully healed!")

func save_game() -> void:
	"""Save the game state"""
	if player == null:
		return
	
	# Prepare save data using GameManager
	var save_data = {
		"position": player.global_position,
		"hp": GameManager.get_player_hp(),
		"max_hp": GameManager.get_player_max_hp(),
		"mp": GameManager.get_player_mp(),
		"max_mp": GameManager.get_player_max_mp(),
		"attack": GameManager.get_player_attack(),
		"unlocked_abilities": GameManager.get_unlocked_abilities(),
		"level": get_tree().current_scene.name
	}
	
	# Save to file
	var save_file = FileAccess.open("user://autosave.save", FileAccess.WRITE)
	if save_file:
		save_file.store_var(save_data)

func show_altar_message(message: String, duration: float = 3.0) -> void:
	"""Show a fading message on screen"""
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 48)
	
	# Position at center top of screen
	label.anchor_left = 0.5
	label.anchor_top = 0.2
	label.anchor_right = 0.5
	label.anchor_bottom = 0.2
	label.offset_x = 0
	label.offset_y = 0
	
	# Add styling for visibility
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_to_group("altar_message")
	
	# Add to CanvasLayer so it's always on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().root.add_child(canvas_layer)
	canvas_layer.add_child(label)
	
	# Start invisible
	label.modulate.a = 0.0
	
	# Fade in
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	
	if duration > 0:
		# Wait and fade out
		await get_tree().create_timer(duration).timeout
		if label and not label.is_queued_for_deletion():
			var tween2 = create_tween()
			tween2.tween_property(label, "modulate:a", 0.0, 0.5)
			await tween2.finished
			label.queue_free()
			canvas_layer.queue_free()

func hide_altar_message() -> void:
	"""Hide all altar messages"""
	for msg in get_tree().get_nodes_in_group("altar_message"):
		if msg:
			msg.queue_free()
