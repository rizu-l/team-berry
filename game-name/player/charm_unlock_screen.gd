extends CanvasLayer

const CHARM_DATA := preload("res://script/charm_data.gd")

@onready var NameLabel: Label = $ColorRect/CenterContainer/VBoxContainer/VBoxContainer/NameLabel
@onready var DescriptionLabel: Label = $ColorRect/CenterContainer/VBoxContainer/VBoxContainer/DescriptionLabel
@onready var IconIMGNode: TextureRect = $ColorRect/CenterContainer/VBoxContainer/IconIMG

var charm_to_show: int
var charm_data = CHARM_DATA.new()

func _ready() -> void:
	get_tree().paused = true
	
	var charm_info: Dictionary = charm_data.get_charm_info(charm_to_show)
	NameLabel.text = charm_info.get("name", "Unknown Charm")
	DescriptionLabel.text = charm_info.get("description", "")
	IconIMGNode.texture = charm_info.get("icon", null)

func _on_close_button_pressed() -> void:
	get_tree().paused = false
	queue_free()
