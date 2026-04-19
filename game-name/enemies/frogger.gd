extends EnemyBase

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	super._ready()
	damaged.connect(_on_damaged)
	died.connect(_on_died)
	if animated_sprite_2d.sprite_frames.has_animation(&"hurt"):
		animated_sprite_2d.sprite_frames.set_animation_loop(&"hurt", false)
	animated_sprite_2d.play("idle")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_dead:
		return

	if not is_on_floor():
		return

	if animated_sprite_2d.animation == &"hurt" and animated_sprite_2d.is_playing():
		return

	if animated_sprite_2d.animation != &"idle":
		animated_sprite_2d.play("idle")

func _on_damaged(_amount: int) -> void:
	if is_dead:
		return

	if animated_sprite_2d.sprite_frames.has_animation("hurt"):
		animated_sprite_2d.stop()
		animated_sprite_2d.play("hurt")

func _on_died() -> void:
	set_physics_process(false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("ContactHitbox/CollisionPolygon2D"):
		$ContactHitbox/CollisionPolygon2D.set_deferred("disabled", true)
