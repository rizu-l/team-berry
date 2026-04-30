extends Area2D

@export_file("*.tscn") var target_scene_path: String
@export var spawn_location: Vector2 # Where the player appears in the new scene

const DEFAULT_TARGET_SCENE_PATH := "res://Stages/stage_3_boss.tscn"
const PLAYER_COLLISION_MASK := 6

var transition_requested: bool = false

func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_mask = PLAYER_COLLISION_MASK

func _on_portal_boss_3_body_entered(body: Node) -> void:
	if transition_requested:
		return

	if body == null or not body.is_in_group("player"):
		return

	var next_scene := target_scene_path if target_scene_path != "" else DEFAULT_TARGET_SCENE_PATH
	if not ResourceLoader.exists(next_scene):
		push_error("Boss portal target scene is missing: %s" % next_scene)
		return

	transition_requested = true
	monitoring = false

	if spawn_location != Vector2.ZERO:
		GameManager.pending_player_position = spawn_location
		GameManager.has_pending_player_position = true
	else:
		GameManager.has_pending_player_position = false

	call_deferred("_change_to_target_scene", next_scene)

func _change_to_target_scene(next_scene: String) -> void:
	get_tree().change_scene_to_file(next_scene)
