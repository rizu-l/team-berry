extends Node
class_name AbilityData

enum ability_list {
	WINGS
}

const INFO: Dictionary = {
	ability_list.WINGS: {
		"name" : "Wings of the Fallen",
		"description" : "Jump while in the air once!",
		"icon" : preload	("res://icons/wings-icon.png"),
	},
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
