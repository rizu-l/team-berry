extends Control

@onready var master_volume_slider = $VBoxContainer/MasterVolumeSlider
@onready var music_volume_slider = $VBoxContainer/MusicVolumeSlider
@onready var sfx_volume_slider = $VBoxContainer/SFXVolumeSlider
@onready var back_button = $VBoxContainer/BackButton

func _ready():
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	back_button.pressed.connect(_on_back_pressed)
	
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	var error = config.load("user://settings.cfg")
	
	if error == OK:
		master_volume_slider.value = config.get_value("audio", "master_volume", 0.8)
		music_volume_slider.value = config.get_value("audio", "music_volume", 0.7)
		sfx_volume_slider.value = config.get_value("audio", "sfx_volume", 0.8)
	else:
		master_volume_slider.value = 0.8
		music_volume_slider.value = 0.7
		sfx_volume_slider.value = 0.8

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume_slider.value)
	config.set_value("audio", "music_volume", music_volume_slider.value)
	config.set_value("audio", "sfx_volume", sfx_volume_slider.value)
	config.save("user://settings.cfg")

func _on_master_volume_changed(value: float):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), false)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	save_settings()

func _on_music_volume_changed(value: float):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))
	save_settings()

func _on_sfx_volume_changed(value: float):
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), false)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))
	save_settings()

func _on_back_pressed():
	print("Returning to main menu...")
	queue_free()
