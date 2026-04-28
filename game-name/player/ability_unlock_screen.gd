extends CanvasLayer

@onready var NameLabel: Label = $ColorRect/CenterContainer/VBoxContainer/VBoxContainer/NameLabel
@onready var DescriptionLabel: Label = $ColorRect/CenterContainer/VBoxContainer/VBoxContainer/DescriptionLabel
@onready var IconIMGNode: TextureRect = $ColorRect/CenterContainer/VBoxContainer/IconIMG

var ability_to_show: AbilityData.ability_list

func _ready() -> void:
	get_tree().paused = true
	
	NameLabel.text = AbilityData.INFO[ability_to_show]["name"]
	DescriptionLabel.text = AbilityData.INFO[ability_to_show]["description"]
	IconIMGNode.texture = AbilityData.INFO[ability_to_show]["icon"]
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		close()

func _on_close_button_pressed() -> void:
	close()

func close() -> void:
	get_tree().paused = false
	queue_free()
