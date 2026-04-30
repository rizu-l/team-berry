extends EnemyBase

enum FroggerState { IDLE, WANDER, JUMP_TOWARD, JUMP_BACK, BUFFERING, ATTACKING, HEALING, HURT }

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var tongue_hitbox: Area2D = $TongueHitbox
@onready var spit_hitbox: Area2D = $SpitHitbox
@onready var tongue_hitbox_shape: CollisionPolygon2D = $TongueHitbox/CollisionPolygon2D
@onready var spit_hitbox_shape: CollisionPolygon2D = $SpitHitbox/CollisionPolygon2D

@export var tongue_attack_range: float = 115.0
@export var spit_attack_range: float = 260.0
@export var attack_cooldown: float = 1.2
@export var tongue_active_start_frame: int = 2
@export var tongue_active_end_frame: int = 5
@export var spit_active_start_frame: int = 7
@export var spit_active_end_frame: int = 10
@export var jump_toward_speed: float = 95.0
@export var jump_back_speed: float = 120.0
@export var jump_velocity: float = -230.0
@export var jump_back_velocity: float = -190.0
@export var approach_jump_limit: int = 2
@export var approach_stop_radius: float = 155.0
@export var landing_action_buffer: float = 0.35
@export var pre_attack_buffer: float = 0.45
@export var post_attack_recovery: float = 0.55
@export var heal_amount: int = 25
@export var heal_cooldown: float = 8.0
@export var heal_when_hp_percent_below: float = 0.45
@export var heal_apply_frame: int = 10
@export var random_walk_min_duration: float = 0.7
@export var random_walk_max_duration: float = 1.8
@export var random_idle_min_duration: float = 0.4
@export var random_idle_max_duration: float = 1.1

var state = FroggerState.IDLE
var attack_cooldown_remaining: float = 0.0
var heal_cooldown_remaining: float = 0.0
var hit_players_this_attack: Dictionary = {}
var current_active_hitbox: Area2D
var pending_attack_animation: StringName = &""
var has_healed_this_animation: bool = false
var approach_jump_count: int = 0
var buffered_action: StringName = &""
var action_buffer_remaining: float = 0.0
var wander_direction: float = 0.0
var wander_time_remaining: float = 0.0
var rng := RandomNumberGenerator.new()

var tongue_hitbox_base_position: Vector2
var spit_hitbox_base_position: Vector2
var tongue_shape_base_position: Vector2
var spit_shape_base_position: Vector2
var tongue_shape_base_polygon: PackedVector2Array
var spit_shape_base_polygon: PackedVector2Array

func _ready() -> void:
	super._ready()
	rng.randomize()
	damaged.connect(_on_damaged)
	died.connect(_on_died)
	for animation_name in [&"hurt", &"tongue", &"spit", &"heal"]:
		if animated_sprite_2d.sprite_frames.has_animation(animation_name):
			animated_sprite_2d.sprite_frames.set_animation_loop(animation_name, false)

	animated_sprite_2d.frame_changed.connect(_on_animation_frame_changed)
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	store_attack_hitbox_bases()
	setup_attack_hitboxes()
	choose_next_wander()
	animated_sprite_2d.play(&"idle")

func process_ai(delta: float) -> void:
	if is_dead:
		return

	update_action_cooldowns(delta)

	if state == FroggerState.ATTACKING or state == FroggerState.HEALING or state == FroggerState.HURT:
		velocity.x = 0.0
		return

	if state == FroggerState.BUFFERING:
		update_action_buffer(delta)
		return

	if not is_on_floor():
		return

	if state == FroggerState.JUMP_TOWARD:
		finish_jump_toward()
		return
	if state == FroggerState.JUMP_BACK:
		finish_jump_back()
		return

	if should_start_heal():
		start_heal()
		return

	var target := find_nearest_target(target_detection_range)
	if target != null:
		start_approach_sequence(target)
		return

	update_random_wander(delta)
	update_movement_animation()

func update_action_cooldowns(delta: float) -> void:
	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	if heal_cooldown_remaining > 0.0:
		heal_cooldown_remaining = maxf(heal_cooldown_remaining - delta, 0.0)

func should_start_heal() -> bool:
	if heal_cooldown_remaining > 0.0:
		return false
	if hp >= max_hp:
		return false
	if not animated_sprite_2d.sprite_frames.has_animation(&"heal"):
		return false

	return float(hp) / float(max_hp) <= heal_when_hp_percent_below

func start_heal() -> void:
	state = FroggerState.HEALING
	velocity.x = 0.0
	approach_jump_count = 0
	buffered_action = &""
	has_healed_this_animation = false
	disable_attack_hitboxes()
	animated_sprite_2d.stop()
	animated_sprite_2d.play(&"heal")

func start_approach_sequence(target: Node2D) -> void:
	approach_jump_count = 0
	var distance_to_target := global_position.distance_to(target.global_position)
	if should_stop_approaching(distance_to_target):
		if attack_cooldown_remaining <= 0.0:
			set_pending_attack(target)
			start_action_buffer(&"jump_back", landing_action_buffer)
		else:
			start_action_buffer(&"", landing_action_buffer)
		return

	start_jump_toward(target)

func start_jump_toward(target: Node2D) -> void:
	var direction := get_direction_to_target(target)
	if direction == 0.0:
		direction = 1.0
	direction = get_ledge_safe_direction(direction)
	if direction == 0.0:
		approach_jump_count = 0
		start_action_buffer(&"", landing_action_buffer)
		return

	state = FroggerState.JUMP_TOWARD
	approach_jump_count += 1
	set_facing_direction(direction)
	velocity = Vector2(direction * jump_toward_speed, jump_velocity)
	play_move_animation()

func finish_jump_toward() -> void:
	velocity.x = 0.0
	var target := find_nearest_target(target_detection_range)
	if target == null:
		state = FroggerState.IDLE
		return

	var distance_to_target := global_position.distance_to(target.global_position)
	if should_stop_approaching(distance_to_target):
		if attack_cooldown_remaining > 0.0:
			approach_jump_count = 0
			start_action_buffer(&"", landing_action_buffer)
			return

		set_pending_attack(target)
		start_action_buffer(&"jump_back", landing_action_buffer)
	else:
		start_action_buffer(&"jump_toward", landing_action_buffer)

func should_stop_approaching(distance_to_target: float) -> bool:
	return approach_jump_count >= approach_jump_limit or distance_to_target <= approach_stop_radius

func set_pending_attack(target: Node2D) -> void:
	var distance_to_target := global_position.distance_to(target.global_position)
	pending_attack_animation = &"tongue" if distance_to_target <= tongue_attack_range else &"spit"

func start_action_buffer(action: StringName, duration: float) -> void:
	state = FroggerState.BUFFERING
	buffered_action = action
	action_buffer_remaining = maxf(duration, 0.0)
	velocity.x = 0.0
	if animated_sprite_2d.animation != &"idle":
		animated_sprite_2d.play(&"idle")

func update_action_buffer(delta: float) -> void:
	velocity.x = 0.0
	action_buffer_remaining -= delta
	if action_buffer_remaining > 0.0:
		return

	var action := buffered_action
	buffered_action = &""
	state = FroggerState.IDLE

	if action == &"jump_toward":
		var target := find_nearest_target(target_detection_range)
		if target != null:
			start_jump_toward(target)
	elif action == &"jump_back":
		var target := find_nearest_target(target_detection_range)
		if target != null:
			start_jump_back_before_attack(target)
	elif action == &"attack":
		if pending_attack_animation != &"":
			start_attack(pending_attack_animation)

func start_jump_back_before_attack(target: Node2D) -> void:
	var direction_to_target := get_direction_to_target(target)
	if direction_to_target == 0.0:
		direction_to_target = 1.0

	set_pending_attack(target)
	var jump_direction := get_ledge_safe_direction(-direction_to_target)
	if jump_direction == 0.0:
		set_facing_direction(direction_to_target)
		start_action_buffer(&"attack", pre_attack_buffer)
		return

	state = FroggerState.JUMP_BACK
	set_facing_direction(direction_to_target)
	velocity = Vector2(jump_direction * jump_back_speed, jump_back_velocity)
	play_move_animation()

func finish_jump_back() -> void:
	velocity.x = 0.0
	var target := find_nearest_target(target_detection_range)
	if target != null:
		set_facing_direction(get_direction_to_target(target))

	if pending_attack_animation == &"":
		state = FroggerState.IDLE
		return

	start_action_buffer(&"attack", pre_attack_buffer)

func start_attack(animation_name: StringName) -> void:
	if not animated_sprite_2d.sprite_frames.has_animation(animation_name):
		state = FroggerState.IDLE
		return

	state = FroggerState.ATTACKING
	approach_jump_count = 0
	pending_attack_animation = &""
	hit_players_this_attack.clear()
	disable_attack_hitboxes()
	velocity.x = 0.0
	animated_sprite_2d.stop()
	animated_sprite_2d.play(animation_name)
	update_attack_hitboxes_for_current_frame()

func store_attack_hitbox_bases() -> void:
	tongue_hitbox_base_position = tongue_hitbox.position
	spit_hitbox_base_position = spit_hitbox.position
	tongue_shape_base_position = tongue_hitbox_shape.position
	spit_shape_base_position = spit_hitbox_shape.position
	tongue_shape_base_polygon = tongue_hitbox_shape.polygon
	spit_shape_base_polygon = spit_hitbox_shape.polygon

func setup_attack_hitboxes() -> void:
	setup_attack_hitbox(tongue_hitbox)
	setup_attack_hitbox(spit_hitbox)
	disable_attack_hitboxes()

func setup_attack_hitbox(hitbox: Area2D) -> void:
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2
	hitbox.monitoring = true
	hitbox.monitorable = false
	hitbox.body_entered.connect(_on_attack_hitbox_body_entered.bind(hitbox))

func set_facing_direction(direction: float) -> void:
	if direction == 0.0:
		return

	animated_sprite_2d.flip_h = direction < 0.0
	update_attack_hitbox_positions()

func update_attack_hitbox_positions() -> void:
	var facing_sign := -1.0 if animated_sprite_2d.flip_h else 1.0
	update_attack_hitbox_position(tongue_hitbox, tongue_hitbox_base_position, tongue_hitbox_shape, tongue_shape_base_position, tongue_shape_base_polygon, facing_sign)
	update_attack_hitbox_position(spit_hitbox, spit_hitbox_base_position, spit_hitbox_shape, spit_shape_base_position, spit_shape_base_polygon, facing_sign)

func update_attack_hitbox_position(
	hitbox: Area2D,
	base_hitbox_position: Vector2,
	shape: CollisionPolygon2D,
	base_shape_position: Vector2,
	base_polygon: PackedVector2Array,
	facing_sign: float
) -> void:
	hitbox.position = Vector2(base_hitbox_position.x * facing_sign, base_hitbox_position.y)
	shape.position = Vector2(base_shape_position.x * facing_sign, base_shape_position.y)
	shape.polygon = get_flipped_polygon(base_polygon, facing_sign)

func get_flipped_polygon(base_polygon: PackedVector2Array, facing_sign: float) -> PackedVector2Array:
	if facing_sign > 0.0:
		return base_polygon

	var flipped_polygon := PackedVector2Array()
	for point in base_polygon:
		flipped_polygon.append(Vector2(-point.x, point.y))

	return flipped_polygon

func _on_animation_frame_changed() -> void:
	if state == FroggerState.HEALING:
		try_apply_heal()
		return

	update_attack_hitboxes_for_current_frame()

func try_apply_heal() -> void:
	if has_healed_this_animation:
		return
	if animated_sprite_2d.animation != &"heal":
		return
	if animated_sprite_2d.frame < heal_apply_frame:
		return

	has_healed_this_animation = true
	heal(heal_amount)

func update_attack_hitboxes_for_current_frame() -> void:
	disable_attack_hitboxes()
	if state != FroggerState.ATTACKING:
		return

	if animated_sprite_2d.animation == &"tongue":
		var is_tongue_active := animated_sprite_2d.frame >= tongue_active_start_frame and animated_sprite_2d.frame <= tongue_active_end_frame
		tongue_hitbox_shape.set_deferred("disabled", not is_tongue_active)
		if is_tongue_active:
			current_active_hitbox = tongue_hitbox
			apply_damage_to_overlaps(tongue_hitbox)
	elif animated_sprite_2d.animation == &"spit":
		var is_spit_active := animated_sprite_2d.frame >= spit_active_start_frame and animated_sprite_2d.frame <= spit_active_end_frame
		spit_hitbox_shape.set_deferred("disabled", not is_spit_active)
		if is_spit_active:
			current_active_hitbox = spit_hitbox
			apply_damage_to_overlaps(spit_hitbox)

func _on_animation_finished() -> void:
	if state == FroggerState.ATTACKING:
		attack_cooldown_remaining = attack_cooldown
		hit_players_this_attack.clear()
		disable_attack_hitboxes()
		start_action_buffer(&"", post_attack_recovery)
	elif state == FroggerState.HEALING:
		try_apply_heal()
		heal_cooldown_remaining = heal_cooldown
		start_action_buffer(&"", post_attack_recovery)
	elif state == FroggerState.HURT:
		state = FroggerState.IDLE
		animated_sprite_2d.play(&"idle")

func disable_attack_hitboxes() -> void:
	current_active_hitbox = null
	tongue_hitbox_shape.set_deferred("disabled", true)
	spit_hitbox_shape.set_deferred("disabled", true)

func apply_damage_to_overlaps(hitbox: Area2D) -> void:
	for body_variant in hitbox.get_overlapping_bodies():
		var body := body_variant as Node
		if body != null:
			apply_attack_damage(body)

func _on_attack_hitbox_body_entered(body: Node, hitbox: Area2D) -> void:
	if hitbox != current_active_hitbox:
		return

	apply_attack_damage(body)

func apply_attack_damage(target: Node) -> void:
	if is_dead:
		return
	if state != FroggerState.ATTACKING:
		return
	if not target.is_in_group("player"):
		return

	var target_instance_id := target.get_instance_id()
	if hit_players_this_attack.has(target_instance_id):
		return

	hit_players_this_attack[target_instance_id] = true
	if target.has_method("take_damage"):
		target.call("take_damage", attack_power)

	var target_node_2d := target as Node2D
	if target_node_2d != null and target.has_method("apply_knockback"):
		var knockback_direction_x := signf(target_node_2d.global_position.x - global_position.x)
		if knockback_direction_x == 0.0:
			knockback_direction_x = -1.0 if animated_sprite_2d.flip_h else 1.0
		target.call("apply_knockback", Vector2(contact_knockback.x * knockback_direction_x, contact_knockback.y))

func update_random_wander(delta: float) -> void:
	state = FroggerState.WANDER
	wander_time_remaining -= delta
	if wander_time_remaining <= 0.0:
		choose_next_wander()

	velocity.x = wander_direction * move_speed
	if wander_direction != 0.0:
		wander_direction = get_safe_wander_direction(wander_direction)
		velocity.x = wander_direction * move_speed
		if wander_direction != 0.0:
			set_facing_direction(wander_direction)

func get_safe_wander_direction(direction: float) -> float:
	var safe_direction := get_ledge_safe_direction(direction)
	if safe_direction != 0.0:
		return safe_direction

	var opposite_direction := get_ledge_safe_direction(-direction)
	if opposite_direction != 0.0:
		wander_time_remaining = rng.randf_range(random_walk_min_duration, random_walk_max_duration)
		return opposite_direction

	wander_time_remaining = rng.randf_range(random_idle_min_duration, random_idle_max_duration)
	return 0.0

func choose_next_wander() -> void:
	var should_idle := rng.randi_range(0, 2) == 0
	if should_idle:
		wander_direction = 0.0
		wander_time_remaining = rng.randf_range(random_idle_min_duration, random_idle_max_duration)
	else:
		wander_direction = -1.0 if rng.randi_range(0, 1) == 0 else 1.0
		wander_time_remaining = rng.randf_range(random_walk_min_duration, random_walk_max_duration)

func update_movement_animation() -> void:
	if wander_direction == 0.0:
		state = FroggerState.IDLE
		velocity.x = 0.0
		if animated_sprite_2d.animation != &"idle":
			animated_sprite_2d.play(&"idle")
		return

	play_move_animation()

func play_move_animation() -> void:
	if animated_sprite_2d.animation != &"move":
		animated_sprite_2d.play(&"move")

func _on_damaged(_amount: int) -> void:
	if is_dead:
		return

	if state == FroggerState.ATTACKING or state == FroggerState.HEALING or state == FroggerState.JUMP_TOWARD or state == FroggerState.JUMP_BACK:
		return
	if state == FroggerState.HURT and animated_sprite_2d.is_playing():
		return

	state = FroggerState.HURT
	velocity.x = 0.0
	disable_attack_hitboxes()
	if animated_sprite_2d.sprite_frames.has_animation(&"hurt"):
		animated_sprite_2d.stop()
		animated_sprite_2d.play(&"hurt")
	else:
		state = FroggerState.IDLE

func _on_died() -> void:
	set_physics_process(false)
	disable_attack_hitboxes()
	velocity = Vector2.ZERO
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("ContactHitbox/CollisionPolygon2D"):
		$ContactHitbox/CollisionPolygon2D.set_deferred("disabled", true)
