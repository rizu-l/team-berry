extends Control

@onready var menu_container = $VBoxContainer
@onready var start_button = $VBoxContainer/StartButton
@onready var load_button = $VBoxContainer/LoadButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

const settings_scene = preload("res://menus/settings_Menu.tscn")
const save_slot_scene = preload("res://menus/save_slot_menu.tscn")

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	animate_menu_in()

func animate_menu_in():
	var buttons = [start_button, load_button, settings_button, quit_button]
	for i in range(buttons.size()):
		buttons[i].modulate.a = 0
		await get_tree().create_timer(i * 0.15).timeout
		var tween = create_tween()
		tween.tween_property(buttons[i], "modulate:a", 1.0, 0.3)

func _on_start_pressed():
	open_save_slots(false)

func _on_load_pressed():
	open_save_slots(true)

func open_save_slots(load_mode: bool) -> void:
	var save_slot_menu = save_slot_scene.instantiate()
	get_tree().root.add_child(save_slot_menu)
	if save_slot_menu.has_method("setup"):
		save_slot_menu.setup(load_mode)

func _on_settings_pressed():
	print("Opening settings...")
	var settings_menu = settings_scene.instantiate()
	add_child(settings_menu)

func _on_quit_pressed():
	print("Quitting game...")
	get_tree().quit()
