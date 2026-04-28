extends AnimatableBody2D

@export var floor_markers: Array[Node2D] 

func _ready():
	SignalBus.move_elevator.connect(move_to_floor)

var is_moving = false

func move_to_floor(index: int):
	if is_moving:
		return
	is_moving = true
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", floor_markers[index].global_position, 1.5)
	
	await tween.finished
	is_moving = false
