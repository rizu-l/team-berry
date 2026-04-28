extends EnemyBase

enum HuntressState { CHASING, GROUND_ATTACK, DASH_ATTACK, JUMP_START, AIRBORNE, AIR_ATTACK, LANDING, HURT, DYING }
enum HuntressAction { NONE, ATTACK1, ATTACK3, DASH_ATTACK, SPECIAL_DASH, UP_IDLE, UP_JUMP, DOWN_JUMP }

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var contact_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D2
@onready var attack1_hitbox: Area2D = $Attack1Hitbox
@onready var attack3_hitbox: Area2D = $Attack3Hitbox
@onready var down_attack_hitbox: Area2D = $DownAttackHitbox
@onready var up_attack_hitbox: Area2D = $UpAttackHitbox
@onready var dash_attack_hitbox: Area2D = $DashAttackHitbox
@onready var special_dash_hitbox: Area2D = $SpecialDashHitbox

@export var chase_speed: float = 285.0
@export var attack_range: float = 150.0
@export var dash_attack_range: float = 430.0
@export var air_attack_range: float = 150.0

const ACTION_COUNT := 8
const GROUND_ACTION_COOLDOWN := 0.18
const JUMP_START_TIME := 0.18
const LANDING_TIME := 0.26
const HURT_TIME := 0.12
const JUMP_VELOCITY := -520.0
const JUMP_FORWARD_SPEED := 190.0
const AIR_DRIFT_SPEED := 135.0
const DOWN_SLAM_SPEED := 720.0
const DASH_ATTACK_SPEED := 390.0
const SPECIAL_DASH_SPEED := 470.0
const ATTACK1_STEP_SPEED := 85.0
const ATTACK3_STEP_SPEED := 65.0
const ENRAGE_HEALTH_RATIO := 0.5

var state = HuntressState.CHASING
var current_action = HuntressAction.NONE
var state_time_remaining: float = 0.0
var action_cooldown_remaining: float = 0.0
var facing_direction: float = 1.0
var hit_players_this_action: Dictionary = {}
var attack_hitboxes: Array = []
var attack_shapes: Array = []
var attack_hitbox_base_positions: Array[Vector2] = []
var attack_shape_base_positions: Array[Vector2] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	rng.randomize()
	damaged.connect(_on_damaged)
	died.connect(_on_died)
	setup_attack_hitboxes()
	set_non_looping_animations()
	disable_all_attack_hitboxes()
	play_animation(&"idle")

func setup_attack_hitboxes() -> void:
	for _i in range(ACTION_COUNT):
		attack_hitboxes.append(null)
		attack_shapes.append(null)
		attack_hitbox_base_positions.append(Vector2.ZERO)
		attack_shape_base_positions.append(Vector2.ZERO)

	set_action_hitbox(HuntressAction.ATTACK1, attack1_hitbox)
	set_action_hitbox(HuntressAction.ATTACK3, attack3_hitbox)
	set_action_hitbox(HuntressAction.DASH_ATTACK, dash_attack_hitbox)
	set_action_hitbox(HuntressAction.SPECIAL_DASH, special_dash_hitbox)
	set_action_hitbox(HuntressAction.UP_IDLE, up_attack_hitbox)
	set_action_hitbox(HuntressAction.UP_JUMP, up_attack_hitbox)
	set_action_hitbox(HuntressAction.DOWN_JUMP, down_attack_hitbox)

	var connected_areas := {}
	for action_index in range(1, ACTION_COUNT):
		var area := attack_hitboxes[action_index] as Area2D
		if area == null:
			continue

		area.collision_layer = 0
		area.collision_mask = 2
		area.monitoring = true
		area.monitorable = false
		if not connected_areas.has(area.get_instance_id()):
			connected_areas[area.get_instance_id()] = true
			area.body_entered.connect(_on_attack_hitbox_body_entered)

func set_action_hitbox(action: int, area: Area2D) -> void:
	attack_hitboxes[action] = area
	attack_hitbox_base_positions[action] = area.position
	var shape := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	attack_shapes[action] = shape
	if shape != null:
		attack_shape_base_positions[action] = shape.position

func set_non_looping_animations() -> void:
	for animation_name in [
		&"attack1",
		&"attack3",
		&"attack_down_jump",
		&"attack_up_idle",
		&"attack_up_jump",
		&"dash",
		&"dash_attack",
		&"special_dash",
		&"death",
		&"fall",
		&"hit",
		&"jump"
	]:
		if animated_sprite_2d.sprite_frames.has_animation(animation_name):
			animated_sprite_2d.sprite_frames.set_animation_loop(animation_name, false)

func process_ai(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	if action_cooldown_remaining > 0.0:
		action_cooldown_remaining = maxf(action_cooldown_remaining - delta, 0.0)

	match state:
		HuntressState.CHASING:
			process_chasing()
		HuntressState.GROUND_ATTACK:
			process_ground_attack(delta)
		HuntressState.DASH_ATTACK:
			process_dash_attack(delta)
		HuntressState.JUMP_START:
			process_jump_start(delta)
		HuntressState.AIRBORNE:
			process_airborne()
		HuntressState.AIR_ATTACK:
			process_air_attack(delta)
		HuntressState.LANDING:
			process_landing(delta)
		HuntressState.HURT:
			process_hurt(delta)
		HuntressState.DYING:
			velocity = Vector2.ZERO

func can_apply_contact_damage() -> bool:
	return state == HuntressState.CHASING or state == HuntressState.AIRBORNE

func process_chasing() -> void:
	disable_all_attack_hitboxes()
	if not is_on_floor():
		state = HuntressState.AIRBORNE
		play_animation(&"mid_air")
		return

	var target := find_nearest_target(target_detection_range)
	if target == null:
		velocity.x = 0.0
		play_animation(&"idle")
		return

	face_target_huntress(target)
	var distance_x := target.global_position.x - global_position.x
	var abs_distance_x := absf(distance_x)
	var vertical_offset := target.global_position.y - global_position.y

	if action_cooldown_remaining <= 0.0:
		if should_ground_up_attack(abs_distance_x, vertical_offset):
			start_ground_action(HuntressAction.UP_IDLE, target)
			return
		if should_jump_pursue(abs_distance_x, vertical_offset):
			start_jump(target)
			return
		if abs_distance_x <= attack_range:
			start_ground_action(pick_close_attack(vertical_offset), target)
			return
		if abs_distance_x <= dash_attack_range:
			start_ground_action(pick_dash_attack(), target)
			return

	var direction := signf(distance_x)
	velocity.x = get_ledge_safe_direction(direction) * get_chase_speed()
	play_animation(&"run" if velocity.x != 0.0 else &"idle")

func should_ground_up_attack(abs_distance_x: float, vertical_offset: float) -> bool:
	return abs_distance_x <= air_attack_range and vertical_offset < -58.0

func should_jump_pursue(abs_distance_x: float, vertical_offset: float) -> bool:
	if abs_distance_x > dash_attack_range:
		return false
	if vertical_offset < -95.0:
		return true

	return rng.randf() < 0.22 and abs_distance_x > attack_range and abs_distance_x < dash_attack_range

func pick_close_attack(vertical_offset: float) -> int:
	if vertical_offset < -42.0:
		return HuntressAction.UP_IDLE
	if rng.randf() < 0.45:
		return HuntressAction.ATTACK3

	return HuntressAction.ATTACK1

func pick_dash_attack() -> int:
	if hp <= int(max_hp * ENRAGE_HEALTH_RATIO) and rng.randf() < 0.56:
		return HuntressAction.SPECIAL_DASH
	if rng.randf() < 0.36:
		return HuntressAction.SPECIAL_DASH

	return HuntressAction.DASH_ATTACK

func start_ground_action(action: int, target: Node2D) -> void:
	current_action = action
	state = HuntressState.DASH_ATTACK if is_dash_action(action) else HuntressState.GROUND_ATTACK
	state_time_remaining = get_animation_duration(get_action_animation(action), 0.42)
	face_target_huntress(target)
	hit_players_this_action.clear()
	disable_all_attack_hitboxes()
	restart_animation(get_action_animation(action))

func process_ground_attack(delta: float) -> void:
	state_time_remaining -= delta
	velocity.x = get_ground_attack_velocity()
	if update_current_attack_hitbox():
		apply_damage_to_attack_overlaps()

	if state_time_remaining <= 0.0:
		finish_action()

func process_dash_attack(delta: float) -> void:
	state_time_remaining -= delta
	velocity.x = get_dash_action_speed(current_action) * facing_direction * get_enrage_multiplier()
	if update_current_attack_hitbox():
		apply_damage_to_attack_overlaps()

	if is_on_wall():
		finish_action()
		return
	if state_time_remaining <= 0.0:
		finish_action()

func start_jump(target: Node2D) -> void:
	current_action = HuntressAction.NONE
	state = HuntressState.JUMP_START
	state_time_remaining = maxf(JUMP_START_TIME, get_animation_duration(&"jump", JUMP_START_TIME) * 0.55)
	face_target_huntress(target)
	velocity = Vector2(facing_direction * JUMP_FORWARD_SPEED * get_enrage_multiplier(), JUMP_VELOCITY)
	disable_all_attack_hitboxes()
	restart_animation(&"jump")

func process_jump_start(delta: float) -> void:
	state_time_remaining -= delta
	velocity.x = facing_direction * JUMP_FORWARD_SPEED * get_enrage_multiplier()
	if state_time_remaining <= 0.0:
		state = HuntressState.AIRBORNE
		play_animation(&"mid_air")

func process_airborne() -> void:
	disable_all_attack_hitboxes()
	if is_on_floor():
		start_landing()
		return

	var target := find_nearest_target(target_detection_range)
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, AIR_DRIFT_SPEED)
	else:
		face_target_huntress(target)
		var distance_x := target.global_position.x - global_position.x
		var abs_distance_x := absf(distance_x)
		var vertical_offset := target.global_position.y - global_position.y
		velocity.x = signf(distance_x) * AIR_DRIFT_SPEED * get_enrage_multiplier()
		if action_cooldown_remaining <= 0.0 and abs_distance_x <= air_attack_range:
			if vertical_offset < -24.0:
				start_air_action(HuntressAction.UP_JUMP, target)
				return
			if vertical_offset > 12.0 or velocity.y > 0.0:
				start_air_action(HuntressAction.DOWN_JUMP, target)
				return

	play_animation(&"fall" if velocity.y > 0.0 else &"mid_air")

func start_air_action(action: int, target: Node2D) -> void:
	current_action = action
	state = HuntressState.AIR_ATTACK
	state_time_remaining = get_animation_duration(get_action_animation(action), 0.44)
	face_target_huntress(target)
	hit_players_this_action.clear()
	disable_all_attack_hitboxes()
	if action == HuntressAction.UP_JUMP:
		velocity.y = minf(velocity.y, -140.0)
	else:
		velocity.y = DOWN_SLAM_SPEED
	restart_animation(get_action_animation(action))

func process_air_attack(delta: float) -> void:
	state_time_remaining -= delta
	if current_action == HuntressAction.DOWN_JUMP:
		velocity.y = DOWN_SLAM_SPEED
		velocity.x = facing_direction * AIR_DRIFT_SPEED * 0.72
	else:
		velocity.x = facing_direction * AIR_DRIFT_SPEED * 0.45

	if update_current_attack_hitbox():
		apply_damage_to_attack_overlaps()

	if current_action == HuntressAction.DOWN_JUMP and is_on_floor():
		start_landing()
		return
	if state_time_remaining <= 0.0:
		current_action = HuntressAction.NONE
		disable_all_attack_hitboxes()
		state = HuntressState.AIRBORNE
		play_animation(&"fall" if velocity.y > 0.0 else &"mid_air")

func start_landing() -> void:
	state = HuntressState.LANDING
	current_action = HuntressAction.NONE
	state_time_remaining = LANDING_TIME
	action_cooldown_remaining = get_action_cooldown(0.12)
	velocity = Vector2.ZERO
	disable_all_attack_hitboxes()
	restart_animation(&"fall")

func process_landing(delta: float) -> void:
	velocity.x = 0.0
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = HuntressState.CHASING
		play_animation(&"idle")

func process_hurt(delta: float) -> void:
	velocity.x = 0.0
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = HuntressState.CHASING
		play_animation(&"idle")

func finish_action() -> void:
	current_action = HuntressAction.NONE
	disable_all_attack_hitboxes()
	velocity.x = 0.0
	action_cooldown_remaining = get_action_cooldown(GROUND_ACTION_COOLDOWN)
	state = HuntressState.CHASING
	play_animation(&"idle")

func get_ground_attack_velocity() -> float:
	match current_action:
		HuntressAction.ATTACK1:
			return ATTACK1_STEP_SPEED * facing_direction
		HuntressAction.ATTACK3:
			return ATTACK3_STEP_SPEED * facing_direction
		_:
			return 0.0

func get_dash_action_speed(action: int) -> float:
	if action == HuntressAction.SPECIAL_DASH:
		return SPECIAL_DASH_SPEED

	return DASH_ATTACK_SPEED

func get_chase_speed() -> float:
	return chase_speed * get_enrage_multiplier()

func get_enrage_multiplier() -> float:
	return 1.18 if hp <= int(max_hp * ENRAGE_HEALTH_RATIO) else 1.0

func get_action_cooldown(base_cooldown: float) -> float:
	var cooldown := base_cooldown
	if hp <= int(max_hp * ENRAGE_HEALTH_RATIO):
		cooldown *= 0.55
	return cooldown * rng.randf_range(0.75, 1.1)

func is_dash_action(action: int) -> bool:
	return action == HuntressAction.DASH_ATTACK or action == HuntressAction.SPECIAL_DASH

func get_action_animation(action: int) -> StringName:
	match action:
		HuntressAction.ATTACK1:
			return &"attack1"
		HuntressAction.ATTACK3:
			return &"attack3"
		HuntressAction.DASH_ATTACK:
			return &"dash_attack"
		HuntressAction.SPECIAL_DASH:
			return &"special_dash"
		HuntressAction.UP_IDLE:
			return &"attack_up_idle"
		HuntressAction.UP_JUMP:
			return &"attack_up_jump"
		HuntressAction.DOWN_JUMP:
			return &"attack_down_jump"
		_:
			return &"idle"

func get_action_damage(action: int) -> int:
	match action:
		HuntressAction.ATTACK1:
			return attack_power
		HuntressAction.ATTACK3:
			return attack_power + 5
		HuntressAction.DASH_ATTACK:
			return attack_power + 7
		HuntressAction.SPECIAL_DASH:
			return attack_power + 12
		HuntressAction.UP_IDLE, HuntressAction.UP_JUMP:
			return attack_power + 6
		HuntressAction.DOWN_JUMP:
			return attack_power + 10
		_:
			return attack_power

func get_action_stun(action: int) -> float:
	match action:
		HuntressAction.SPECIAL_DASH:
			return 0.34
		HuntressAction.DASH_ATTACK, HuntressAction.DOWN_JUMP:
			return 0.28
		HuntressAction.ATTACK3, HuntressAction.UP_IDLE, HuntressAction.UP_JUMP:
			return 0.22
		_:
			return 0.14

func get_action_knockback(action: int, knockback_direction_x: float) -> Vector2:
	match action:
		HuntressAction.SPECIAL_DASH:
			return Vector2(640.0 * knockback_direction_x, -250.0)
		HuntressAction.DASH_ATTACK:
			return Vector2(560.0 * knockback_direction_x, -235.0)
		HuntressAction.DOWN_JUMP:
			return Vector2(360.0 * knockback_direction_x, -410.0)
		HuntressAction.UP_IDLE, HuntressAction.UP_JUMP:
			return Vector2(320.0 * knockback_direction_x, -470.0)
		HuntressAction.ATTACK3:
			return Vector2(460.0 * knockback_direction_x, -240.0)
		_:
			return Vector2(390.0 * knockback_direction_x, -220.0)

func update_current_attack_hitbox() -> bool:
	if current_action == HuntressAction.NONE:
		disable_all_attack_hitboxes()
		return false

	var is_active := is_current_action_frame_active()
	set_action_hitbox_active(current_action, is_active)
	return is_active

func is_current_action_frame_active() -> bool:
	if current_action == HuntressAction.NONE:
		return false

	var frame := animated_sprite_2d.frame
	var frame_range := get_active_frame_range(current_action)
	return frame >= frame_range.x and frame <= frame_range.y

func get_active_frame_range(action: int) -> Vector2i:
	match action:
		HuntressAction.ATTACK1:
			return Vector2i(1, 2)
		HuntressAction.ATTACK3:
			return Vector2i(2, 4)
		HuntressAction.DASH_ATTACK:
			return Vector2i(1, 2)
		HuntressAction.SPECIAL_DASH:
			return Vector2i(2, 4)
		HuntressAction.UP_IDLE, HuntressAction.UP_JUMP:
			return Vector2i(1, 3)
		HuntressAction.DOWN_JUMP:
			return Vector2i(1, 3)
		_:
			return Vector2i(99, 99)

func set_action_hitbox_active(action: int, active: bool) -> void:
	var shape := attack_shapes[action] as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", not active)

func disable_all_attack_hitboxes() -> void:
	var disabled_shapes := {}
	for action_index in range(1, ACTION_COUNT):
		var shape := attack_shapes[action_index] as CollisionShape2D
		if shape == null:
			continue
		if disabled_shapes.has(shape.get_instance_id()):
			continue
		disabled_shapes[shape.get_instance_id()] = true
		shape.set_deferred("disabled", true)

func _on_attack_hitbox_body_entered(body: Node) -> void:
	apply_attack_damage(body)

func apply_damage_to_attack_overlaps() -> void:
	if current_action == HuntressAction.NONE:
		return

	var area := attack_hitboxes[current_action] as Area2D
	if area == null:
		return

	for body_variant in area.get_overlapping_bodies():
		var body := body_variant as Node
		if body != null:
			apply_attack_damage(body)

func apply_attack_damage(target: Node) -> void:
	if current_action == HuntressAction.NONE:
		return
	if not is_current_action_frame_active():
		return
	if not target.is_in_group("player"):
		return

	var target_instance_id := target.get_instance_id()
	if hit_players_this_action.has(target_instance_id):
		return

	hit_players_this_action[target_instance_id] = true
	if target.has_method("take_damage"):
		target.call("take_damage", get_action_damage(current_action))
	if target.has_method("apply_knockback") and target is Node2D:
		var target_node := target as Node2D
		var knockback_direction_x := signf(target_node.global_position.x - global_position.x)
		if knockback_direction_x == 0.0:
			knockback_direction_x = facing_direction
		target.call("apply_knockback", get_action_knockback(current_action, knockback_direction_x))
	if target.has_method("apply_stun"):
		target.call("apply_stun", get_action_stun(current_action))

func face_target_huntress(target: Node2D) -> void:
	if target == null:
		return
	face_direction(signf(target.global_position.x - global_position.x))

func face_direction(direction: float) -> void:
	if direction == 0.0:
		return

	facing_direction = signf(direction)
	animated_sprite_2d.flip_h = facing_direction < 0.0
	for action_index in range(1, ACTION_COUNT):
		var area := attack_hitboxes[action_index] as Area2D
		var shape := attack_shapes[action_index] as CollisionShape2D
		if area != null:
			var base_area_position: Vector2 = attack_hitbox_base_positions[action_index]
			area.position = Vector2(base_area_position.x * facing_direction, base_area_position.y)
		if shape != null:
			var base_shape_position: Vector2 = attack_shape_base_positions[action_index]
			shape.position = Vector2(base_shape_position.x * facing_direction, base_shape_position.y)

func get_animation_duration(animation_name: StringName, fallback: float = 0.4) -> float:
	var frames := animated_sprite_2d.sprite_frames
	if not frames.has_animation(animation_name):
		return fallback

	var frame_count := frames.get_frame_count(animation_name)
	var animation_speed := maxf(frames.get_animation_speed(animation_name), 0.01)
	var total_duration := 0.0
	for frame_index in range(frame_count):
		total_duration += frames.get_frame_duration(animation_name, frame_index) / animation_speed

	return maxf(total_duration, fallback)

func restart_animation(animation_name: StringName) -> void:
	if animated_sprite_2d.sprite_frames.has_animation(animation_name):
		animated_sprite_2d.stop()
		animated_sprite_2d.play(animation_name)

func play_animation(animation_name: StringName) -> void:
	if animated_sprite_2d.animation == animation_name:
		return
	if animated_sprite_2d.sprite_frames.has_animation(animation_name):
		animated_sprite_2d.play(animation_name)

func _on_damaged(_amount: int) -> void:
	if is_dead:
		return
	if state == HuntressState.GROUND_ATTACK or state == HuntressState.DASH_ATTACK or state == HuntressState.AIR_ATTACK:
		return

	state = HuntressState.HURT
	current_action = HuntressAction.NONE
	state_time_remaining = HURT_TIME
	velocity.x = 0.0
	disable_all_attack_hitboxes()
	restart_animation(&"hit")

func die() -> void:
	if is_dead:
		return

	is_dead = true
	state = HuntressState.DYING
	current_action = HuntressAction.NONE
	velocity = Vector2.ZERO
	died.emit()
	disable_all_attack_hitboxes()
	restart_animation(&"death")
	await animated_sprite_2d.animation_finished
	finish_death()

func _on_died() -> void:
	set_physics_process(false)
	body_shape.set_deferred("disabled", true)
	contact_shape.set_deferred("disabled", true)
	disable_all_attack_hitboxes()
