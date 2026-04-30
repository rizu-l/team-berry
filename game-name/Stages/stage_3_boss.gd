extends Node2D

@export_file("*.tscn") var target_scene_path: String
@export var spawn_location: Vector2 # Where the player appears in the new scene

@onready var frogPortal = $PortalFrog

func _ready():
	# This runs the moment the scene loads
	frogPortal.hide()

func _on_frog_died():
	#frogPortal.show()
	get_tree().change_scene_to_file("res://Stages/spire.tscn")
	


func _on_portal_return_entered(body: Node2D) -> void:
	pass # Replace with function body.
