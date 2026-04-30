extends Node2D

@onready var left_side = $LeftSide
@onready var right_side = $RightSide
@onready var mountian_layer = $MountianLayer

func _ready():
	# This runs the moment the scene loads
	mountian_layer.hide()

var has_split = false

func _on_area_mountian_entered(body: Node2D) -> void:
	if body.name == "Player" and not has_split:
		has_split = true
		
		# 1. THE DELAY
		# Pause for 0.6 seconds to let the player realize they've stepped on something
		await get_tree().create_timer(0.01).timeout 
		
		start_mountain_split()

func start_mountain_split():
	mountian_layer.show()
	# 1. Find the player
	var player = get_tree().get_first_node_in_group("Player")
	
	if player:
		# 2. Break the 'glue' 
		# We set floor_snap_length to 0 so they don't 'snap' to the moving pieces
		player.floor_snap_length = 0
		# We tell the player to ignore platform velocity
		player.platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
		
		# 3. Optional: Give them a tiny nudge down to force the fall
		player.velocity.y = 10 
	# Find the current active camera
	var camera = get_viewport().get_camera_2d()
	
	# 2. START CAMERA SHAKE
	if camera:
		apply_camera_shake(camera, 2.0, 12.0) # 2 seconds, 12px intensity

	# 3. MOUNTAIN SPLIT ANIMATION
	var tween = create_tween().set_parallel(true)
	
	# Ease In makes the movement start slow and "heavy"
	tween.tween_property(left_side, "position:x", left_side.position.x - 450, 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_property(right_side, "position:x", right_side.position.x + 450, 2.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	
	# Wait for split to finish before falling into the next scene
	await tween.finished
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://Stages/stage_1_boss.tscn")

func apply_camera_shake(camera: Camera2D, duration: float, intensity: float):
	var shake_tween = create_tween()
	
	# We shake the OFFSET so the camera stays centered on the player 
	# but vibrates internally.
	for i in range(15): 
		var random_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(camera, "offset", random_offset, duration / 15.0)
	
	# Reset camera offset to zero when finished
	shake_tween.tween_property(camera, "offset", Vector2.ZERO, 0.1)
