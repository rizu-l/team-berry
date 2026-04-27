extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var dash_particles: GPUParticles2D = get_node_or_null("DashParticles") as GPUParticles2D
@onready var player_collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_hitbox_1: Area2D = get_node_or_null("AttackHitbox1") as Area2D
@onready var attack_hitbox_2: Area2D = get_node_or_null("AttackHitbox2") as Area2D
@onready var attack_hitbox_3: Area2D = get_node_or_null("AttackHitbox3") as Area2D
@onready var respawn_probe_area: Area2D = get_node_or_null("Area2D") as Area2D

const ATTACK_ANIMATIONS := [&"Attack1", &"Attack2", &"Attack3"]
const WALK_SPEED = 100.0
const SPRINT_SPEED = 300.0
const JUMP_VELOCITY = -400.0
var currentState
var jumpDirection = 0  # Store the jump direction
var lastDirection = 1  # Store the last facing direction (1 = right, -1 = left)
var doubleJump = true
var isDoubleJumping = false
var is_dashing = false
var is_attacking = false
var is_blinking = false
var dash_timer = 0.0
var dash_cooldown_remaining = 0.0
var dash_direction = 1.0
var blink_cooldown_remaining = 0.0
var respawn_invulnerability_remaining = 0.0
var respawn_flash_timer = 0.0
var current_attack_index = -1
var attack_sequence_id = 0
var damage_knockback_lock_remaining = 0.0
var attack_hitboxes = []
var attack_hitbox_shapes = []
var attack_hitbox_base_positions: Array[Vector2] = []
var attack_hitbox_shape_base_positions: Array[Vector2] = []
var last_safe_ground_position = Vector2.ZERO
enum State { Idle, Walk, Run, Jump, Fall, DoubleJump, Blink, Dash, Sit}

@export var starting_max_hp: int = 100
@export var starting_hp: int = 70
@export var starting_max_mp: float = 100.0
@export var starting_mp: float = 50.0
@export var starting_attack: int = 10
@export var mp_regen_per_second: float = 3.0
@export var heal_amount: int = 30
@export var heal_mp_cost: float = 25.0
@export var void_y_threshold: float = 1000.0
@export var respawn_invulnerability_duration: float = 1.5
@export var respawn_flash_interval: float = 0.12
@export var damage_knockback_lock_duration: float = 0.18
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 0.25
@export var start_with_blink: bool = true
@export var blink_distance: float = 160.0
@export var blink_cooldown: float = 0.35
@export var blink_wall_margin: float = 2.0

var hp: int:
	get:
		return GameManager.get_player_hp()
	set(value):
		GameManager.set_player_hp(value)

var max_hp: int:
	get:
		return GameManager.get_player_max_hp()
	set(value):
		GameManager.set_player_max_hp(value)

var mp: float:
	get:
		return GameManager.get_player_mp()
	set(value):
		GameManager.set_player_mp(value)

var max_mp: float:
	get:
		return GameManager.get_player_max_mp()
	set(value):
		GameManager.set_player_max_mp(value)

var attack: int:
	get:
		return GameManager.get_player_attack()
	set(value):
		GameManager.set_player_attack(value)

func get_attack_power() -> int:
	return attack

var unlocked_abilities: Dictionary:
	get:
		return GameManager.get_unlocked_abilities()

func _ready():
	max_hp = starting_max_hp
	hp = starting_hp
	max_mp = starting_max_mp
	mp = starting_mp
	attack = starting_attack
	if start_with_blink:
		GameManager.unlock_ability(AbilityData.ability_list.BLINK)
	if dash_particles != null:
		dash_particles.z_index = -1
		dash_particles.show_behind_parent = true
	attack_hitboxes = [attack_hitbox_1, attack_hitbox_2, attack_hitbox_3]
	for hitbox in attack_hitboxes:
		if hitbox != null:
			hitbox.add_to_group("player_attack_hitboxes")
			hitbox.collision_layer = 16
			hitbox.collision_mask = 0
			hitbox.monitorable = true
			hitbox.monitoring = true
			var shape: CollisionShape2D = get_attack_hitbox_shape(hitbox)
			var base_shape_position_to_store: Vector2 = shape.position if shape != null else Vector2.ZERO
			attack_hitbox_shapes.append(shape)
			attack_hitbox_base_positions.append(hitbox.position)
			attack_hitbox_shape_base_positions.append(base_shape_position_to_store)
			if shape != null:
				shape.disabled = true
		else:
			attack_hitbox_shapes.append(null)
			attack_hitbox_base_positions.append(Vector2.ZERO)
			attack_hitbox_shape_base_positions.append(Vector2.ZERO)
	for animation_name in ATTACK_ANIMATIONS:
		if animated_sprite_2d.sprite_frames.has_animation(animation_name):
			animated_sprite_2d.sprite_frames.set_animation_loop(animation_name, false)
	currentState = State.Idle
	last_safe_ground_position = global_position
	add_to_group("player")
	player_animations()

func _physics_process(delta: float) -> void:
	check_void_fall()
	update_respawn_invulnerability(delta)

	if dash_cooldown_remaining > 0.0:
		dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)

	if blink_cooldown_remaining > 0.0:
		blink_cooldown_remaining = maxf(blink_cooldown_remaining - delta, 0.0)

	if damage_knockback_lock_remaining > 0.0:
		damage_knockback_lock_remaining = maxf(damage_knockback_lock_remaining - delta, 0.0)

	regenerate_mp(delta)
	player_heal()

	if is_blinking:
		velocity = Vector2.ZERO
		return

	if is_dashing:
		update_dash(delta)
		move_and_slide()
		player_animations()
		return

	player_idle(delta)
	
	# Add the gravity.
	if  !is_on_floor():
		velocity += get_gravity() * delta
	else:
		doubleJump = true
		isDoubleJumping = false
		if not is_dashing:
			dash_direction = lastDirection
		if can_store_respawn_position():
			last_safe_ground_position = global_position

	player_attack()
	player_dash()
	if is_dashing:
		update_dash(delta)
		move_and_slide()
		player_animations()
		return

	player_blink()
	if is_blinking:
		velocity = Vector2.ZERO
		return
	if is_attacking:
		update_attack_physics(delta)
	player_jump(delta)
	player_run(delta)
	move_and_slide()
	player_animations()

func check_void_fall() -> void:
	if global_position.y <= void_y_threshold:
		return

	hp = 1
	velocity = Vector2.ZERO
	cancel_attack()
	is_dashing = false
	is_blinking = false
	global_position = last_safe_ground_position
	respawn_invulnerability_remaining = respawn_invulnerability_duration
	respawn_flash_timer = 0.0
	animated_sprite_2d.modulate.a = 1.0

func update_respawn_invulnerability(delta: float) -> void:
	if respawn_invulnerability_remaining <= 0.0:
		animated_sprite_2d.modulate.a = 1.0
		return

	respawn_invulnerability_remaining = maxf(respawn_invulnerability_remaining - delta, 0.0)
	respawn_flash_timer += delta

	if respawn_flash_timer >= respawn_flash_interval:
		respawn_flash_timer = 0.0
		animated_sprite_2d.modulate.a = 1.0 if animated_sprite_2d.modulate.a < 1.0 else 0.35

	if respawn_invulnerability_remaining <= 0.0:
		animated_sprite_2d.modulate.a = 1.0

func can_store_respawn_position() -> bool:
	if respawn_probe_area == null:
		return true

	if respawn_probe_area.has_overlapping_bodies():
		return false

	var overlapping_areas: Array = respawn_probe_area.get_overlapping_areas()
	for overlapping_area_variant in overlapping_areas:
		var overlapping_area: Area2D = overlapping_area_variant as Area2D
		if overlapping_area == null:
			continue
		if overlapping_area == respawn_probe_area:
			continue
		if overlapping_area == attack_hitbox_1 or overlapping_area == attack_hitbox_2 or overlapping_area == attack_hitbox_3:
			continue
		return false

	return true

func get_player_half_width() -> float:
	if player_collision_shape == null or player_collision_shape.shape == null:
		return 8.0

	if player_collision_shape.shape is CapsuleShape2D:
		return (player_collision_shape.shape as CapsuleShape2D).radius

	if player_collision_shape.shape is RectangleShape2D:
		return (player_collision_shape.shape as RectangleShape2D).size.x * 0.5

	return 8.0

func regenerate_mp(delta: float) -> void:
	if mp >= max_mp:
		return

	mp += mp_regen_per_second * delta

func player_heal() -> void:
	if not Input.is_action_just_pressed("heal"):
		return

	if mp < heal_mp_cost:
		return

	mp -= heal_mp_cost
	heal(heal_amount)

func update_attack_physics(delta: float) -> void:
	if damage_knockback_lock_remaining > 0.0:
		if not is_on_floor():
			velocity += get_gravity() * delta
		return

	var direction = Input.get_axis("left", "right")
	var is_sprinting = Input.is_action_pressed("sprint")

	if direction != 0.0:
		var move_speed = SPRINT_SPEED if is_sprinting else WALK_SPEED
		velocity.x = direction * move_speed
		lastDirection = direction

	if not is_on_floor():
		velocity += get_gravity() * delta

func player_idle(delta):
	if is_on_floor() and not is_attacking:
		currentState = State.Idle

func player_attack() -> void:
	if not Input.is_action_just_pressed("attack"):
		return

	if is_attacking or is_dashing or is_blinking:
		return
	
	
	perform_attack_combo()

func player_run(delta):
	if damage_knockback_lock_remaining > 0.0:
		return

	var direction = Input.get_axis("left", "right")
	var is_sprinting = Input.is_action_pressed("sprint")

	if direction:
		var move_speed = SPRINT_SPEED if is_sprinting else WALK_SPEED
		velocity.x = direction * move_speed
		lastDirection = direction
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
	
	if direction == 0 and is_on_floor():
		if not is_attacking:
			currentState = State.Idle
	elif is_on_floor() and not is_attacking:
		currentState = State.Run if is_sprinting else State.Walk

func player_blink() -> void:
	if not Input.is_action_just_pressed("blink"):
		return

	if is_blinking or blink_cooldown_remaining > 0.0 or damage_knockback_lock_remaining > 0.0:
		return

	if not GameManager.has_ability(AbilityData.ability_list.BLINK):
		return
		
	if mp <= 25:
		return

	mp -= 25
	cancel_attack()
	perform_blink()

func player_dash() -> void:
	if not Input.is_action_just_pressed("dash"):
		return

	if is_dashing or is_blinking or dash_cooldown_remaining > 0.0 or damage_knockback_lock_remaining > 0.0:
		return

	var input_direction := Input.get_axis("left", "right")
	if input_direction != 0.0:
		dash_direction = input_direction
	else:
		dash_direction = float(lastDirection)

	if dash_direction == 0.0:
		dash_direction = 1.0

	cancel_attack()
	lastDirection = int(signf(dash_direction))
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_remaining = dash_cooldown
	velocity = Vector2(dash_direction * dash_speed, 0.0)
	currentState = State.Dash
	set_dash_particles_active(true)

func update_dash(delta: float) -> void:
	dash_timer = maxf(dash_timer - delta, 0.0)
	velocity = Vector2(dash_direction * dash_speed, 0.0)
	currentState = State.Dash
	update_dash_particles_direction()

	if dash_timer <= 0.0:
		is_dashing = false
		velocity.x = 0.0
		set_dash_particles_active(false)
		currentState = State.Idle if is_on_floor() else State.Fall
		
func player_jump(delta):
	if damage_knockback_lock_remaining > 0.0:
		if Input.is_action_just_released("jump") and velocity.y < 0:
			velocity.y *= 0.3

		if !is_on_floor():
			if velocity.y > 0 and not is_attacking:
				currentState = State.Fall
			else:
				if isDoubleJumping and not is_attacking:
					currentState = State.DoubleJump
				elif not is_attacking:
					currentState = State.Jump
		return

	var direction = Input.get_axis("left", "right")
	
	if Input.is_action_just_pressed("jump"):
		cancel_attack()
		# Ground jump
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			if direction != 0:
				jumpDirection = direction
			else:
				jumpDirection = lastDirection
		# Double jump (only if WINGS ability is unlocked)
		elif doubleJump and GameManager.has_ability(AbilityData.ability_list.WINGS):
			velocity.y = JUMP_VELOCITY
			doubleJump = false
			isDoubleJumping = true
			if direction != 0:
				jumpDirection = direction
			else:
				jumpDirection = lastDirection
		
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.3
		
		if !is_on_floor():
			if velocity.y > 0 and not is_attacking:
				currentState = State.Fall
			else:
				if isDoubleJumping and not is_attacking:
					currentState = State.DoubleJump
				elif not is_attacking:
					currentState = State.Jump
		
	# Only update jump state if in the air
	if not is_on_floor():
		# Switch to fall animation if falling (velocity.y is positive)
		if velocity.y > 0 and not is_attacking:
			currentState = State.Fall
		else:
			# Still ascending - check if double jumping
			if isDoubleJumping and not is_attacking:
				currentState = State.DoubleJump
			elif not is_attacking:
				currentState = State.Jump

func perform_blink() -> void:
	is_blinking = true
	blink_cooldown_remaining = blink_cooldown
	velocity = Vector2.ZERO

	var blink_direction := signf(lastDirection)
	if blink_direction == 0.0:
		blink_direction = 1.0
	lastDirection = int(blink_direction)

	play_blink_animation()
	await animated_sprite_2d.animation_finished

	var safe_distance := get_safe_blink_distance(blink_direction)
	global_position.x += blink_direction * safe_distance

	play_blink_animation()
	await animated_sprite_2d.animation_finished

	is_blinking = false
	currentState = State.Idle if is_on_floor() else State.Fall

func perform_attack_combo() -> void:
	is_attacking = true
	attack_sequence_id += 1
	var sequence_id: int = attack_sequence_id

	while true:
		if not is_attacking or sequence_id != attack_sequence_id:
			break

		current_attack_index = (current_attack_index + 1) % ATTACK_ANIMATIONS.size()
		play_attack_animation(current_attack_index)
		await animated_sprite_2d.animation_finished
		if not is_attacking or sequence_id != attack_sequence_id:
			break
		disable_all_attack_hitboxes()

		if not Input.is_action_pressed("attack"):
			break

	current_attack_index = -1
	is_attacking = false
	disable_all_attack_hitboxes()
	currentState = State.Idle if is_on_floor() else State.Fall

func cancel_attack() -> void:
	if not is_attacking:
		return

	attack_sequence_id += 1
	is_attacking = false
	current_attack_index = -1
	disable_all_attack_hitboxes()

func play_attack_animation(attack_index: int) -> void:
	var animation_name: StringName = ATTACK_ANIMATIONS[attack_index]
	animated_sprite_2d.flip_h = lastDirection < 0
	update_attack_hitbox_positions()
	set_active_attack_hitbox(attack_index)
	animated_sprite_2d.stop()
	animated_sprite_2d.play(animation_name)

func play_blink_animation() -> void:
	currentState = State.Blink
	animated_sprite_2d.flip_h = lastDirection < 0
	animated_sprite_2d.stop()
	animated_sprite_2d.play("Blink")

func get_safe_blink_distance(direction: float) -> float:
	if direction == 0.0:
		return 0.0

	if not test_move(global_transform, Vector2(direction * blink_distance, 0.0)):
		return blink_distance

	var low := 0.0
	var high := blink_distance

	for _i in range(10):
		var mid := (low + high) * 0.5
		if test_move(global_transform, Vector2(direction * mid, 0.0)):
			high = mid
		else:
			low = mid

	return maxf(low - blink_wall_margin, 0.0)

func take_damage(amount: int) -> void:
	hp -= amount

func apply_knockback(knockback_velocity: Vector2) -> void:
	cancel_attack()
	is_dashing = false
	is_blinking = false
	velocity = knockback_velocity
	damage_knockback_lock_remaining = damage_knockback_lock_duration
	currentState = State.Fall

func heal(amount: int) -> void:
	hp += amount

func disable_all_attack_hitboxes() -> void:
	for shape in attack_hitbox_shapes:
		if shape != null:
			shape.disabled = true

func set_active_attack_hitbox(attack_index: int) -> void:
	disable_all_attack_hitboxes()
	if attack_index < 0 or attack_index >= attack_hitbox_shapes.size():
		return

	var active_hitbox_shape: CollisionShape2D = attack_hitbox_shapes[attack_index] as CollisionShape2D
	if active_hitbox_shape != null:
		active_hitbox_shape.disabled = false

func update_attack_hitbox_positions() -> void:
	var facing_sign: float = -1.0 if lastDirection < 0 else 1.0

	for index in range(attack_hitboxes.size()):
		var hitbox: Area2D = attack_hitboxes[index] as Area2D
		if hitbox == null:
			continue

		var base_position: Vector2 = attack_hitbox_base_positions[index]
		hitbox.position = Vector2(
			base_position.x * facing_sign,
			base_position.y
		)

		var hitbox_shape: CollisionShape2D = attack_hitbox_shapes[index] as CollisionShape2D
		if hitbox_shape == null:
			continue

		var base_shape_position: Vector2 = attack_hitbox_shape_base_positions[index]
		hitbox_shape.position = Vector2(
			base_shape_position.x * facing_sign,
			base_shape_position.y
		)

func get_attack_hitbox_shape(hitbox: Area2D) -> CollisionShape2D:
	for child in hitbox.get_children():
		if child is CollisionShape2D:
			return child as CollisionShape2D
	return null

func set_dash_particles_active(is_active: bool) -> void:
	if dash_particles == null:
		return

	update_dash_particles_direction()
	dash_particles.emitting = is_active
	if is_active:
		dash_particles.restart()

func update_dash_particles_direction() -> void:
	if dash_particles == null:
		return

	var facing_direction: float = dash_direction if is_dashing else float(lastDirection)
	if facing_direction == 0.0:
		facing_direction = 1.0

	dash_particles.position.x = 4.0 * signf(facing_direction)
	dash_particles.rotation = 0.0 if (dash_direction if is_dashing else float(lastDirection)) < 0.0 else PI
		
func player_animations():
	if is_attacking and current_attack_index >= 0 and current_attack_index < ATTACK_ANIMATIONS.size():
		animated_sprite_2d.flip_h = lastDirection < 0
		update_attack_hitbox_positions()
		if animated_sprite_2d.animation != ATTACK_ANIMATIONS[current_attack_index]:
			animated_sprite_2d.play(ATTACK_ANIMATIONS[current_attack_index])
		return

	animated_sprite_2d.flip_h = lastDirection < 0

	if currentState == State.Idle:
		animated_sprite_2d.play("Idle")
	elif currentState == State.Run:
		animated_sprite_2d.play("Run")
	elif currentState == State.Walk:
		animated_sprite_2d.play("Walk")
	elif currentState == State.Jump:
		animated_sprite_2d.play("Jump")
	elif currentState == State.DoubleJump:
		animated_sprite_2d.play("DoubleJump")
	elif currentState == State.Fall:
		animated_sprite_2d.play("Fall")
	elif currentState == State.Blink:
		animated_sprite_2d.play("Blink")
	elif currentState == State.Dash:
		animated_sprite_2d.play("Fall")
	elif currentState == State.Sit:
		animated_sprite_2d.play("Sit")
