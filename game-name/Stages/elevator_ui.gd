extends CanvasLayer

signal floor_selected(index: int)

# This single function handles every button because you are passing the int!
func _on_button_pressed(index: int):
	# Just shout the command into the Signal Bus
	SignalBus.move_elevator.emit(index) 
