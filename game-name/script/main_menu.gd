extends Control
# Attach this to the root of your menu scene

@onready var menu_container = $VBoxContainer
@onready var start_button = $VBoxContainer/StartButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

const settings_scene = preload("res://menus/settings_menu.tscn")
const game_scene = "res://Stages/stage_1.tscn"  # Change this to your first level

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Optional: Add some animation on startup
	animate_menu_in()

func animate_menu_in():
	"""Animate the menu buttons in on startup"""
	var buttons = [start_button, settings_button, quit_button]
	for i in range(buttons.size()):
		buttons[i].modulate.a = 0
		await get_tree().create_timer(i * 0.15).timeout
		var tween = create_tween()
		tween.tween_property(buttons[i], "modulate:a", 1.0, 0.3)

func _on_start_pressed():
	print("Starting game...")
	# For now, just start a new game
	get_tree().change_scene_to_file(game_scene)

func _on_settings_pressed():
	print("Opening settings...")
	# Instantiate and add the settings menu
	var settings_menu = settings_scene.instantiate()
	add_child(settings_menu)

func _on_quit_pressed():
	print("Quitting game...")
	get_tree().quit()
