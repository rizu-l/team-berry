extends Node
class_name AbilityData

enum ability_list {
	WINGS,
	BLINK
}

const INFO: Dictionary = {
	ability_list.WINGS: {
		"name" : "Wings of the Fallen",
		"description" : "Jump while in the air once!",
		"icon" : preload	("res://icons/wings-icon.png"),
	},
	ability_list.BLINK: {
		"name" : "Blink Step",
		"description" : "Teleport forward and stop just before walls.",
		"icon" : preload("res://player/blink.png"),
	},
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
