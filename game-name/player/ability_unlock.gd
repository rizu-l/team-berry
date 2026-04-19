extends AnimatedSprite2D

@export var Ability_to_Unlock: AbilityData.ability_list

const ability_unlock_screen_preload = preload("res://player/ability_unlock_screen.tscn")

func _ready():
	var player: CharacterBody2D = null
	while player == null:
		player = get_tree().get_first_node_in_group("player")
		await get_tree().physics_frame
	if GameManager.has_ability(Ability_to_Unlock):
		queue_free()
		
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.unlock_ability(Ability_to_Unlock)
		
		var new_unlock_screen = ability_unlock_screen_preload.instantiate()
		new_unlock_screen.ability_to_show = Ability_to_Unlock
		get_parent().add_child(new_unlock_screen)
		
		queue_free()
 
