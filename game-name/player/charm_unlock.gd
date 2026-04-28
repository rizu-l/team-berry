extends AnimatedSprite2D
# Pickup node that unlocks a charm when player touches it
# Mirrors the ability_unlock.gd pattern exactly

@export var Charm_to_Unlock: CharmData.charm_list
const charm_unlock_screen_preload = preload("res://player/charm_unlock_screen.tscn")

func _ready():
	var player: CharacterBody2D = null
	while player == null:
		player = get_tree().get_first_node_in_group("player")
		await get_tree().physics_frame
	
	# If charm already unlocked, delete this pickup
	if GameManager.is_charm_unlocked(Charm_to_Unlock):
		queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Unlock the charm
		GameManager.unlock_charm(Charm_to_Unlock)
		
		# Spawn the unlock screen
		var new_unlock_screen = charm_unlock_screen_preload.instantiate()
		new_unlock_screen.charm_to_show = Charm_to_Unlock
		get_parent().add_child(new_unlock_screen)
		
		# Delete the pickup
		queue_free()
