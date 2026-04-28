extends EnemyBase

enum SamuraiState { CHASING, DODGING, WINDUP, ATTACKING, RECOVERING, HURT, DYING }

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var contact_shape: CollisionShape2D = $ContactHitbox/CollisionShape2D
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

@export var chase_speed: float = 245.0
@export var attack_range: float = 86.0
@export var dodge_chance: float = 0.65
@export var attack_knockback: Vector2 = Vector2(560.0, -250.0)
@export var attack_stun_time: float = 0.3

const ATTACK_SLIDE_SPEED := 105.0
const ATTACK_WINDUP_TIME := 0.36
const ATTACK_ACTIVE_TIME := 0.16
const ATTACK_RECOVERY_TIME := 0.62
const ATTACK_COOLDOWN := 1.25
const DODGE_DETECTION_RANGE := 118.0
const DODGE_SPEED := 320.0
const DODGE_TIME := 0.18
const DODGE_COOLDOWN := 0.9
const HIT_REACTION_TIME := 0.14

var state = SamuraiState.CHASING
var state_time_remaining: float = 0.0
var attack_cooldown_remaining: float = 0.0
var dodge_cooldown_remaining: float = 0.0
var attack_direction: float = 1.0
var dodge_direction: float = 1.0
var hit_players_this_attack: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	rng.randomize()
	damaged.connect(_on_damaged)
	died.connect(_on_died)
	for animation_name in [&"attack", &"hit"]:
		if animated_sprite_2d.sprite_frames.has_animation(animation_name):
			animated_sprite_2d.sprite_frames.set_animation_loop(animation_name, false)

	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 2
	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = false
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	disable_attack_hitbox()
	play_animation(&"idle")

func process_ai(delta: float) -> void:
	if is_dead:
		velocity.x = 0.0
		return

	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	if dodge_cooldown_remaining > 0.0:
		dodge_cooldown_remaining = maxf(dodge_cooldown_remaining - delta, 0.0)

	match state:
		SamuraiState.CHASING:
			process_chasing()
		SamuraiState.DODGING:
			process_dodging(delta)
		SamuraiState.WINDUP:
			process_windup(delta)
		SamuraiState.ATTACKING:
			process_attacking(delta)
		SamuraiState.RECOVERING:
			process_recovering(delta)
		SamuraiState.HURT:
			process_hurt(delta)
		SamuraiState.DYING:
			velocity.x = 0.0

func can_apply_contact_damage() -> bool:
	return state != SamuraiState.WINDUP and state != SamuraiState.ATTACKING and state != SamuraiState.RECOVERING

func process_chasing() -> void:
	disable_attack_hitbox()
	var target := find_nearest_target(target_detection_range)
	if target == null:
		velocity.x = 0.0
		play_animation(&"idle")
		return

	face_target_samurai(target)
	var distance_x := target.global_position.x - global_position.x
	var abs_distance_x := absf(distance_x)
	if should_dodge_player_attack(target, abs_distance_x):
		start_dodge(target)
		return

	if can_start_attack(abs_distance_x):
		start_attack_windup(target)
		return

	var direction := signf(distance_x)
	if direction == 0.0:
		velocity.x = 0.0
	else:
		velocity.x = get_ledge_safe_direction(direction) * chase_speed

	play_animation(&"run" if velocity.x != 0.0 else &"idle")

func process_dodging(delta: float) -> void:
	disable_attack_hitbox()
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = SamuraiState.CHASING
		return

	velocity.x = get_ledge_safe_direction(dodge_direction) * DODGE_SPEED
	play_animation(&"run" if velocity.x != 0.0 else &"idle")

func can_start_attack(abs_distance_x) -> bool:
	return attack_cooldown_remaining <= 0.0 and abs_distance_x <= attack_range and is_on_floor()

func should_dodge_player_attack(target: Node2D, abs_distance_x) -> bool:
	if dodge_cooldown_remaining > 0.0:
		return false
	if abs_distance_x > DODGE_DETECTION_RANGE:
		return false
	if target == null or not bool(target.get("is_attacking")):
		return false
	if rng.randf() > dodge_chance:
		return false

	return is_player_attacking_toward_samurai(target)

func is_player_attacking_toward_samurai(target: Node2D) -> bool:
	var player_direction := float(target.get("lastDirection"))
	var direction_from_player := signf(global_position.x - target.global_position.x)
	if player_direction == 0.0 or direction_from_player == 0.0:
		return true

	return signf(player_direction) == direction_from_player

func start_dodge(target: Node2D) -> void:
	state = SamuraiState.DODGING
	state_time_remaining = DODGE_TIME
	dodge_cooldown_remaining = DODGE_COOLDOWN * rng.randf_range(0.8, 1.25)
	dodge_direction = -get_direction_to_target(target)
	if dodge_direction == 0.0:
		dodge_direction = -1.0 if animated_sprite_2d.flip_h else 1.0
	velocity.x = get_ledge_safe_direction(dodge_direction) * DODGE_SPEED
	play_animation(&"run")

func start_attack_windup(target: Node2D) -> void:
	state = SamuraiState.WINDUP
	state_time_remaining = ATTACK_WINDUP_TIME * rng.randf_range(0.9, 1.12)
	velocity.x = 0.0
	attack_direction = get_direction_to_target(target)
	if attack_direction == 0.0:
		attack_direction = -1.0 if animated_sprite_2d.flip_h else 1.0
	face_direction(attack_direction)
	hit_players_this_attack.clear()
	disable_attack_hitbox()
	play_animation(&"attack")

func process_windup(delta: float) -> void:
	velocity.x = 0.0
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = SamuraiState.ATTACKING
		state_time_remaining = ATTACK_ACTIVE_TIME
		enable_attack_hitbox()

func process_attacking(delta: float) -> void:
	velocity.x = attack_direction * ATTACK_SLIDE_SPEED
	enable_attack_hitbox()
	apply_damage_to_attack_overlaps()

	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		start_recovery()

func start_recovery() -> void:
	state = SamuraiState.RECOVERING
	state_time_remaining = ATTACK_RECOVERY_TIME
	attack_cooldown_remaining = ATTACK_COOLDOWN * rng.randf_range(0.85, 1.2)
	velocity.x = 0.0
	disable_attack_hitbox()

func process_recovering(delta: float) -> void:
	velocity.x = 0.0
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = SamuraiState.CHASING
		play_animation(&"idle")

func process_hurt(delta: float) -> void:
	velocity.x = 0.0
	state_time_remaining -= delta
	if state_time_remaining <= 0.0:
		state = SamuraiState.CHASING
		play_animation(&"idle")

func face_target_samurai(target: Node2D) -> void:
	face_direction(get_direction_to_target(target))

func face_direction(direction: float) -> void:
	if direction == 0.0:
		return

	animated_sprite_2d.flip_h = direction < 0.0
	var facing_sign := -1.0 if animated_sprite_2d.flip_h else 1.0
	attack_hitbox.position.x = absf(attack_hitbox.position.x) * facing_sign
	attack_shape.position.x = absf(attack_shape.position.x) * facing_sign

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
	if state != SamuraiState.ATTACKING:
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
			knockback_direction_x = attack_direction
		target.call("apply_knockback", Vector2(attack_knockback.x * knockback_direction_x, attack_knockback.y))
	if target.has_method("apply_stun"):
		target.call("apply_stun", attack_stun_time)

func _on_damaged(_amount: int) -> void:
	if is_dead:
		return
	if state == SamuraiState.WINDUP or state == SamuraiState.ATTACKING or state == SamuraiState.RECOVERING:
		return

	state = SamuraiState.HURT
	state_time_remaining = HIT_REACTION_TIME
	velocity.x = 0.0
	disable_attack_hitbox()
	play_animation(&"hit")

func die() -> void:
	if is_dead:
		return

	is_dead = true
	state = SamuraiState.DYING
	velocity = Vector2.ZERO
	died.emit()
	disable_attack_hitbox()
	if animated_sprite_2d.sprite_frames.has_animation(&"hit"):
		play_animation(&"hit")
		await animated_sprite_2d.animation_finished
	finish_death()

func _on_died() -> void:
	set_physics_process(false)
	body_shape.set_deferred("disabled", true)
	contact_shape.set_deferred("disabled", true)
	disable_attack_hitbox()

func play_animation(animation_name: StringName) -> void:
	var selected_animation := animation_name
	if selected_animation == &"run" and not animated_sprite_2d.sprite_frames.has_animation(&"run"):
		selected_animation = &"fly"
	if animated_sprite_2d.animation == selected_animation:
		return
	if animated_sprite_2d.sprite_frames.has_animation(selected_animation):
		animated_sprite_2d.play(selected_animation)
