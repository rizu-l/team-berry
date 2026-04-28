extends CanvasLayer
# Popup that displays when a charm is unlocked
# Mirrors ability_unlock_screen.gd pattern exactly

@onready var NameLabel: Label = $ColorRect/CenterContainer/VBoxContainer/VBoxContainer/NameLabel
@onready var DescriptionLabel: Label = $ColorRect/CenterContainer/VBoxContainer/VBoxContainer/DescriptionLabel
@onready var IconIMGNode: TextureRect = $ColorRect/CenterContainer/VBoxContainer/IconIMG

var charm_to_show: CharmData.charm_list

func _ready() -> void:
	get_tree().paused = true
	
	NameLabel.text = CharmData.INFO[charm_to_show]["name"]
	DescriptionLabel.text = CharmData.INFO[charm_to_show]["description"]
	IconIMGNode.texture = CharmData.INFO[charm_to_show]["icon"]

func _on_close_button_pressed() -> void:
	get_tree().paused = false
	queue_free()
