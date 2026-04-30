extends CanvasLayer

const CHARM_DATA := preload("res://script/charm_data.gd")

@onready var NameLabel: Label = $ColorRect/CenterContainer/VBoxContainer/VBoxContainer/NameLabel
@onready var DescriptionLabel: Label = $ColorRect/CenterContainer/VBoxContainer/VBoxContainer/DescriptionLabel
@onready var IconIMGNode: TextureRect = $ColorRect/CenterContainer/VBoxContainer/IconIMG

var charm_to_show: int

func _ready() -> void:
	get_tree().paused = true
	
	NameLabel.text = CHARM_DATA.INFO[charm_to_show]["name"]
	DescriptionLabel.text = CHARM_DATA.INFO[charm_to_show]["description"]
	IconIMGNode.texture = CHARM_DATA.INFO[charm_to_show]["icon"]

func _on_close_button_pressed() -> void:
	get_tree().paused = false
	queue_free()
