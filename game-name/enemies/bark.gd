extends EnemyBase

enum BarkState { FLYING, ALIGNING, ASCENDING, AIR_IDLE, SMASH_START, SMASH_FALL, SMASH_END, HURT, DYING }

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var contact_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D
@onready var smash_hitbox: Area2D = $SmashHitbox
@onready var smash_shape: CollisionShape2D = $SmashHitbox/CollisionShape2D
@onready var death_hitbox: Area2D = $DeathHitbox
@onready var death_shape: CollisionShape2D = $DeathHitbox/CollisionShape2D

@export var fly_speed: float = 185.0
@export var fly_vertical_speed: float = 120.0
@export var orbit_radius: float = 130.0
@export var spawn_leash_radius: float = 320.0
@export var fly_ceiling_offset: float = 170.0
@export var fly_floor_offset: float = 60.0
@export var smash_trigger_range: float = 260.0
@export var smash_align_height: float = 135.0
@export var smash_align_tolerance: float = 12.0
@export var smash_align_timeout: float = 1.0
@export var smash_height: float = 230.0
@export var ascend_speed: float = 460.0
@export var smash_fall_speed: float = 760.0
@export var air_idle_time: float = 0.35
@export var smash_start_time: float = 0.22
@export var smash_end_time: float = 0.85
@export var smash_cooldown: float = 2.0
@export var smash_max_fall_below_target: float = 360.0
@export var smash_ground_probe_down: float = 900.0
@export var smash_align_speed: float = 150.0
@export var randomness_amount: float = 0.18
@export var hit_reaction_time: float = 0.22
@export var death_explosion_damage: int = 20
@export var death_explosion_active_time: float = 0.18

var state = BarkState.FLYING
var spawn_position := Vector2.ZERO
var target_position_before_smash := Vector2.ZERO
var smash_align_position := Vector2.ZERO
var smash_cooldown_remaining: float = 0.0
var state_time_remaining: float = 0.0
var hit_players_this_attack: Dictionary = {}
var hit_players_this_death: Dictionary = {}
var fly_phase: float = 0.0
var orbit_side_preference: float = 1.0
var orbit_radius_offset: float = 0.0
var hover_height_offset: float = 0.0
var fly_speed_multiplier: float = 1.0
var vertical_speed_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var align_height_offset: float = 0.0
var current_align_lateral_offset: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	rng.randomize()
	spawn_position = global_position
	randomize_instance_behavior()
	damaged.connect(_on_damaged)
	died.connect(_on_died)
	for animation_name in [&"smash_start", &"smash_end", &"die", &"hit"]:
		if animated_sprite_2d.sprite_frames.has_animation(animation_name):
			animated_sprite_2d.sprite_frames.set_animation_loop(animation_name, false)

	smash_hitbox.collision_layer = 0
	smash_hitbox.collision_mask = 2
	smash_hitbox.monitoring = true
	smash_hitbox.monitorable = false
	smash_hitbox.body_entered.connect(_on_smash_hitbox_body_entered)

	death_hitbox.collision_layer = 0
	death_hitbox.collision_mask = 2
	death_hitbox.monitoring = true
	death_hitbox.monitorable = false
	death_hitbox.body_entered.connect(_on_death_hitbox_body_entered)

	disable_smash_hitbox()
	disable_death_hitbox()
	animated_sprite_2d.play(&"fly")

func process_ai(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	if smash_cooldown_remaining > 0.0:
		smash_cooldown_remaining = maxf(smash_cooldown_remaining - delta, 0.0)

	match state:
		BarkState.FLYING:
			process_flying(delta)
		BarkState.ALIGNING:
			process_aligning(delta)
		BarkState.ASCENDING:
			process_ascending(delta)
		BarkState.AIR_IDLE:
			process_air_idle(delta)
		BarkState.SMASH_START:
			process_smash_start(delta)
		BarkState.SMASH_FALL:
			process_smash_fall()
		BarkState.SMASH_END:
			process_smash_end(delta)
		BarkState.HURT:
			process_hurt(delta)
		BarkState.DYING:
			velocity = Vector2.ZERO

func can_apply_contact_damage() -> bool:
	return state != BarkState.SMASH_START and state != BarkState.SMASH_FALL and state != BarkState.SMASH_END

func process_flying(delta: float) -> void:
	disable_smash_hitbox()
	fly_phase += delta * fly_speed_multiplier
	var target := find_nearest_target(target_detection_range)
	if target == null:
		var home_position := spawn_position + Vector2(cos(fly_phase) * (80.0 + orbit_radius_offset), sin(fly_phase * 1.7) * (35.0 + hover_height_offset * 0.35))
		move_toward_flight_position(home_position, 0.55)
		play_animation(&"fly")
		return

	var offset := target.global_position - global_position
	var distance := offset.length()
	if can_start_smash(distance):
		if start_align(target):
			return

		smash_cooldown_remaining = 0.35

	var orbit_side := orbit_side_preference
	if absf(global_position.x - target.global_position.x) > 24.0:
		orbit_side = signf(global_position.x - target.global_position.x)

	var desired_position := target.global_position + Vector2(orbit_side * (orbit_radius + orbit_radius_offset), -120.0 + hover_height_offset + sin(fly_phase * 2.0) * 35.0)
	desired_position = constrain_flight_position(desired_position)
	move_toward_flight_position(desired_position)
	update_facing(velocity.x)
	play_animation(&"fly")

func can_start_smash(distance_to_target: float) -> bool:
	if smash_cooldown_remaining > 0.0:
		return false
	if distance_to_target > smash_trigger_range:
		return false
	if is_outside_spawn_leash():
		return false

	return has_floor_below_self()

func start_align(target: Node2D) -> bool:
	if not has_floor_below_self():
		return false

	state = BarkState.ALIGNING
	target_position_before_smash = target.global_position
	current_align_lateral_offset = orbit_side_preference * rng.randf_range(-14.0, 14.0)
	smash_align_position = get_smash_align_position(target.global_position)
	state_time_remaining = smash_align_timeout * rng.randf_range(0.85, 1.2)
	hit_players_this_attack.clear()
	disable_smash_hitbox()
	play_animation(&"fly")
	return true

func process_aligning(delta: float) -> void:
	state_time_remaining -= delta
	var target := find_nearest_target(target_detection_range)
	if target != null:
		target_position_before_smash = target.global_position
		smash_align_position = get_smash_align_position(target.global_position)

	move_toward_flight_position(smash_align_position, 1.35)
	update_facing(velocity.x)

	if global_position.distance_to(smash_align_position) <= smash_align_tolerance or state_time_remaining <= 0.0:
		if has_floor_below_self():
			start_ascend()
		else:
			abort_smash()

func start_ascend() -> void:
	state = BarkState.ASCENDING
	disable_smash_hitbox()
	play_animation(&"fly")

func process_ascending(_delta: float) -> void:
	var target_y := maxf(target_position_before_smash.y - smash_height, spawn_position.y - fly_ceiling_offset)
	var align_direction := signf(target_position_before_smash.x - global_position.x)
	var horizontal_velocity := 0.0
	if absf(target_position_before_smash.x - global_position.x) > 6.0 and not is_outside_spawn_leash():
		horizontal_velocity = align_direction * smash_align_speed

	velocity = Vector2(horizontal_velocity, -ascend_speed)
	if global_position.y <= target_y:
		velocity = Vector2.ZERO
		start_air_idle()

func start_air_idle() -> void:
	state = BarkState.AIR_IDLE
	state_time_remaining = air_idle_time
	play_animation(&"fly")

func process_air_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		start_smash_start()

func start_smash_start() -> void:
	state = BarkState.SMASH_START
	state_time_remaining = smash_start_time
	play_animation(&"smash_start")

func process_smash_start(delta: float) -> void:
	velocity = Vector2.ZERO
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		if not has_floor_below_self():
			abort_smash()
			return

		state = BarkState.SMASH_FALL
		enable_smash_hitbox()
		play_animation(&"smash_loop")

func process_smash_fall() -> void:
	velocity = Vector2(0.0, smash_fall_speed)
	enable_smash_hitbox()
	apply_damage_to_smash_overlaps()

	if is_on_floor():
		start_smash_end()
		return

	if global_position.y >= target_position_before_smash.y + smash_max_fall_below_target:
		abort_smash()
		return

func start_smash_end() -> void:
	state = BarkState.SMASH_END
	state_time_remaining = smash_end_time
	velocity = Vector2.ZERO
	disable_smash_hitbox()
	smash_cooldown_remaining = get_randomized_cooldown(smash_cooldown)
	play_animation(&"smash_end")

func abort_smash() -> void:
	state = BarkState.FLYING
	velocity = Vector2.ZERO
	disable_smash_hitbox()
	smash_cooldown_remaining = get_randomized_cooldown(0.6)
	play_animation(&"fly")

func process_smash_end(delta: float) -> void:
	velocity = Vector2.ZERO
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = BarkState.FLYING
		play_animation(&"fly")

func process_hurt(delta: float) -> void:
	velocity = Vector2.ZERO
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = BarkState.FLYING
		play_animation(&"fly")

func constrain_flight_position(position: Vector2) -> Vector2:
	var constrained_position := position
	constrained_position.y = clampf(constrained_position.y, spawn_position.y - fly_ceiling_offset, spawn_position.y + fly_floor_offset)

	var offset_from_spawn := constrained_position - spawn_position
	if offset_from_spawn.length() > spawn_leash_radius:
		constrained_position = spawn_position + offset_from_spawn.normalized() * spawn_leash_radius

	return constrained_position

func move_toward_flight_position(position: Vector2, speed_scale: float = 1.0) -> void:
	if is_outside_spawn_leash():
		position = spawn_position

	var constrained_position := constrain_flight_position(position)
	var direction := global_position.direction_to(constrained_position)
	var distance := global_position.distance_to(constrained_position)
	if distance <= 4.0:
		velocity = Vector2.ZERO
		return

	velocity = Vector2(
		direction.x * fly_speed * fly_speed_multiplier * speed_scale,
		direction.y * fly_vertical_speed * vertical_speed_multiplier * speed_scale
	)

func randomize_instance_behavior() -> void:
	fly_phase = rng.randf_range(0.0, TAU)
	orbit_side_preference = -1.0 if rng.randi_range(0, 1) == 0 else 1.0
	orbit_radius_offset = rng.randf_range(-30.0, 30.0)
	hover_height_offset = rng.randf_range(-28.0, 24.0)
	fly_speed_multiplier = rng.randf_range(1.0 - randomness_amount, 1.0 + randomness_amount)
	vertical_speed_multiplier = rng.randf_range(1.0 - randomness_amount, 1.0 + randomness_amount)
	cooldown_multiplier = rng.randf_range(0.85, 1.25)
	align_height_offset = rng.randf_range(-24.0, 18.0)
	smash_cooldown_remaining = rng.randf_range(0.0, smash_cooldown * 0.6)

func get_smash_align_position(target_position: Vector2) -> Vector2:
	return constrain_flight_position(target_position + Vector2(current_align_lateral_offset, -smash_align_height + align_height_offset))

func get_randomized_cooldown(base_cooldown: float) -> float:
	return base_cooldown * cooldown_multiplier * rng.randf_range(0.85, 1.15)

func is_outside_spawn_leash() -> bool:
	return global_position.distance_to(spawn_position) > spawn_leash_radius

func has_floor_below_self() -> bool:
	var space_state := get_world_2d().direct_space_state
	var probe_start := global_position
	var probe_end := global_position + Vector2(0.0, smash_ground_probe_down)
	var query := PhysicsRayQueryParameters2D.create(probe_start, probe_end, body_collision_mask)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	return not result.is_empty()

func _on_damaged(_amount: int) -> void:
	if is_dead:
		return
	if state == BarkState.SMASH_START or state == BarkState.SMASH_FALL or state == BarkState.SMASH_END:
		return

	state = BarkState.HURT
	state_time_remaining = hit_reaction_time
	velocity = Vector2.ZERO
	disable_smash_hitbox()
	play_animation(&"hit")

func die() -> void:
	if is_dead:
		return

	is_dead = true
	state = BarkState.DYING
	velocity = Vector2.ZERO
	died.emit()
	play_animation(&"die")
	enable_death_hitbox()
	apply_damage_to_death_overlaps()
	await get_tree().create_timer(death_explosion_active_time).timeout
	disable_death_hitbox()
	await animated_sprite_2d.animation_finished
	finish_death()

func _on_died() -> void:
	set_physics_process(false)
	body_shape.set_deferred("disabled", true)
	contact_shape.set_deferred("disabled", true)
	disable_smash_hitbox()

func enable_smash_hitbox() -> void:
	smash_shape.set_deferred("disabled", false)

func disable_smash_hitbox() -> void:
	smash_shape.set_deferred("disabled", true)

func enable_death_hitbox() -> void:
	death_shape.set_deferred("disabled", false)

func disable_death_hitbox() -> void:
	death_shape.set_deferred("disabled", true)

func _on_smash_hitbox_body_entered(body: Node) -> void:
	apply_smash_damage(body)

func apply_damage_to_smash_overlaps() -> void:
	for body_variant in smash_hitbox.get_overlapping_bodies():
		var body := body_variant as Node
		if body != null:
			apply_smash_damage(body)

func apply_smash_damage(target: Node) -> void:
	if state != BarkState.SMASH_FALL:
		return
	if not target.is_in_group("player"):
		return

	var target_instance_id := target.get_instance_id()
	if hit_players_this_attack.has(target_instance_id):
		return

	hit_players_this_attack[target_instance_id] = true
	if target.has_method("take_damage"):
		target.call("take_damage", attack_power)
	if target.has_method("apply_knockback") and target is Node2D:
		var target_node := target as Node2D
		var knockback_direction_x := signf(target_node.global_position.x - global_position.x)
		if knockback_direction_x == 0.0:
			knockback_direction_x = 1.0
		target.call("apply_knockback", Vector2(contact_knockback.x * knockback_direction_x, contact_knockback.y))

func _on_death_hitbox_body_entered(body: Node) -> void:
	apply_death_damage(body)

func apply_damage_to_death_overlaps() -> void:
	for body_variant in death_hitbox.get_overlapping_bodies():
		var body := body_variant as Node
		if body != null:
			apply_death_damage(body)

func apply_death_damage(target: Node) -> void:
	if not is_dead:
		return
	if not target.is_in_group("player"):
		return

	var target_instance_id := target.get_instance_id()
	if hit_players_this_death.has(target_instance_id):
		return

	hit_players_this_death[target_instance_id] = true
	if target.has_method("take_damage"):
		target.call("take_damage", death_explosion_damage)

func update_facing(direction_x: float) -> void:
	if direction_x == 0.0:
		return
	animated_sprite_2d.flip_h = direction_x < 0.0

func play_animation(animation_name: StringName) -> void:
	if animated_sprite_2d.animation == animation_name:
		return
	if animated_sprite_2d.sprite_frames.has_animation(animation_name):
		animated_sprite_2d.play(animation_name)
