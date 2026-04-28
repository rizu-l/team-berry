extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var spawn_location: Vector2

func _on_door_cliff_body_entered(body):
	print("Switch Scene", body.name)
	if body.name == "Player":
		get_tree().change_scene_to_file("res://Stages/stage_1.tscn")
