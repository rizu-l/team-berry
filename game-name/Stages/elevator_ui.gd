extends CanvasLayer

signal floor_selected(index: int)

func _on_button_pressed(index: int):
	SignalBus.move_elevator.emit(index) 
