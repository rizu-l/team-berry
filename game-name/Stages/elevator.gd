extends AnimatableBody2D

@export var floor_markers: Array[Node2D] 

func _ready():
	# Connect the global signal to this node's function
	SignalBus.move_elevator.connect(move_to_floor)

var is_moving = false

func move_to_floor(index: int):
	if is_moving: return # Prevent spamming
	is_moving = true
	
	# Move logic...
	var tween = create_tween()
	tween.tween_property(self, "global_position", floor_markers[index].global_position, 1.5)
	
	# Wait for movement to finish
	await tween.finished
	is_moving = false
	
# elevator.gd

# Make sure you have a reference to the UI!
# If your UI is an Autoload, use this:
# Inside elevator.gd
@onready var ui = get_node("/root/ElevatorUI") 

#func _on_area_2d_body_entered(body):
	#print("Something touched the elevator: ", body.name) # This will tell us if ANYTHING hits it
	#if body.name == "Player": # Ensure your player node is named "Player"
		#print("Player entered! Showing UI.")
		#ui.show()
	#if ui.visible:
		#print("UI is now visible!")

#func _on_area_2d_body_exited(body):
	#if body.name == "Player":
		#print("Player left. Hiding UI.")
		#ui.hide()
