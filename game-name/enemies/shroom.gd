extends EnemyBase

enum ShroomState { CHASING, WINDUP, ATTACKING, STUNNED, HURT, DYING }

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var contact_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

@export var chase_speed: float = 260.0
@export var attack_range: float = 74.0
@export var attack_windup_min_time: float = 0.18
@export var attack_windup_max_time: float = 0.28
@export var attack_speed: float = 430.0
@export var attack_duration: float = 0.42
@export var attack_cooldown: float = 0.65
@export var attack_speed_randomness: float = 0.18
@export var attack_duration_randomness: float = 0.16
@export var chase_speed_randomness: float = 0.14
@export var chase_jitter_interval_min: float = 0.18
@export var chase_jitter_interval_max: float = 0.42
@export var chase_jitter_strength: float = 34.0
@export var attack_knockback: Vector2 = Vector2(430.0, -260.0)
@export var stun_duration: float = 1.15
@export var hit_reaction_time: float = 0.18

var state = ShroomState.CHASING
var state_time_remaining: float = 0.0
var attack_cooldown_remaining: float = 0.0
var attack_direction: float = 1.0
var has_hit_player_this_attack: bool = false
var current_attack_speed: float = 0.0
var current_chase_speed: float = 0.0
var chase_jitter: float = 0.0
var chase_jitter_time_remaining: float = 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	rng.randomize()
	ledge_avoidance_enabled = false
	randomize_chase_movement()
	damaged.connect(_on_damaged)
	died.connect(_on_died)
	for animation_name in [&"attack", &"hit", &"die"]:
		if animated_sprite_2d.sprite_frames.has_animation(animation_name):
			animated_sprite_2d.sprite_frames.set_animation_loop(animation_name, false)

	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 2
	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = false
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	disable_attack_hitbox()
	play_animation(&"run")

func process_ai(delta: float) -> void:
	if is_dead:
		velocity.x = 0.0
		return

	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)

	match state:
		ShroomState.CHASING:
			process_chasing()
		ShroomState.WINDUP:
			process_windup(delta)
		ShroomState.ATTACKING:
			process_attacking(delta)
		ShroomState.STUNNED:
			process_stunned(delta)
		ShroomState.HURT:
			process_hurt(delta)
		ShroomState.DYING:
			velocity.x = 0.0

func can_apply_contact_damage() -> bool:
	return false

func prevent_ledge_fall() -> void:
	pass

func process_chasing() -> void:
	disable_attack_hitbox()
	if not is_on_floor():
		play_animation(&"run")
		return

	var target := find_nearest_target(target_detection_range)
	if target == null:
		velocity.x = 0.0
		play_animation(&"idle")
		return

	var distance_to_target := global_position.distance_to(target.global_position)
	if attack_cooldown_remaining <= 0.0 and distance_to_target <= attack_range:
		start_attack_windup(target)
		return

	update_chase_jitter()
	var direction := get_direction_to_target(target)
	if absf(target.global_position.x - global_position.x) <= attack_range * 0.55:
		direction = 0.0
	velocity.x = direction * current_chase_speed
	velocity.x += chase_jitter
	if direction != 0.0:
		set_facing_direction(direction)
		play_animation(&"run")
	else:
		play_animation(&"idle")

func start_attack_windup(target: Node2D) -> void:
	state = ShroomState.WINDUP
	state_time_remaining = rng.randf_range(attack_windup_min_time, attack_windup_max_time)
	velocity.x = 0.0
	attack_direction = get_direction_to_target(target)
	if attack_direction == 0.0:
		attack_direction = -1.0 if animated_sprite_2d.flip_h else 1.0
	set_facing_direction(attack_direction)
	has_hit_player_this_attack = false
	current_attack_speed = attack_speed * rng.randf_range(1.0 - attack_speed_randomness, 1.0 + attack_speed_randomness)
	disable_attack_hitbox()
	play_animation(&"attack")

func process_windup(delta: float) -> void:
	velocity.x = 0.0
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = ShroomState.ATTACKING
		state_time_remaining = attack_duration * rng.randf_range(1.0 - attack_duration_randomness, 1.0 + attack_duration_randomness)
		enable_attack_hitbox()
		play_animation(&"attack_stun")

func process_attacking(delta: float) -> void:
	enable_attack_hitbox()
	velocity.x = attack_direction * current_attack_speed
	apply_damage_to_attack_overlaps()

	if is_on_wall():
		start_stun()
		return

	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		if has_hit_player_this_attack:
			finish_attack()
		else:
			start_stun()

func finish_attack() -> void:
	state = ShroomState.CHASING
	velocity.x = 0.0
	attack_cooldown_remaining = get_randomized_attack_cooldown()
	disable_attack_hitbox()
	randomize_chase_movement()
	play_animation(&"run")

func start_stun() -> void:
	state = ShroomState.STUNNED
	state_time_remaining = stun_duration * rng.randf_range(0.85, 1.2)
	velocity.x = 0.0
	attack_cooldown_remaining = get_randomized_attack_cooldown()
	disable_attack_hitbox()
	play_animation(&"stun")

func process_stunned(delta: float) -> void:
	velocity.x = 0.0
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = ShroomState.CHASING
		randomize_chase_movement()
		play_animation(&"run")

func process_hurt(delta: float) -> void:
	velocity.x = 0.0
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = ShroomState.CHASING
		randomize_chase_movement()
		play_animation(&"run")

func update_chase_jitter() -> void:
	chase_jitter_time_remaining -= get_physics_process_delta_time()
	if chase_jitter_time_remaining > 0.0:
		return

	chase_jitter_time_remaining = rng.randf_range(chase_jitter_interval_min, chase_jitter_interval_max)
	chase_jitter = rng.randf_range(-chase_jitter_strength, chase_jitter_strength)

func randomize_chase_movement() -> void:
	current_chase_speed = chase_speed * rng.randf_range(1.0 - chase_speed_randomness, 1.0 + chase_speed_randomness)
	chase_jitter_time_remaining = 0.0
	chase_jitter = 0.0

func get_randomized_attack_cooldown() -> float:
	return attack_cooldown * rng.randf_range(0.75, 1.35)

func set_facing_direction(direction: float) -> void:
	if direction == 0.0:
		return

	animated_sprite_2d.flip_h = direction < 0.0
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * (-1.0 if animated_sprite_2d.flip_h else 1.0)
	attack_shape.position.x = absf(attack_shape.position.x) * (-1.0 if animated_sprite_2d.flip_h else 1.0)

func enable_attack_hitbox() -> void:
	attack_shape.set_deferred("disabled", false)

func disable_attack_hitbox() -> void:
	attack_shape.set_deferred("disabled", true)

func _on_attack_hitbox_body_entered(body: Node) -> void:
	apply_attack_damage(body)

func apply_damage_to_attack_overlaps() -> void:
	for body_variant in attack_hitbox.get_overlapping_bodies():
		var body := body_variant as Node
		if body != null:
			apply_attack_damage(body)

func apply_attack_damage(target: Node) -> void:
	if state != ShroomState.ATTACKING:
		return
	if not target.is_in_group("player"):
		return
	if has_hit_player_this_attack:
		return

	has_hit_player_this_attack = true
	if target.has_method("take_damage"):
		target.call("take_damage", attack_power)
	if target.has_method("apply_knockback") and target is Node2D:
		var target_node := target as Node2D
		var knockback_direction_x := signf(target_node.global_position.x - global_position.x)
		if knockback_direction_x == 0.0:
			knockback_direction_x = attack_direction
		target.call("apply_knockback", Vector2(attack_knockback.x * knockback_direction_x, attack_knockback.y))

func _on_damaged(_amount: int) -> void:
	if is_dead:
		return
	if state == ShroomState.ATTACKING or state == ShroomState.STUNNED:
		return

	state = ShroomState.HURT
	state_time_remaining = hit_reaction_time
	velocity.x = 0.0
	disable_attack_hitbox()
	play_animation(&"hit")

func die() -> void:
	if is_dead:
		return

	is_dead = true
	state = ShroomState.DYING
	velocity = Vector2.ZERO
	died.emit()
	disable_attack_hitbox()
	play_animation(&"die")
	await animated_sprite_2d.animation_finished
	finish_death()

func _on_died() -> void:
	set_physics_process(false)
	body_shape.set_deferred("disabled", true)
	contact_shape.set_deferred("disabled", true)
	disable_attack_hitbox()

func play_animation(animation_name: StringName) -> void:
	if animated_sprite_2d.animation == animation_name:
		return
	if animated_sprite_2d.sprite_frames.has_animation(animation_name):
		animated_sprite_2d.play(animation_name)
