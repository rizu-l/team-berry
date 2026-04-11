extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
const RunSPEED = 300.0
const SPEED = 100.0
const JUMP_VELOCITY = -400.0
var currentState
var jumpDirection = 0  # Store the jump direction
var lastDirection = 1  # Store the last facing direction (1 = right, -1 = left)
var doubleJump = true
var isDoubleJumping = false
var unlocked_abilities: Dictionary = {}
enum State { IdleLeft, IdleRight, RunLeft, RunRight, WalkLeft, WalkRight, JumpLeft, JumpRight, FallLeft, FallRight, DoubleJumpLeft, DoubleJumpRight}
func _ready():
	currentState = State.IdleLeft
	add_to_group("player")

func _physics_process(delta: float) -> void:
	player_idle(delta)
	
	# Add the gravity.
	if  !is_on_floor():
		velocity += get_gravity() * delta
	else:
		doubleJump = true
		isDoubleJumping = false
	player_jump(delta)
	player_run(delta)
	move_and_slide()
	player_animations()
func player_idle(delta):
	if is_on_floor():
		if lastDirection > 0:
			currentState = State.IdleRight
		else:
			currentState = State.IdleLeft
func player_run(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		lastDirection = direction
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	if direction == 0 && is_on_floor():
		if lastDirection > 0:
			currentState = State.IdleRight
		else:
			currentState = State.IdleLeft
	elif direction > 0 && velocity.x < 200 && is_on_floor():
		currentState = State.WalkRight
		lastDirection = 1
	elif direction < 0 && velocity.x > -200 && is_on_floor():
		currentState = State.WalkLeft
		lastDirection = -1
	elif direction > 0 && velocity.x > 200 && is_on_floor():
		currentState = State.RunRight
		lastDirection = 1
	elif direction < 0 && velocity.x < -200 && is_on_floor():
		currentState = State.RunLeft
		lastDirection = -1
		
func player_jump(delta):
	var direction = Input.get_axis("ui_left", "ui_right")
	
	if Input.is_action_just_pressed("ui_accept"):
		# Ground jump
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			if direction != 0:
				jumpDirection = direction
			else:
				jumpDirection = lastDirection
		# Double jump (only if WINGS ability is unlocked)
		elif doubleJump and unlocked_abilities.has(AbilityData.ability_list.WINGS):
			velocity.y = JUMP_VELOCITY
			doubleJump = false
			isDoubleJumping = true
			if direction != 0:
				jumpDirection = direction
			else:
				jumpDirection = lastDirection
		
	if Input.is_action_just_released("ui_accept") and velocity.y < 0:
		velocity.y *= 0.3
		
		if !is_on_floor():
			if velocity.y > 0:
				if lastDirection > 0:
					currentState = State.FallRight
				elif lastDirection < 0:
					currentState = State.FallLeft
			else:
				if isDoubleJumping:
					if jumpDirection > 0:
						currentState = State.DoubleJumpRight
					elif jumpDirection < 0:
						currentState = State.DoubleJumpLeft
				else:
					if jumpDirection > 0:
						currentState = State.JumpRight
					elif jumpDirection < 0:
						currentState = State.JumpLeft
		
	# Only update jump state if in the air
	if not is_on_floor():
		# Switch to fall animation if falling (velocity.y is positive)
		if velocity.y > 0:
			if lastDirection > 0:
				currentState = State.FallRight
			elif lastDirection < 0:
				currentState = State.FallLeft
		else:
			# Still ascending - check if double jumping
			if isDoubleJumping:
				if jumpDirection > 0:
					currentState = State.DoubleJumpRight
				elif jumpDirection < 0:
					currentState = State.DoubleJumpLeft
			else:
				if jumpDirection > 0:
					currentState = State.JumpRight
				elif jumpDirection < 0:
					currentState = State.JumpLeft
		
func player_animations():
	if currentState == State.IdleLeft:
		animated_sprite_2d.play("IdleLeft")
	elif currentState == State.IdleRight:
		animated_sprite_2d.play("IdleRight")
	elif currentState == State.RunLeft:
		animated_sprite_2d.play("RunLeft")
	elif currentState == State.RunRight:
		animated_sprite_2d.play("RunRight")
	elif currentState == State.WalkLeft:
		animated_sprite_2d.play("WalkLeft")
	elif currentState == State.WalkRight:
		animated_sprite_2d.play("WalkRight")
	elif currentState == State.JumpLeft:
		animated_sprite_2d.play("JumpLeft")
	elif currentState == State.JumpRight:
		animated_sprite_2d.play("JumpRight")
	elif currentState == State.DoubleJumpLeft:
		animated_sprite_2d.play("DoubleJumpLeft")
	elif currentState == State.DoubleJumpRight:
		animated_sprite_2d.play("DoubleJumpRight")
	elif currentState == State.FallLeft:
		animated_sprite_2d.play("FallLeft")
	elif currentState == State.FallRight:
		animated_sprite_2d.play("FallRight")
