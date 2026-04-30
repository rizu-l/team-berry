extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var spawn_location: Vector2 # Where the player appears in the new scene

func _on_door_deep_return_body_entered(body):
	print("Switch Scene", body.name) # This will tell us if ANYTHING hits it
	if body.name == "Player":
		# Change to the target scene
		get_tree().change_scene_to_file("res://Stages/spire.tscn")
