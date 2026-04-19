extends CharacterBody2D
class_name EnemyBase

signal health_changed(current_hp: int, max_hp: int)
signal died
signal damaged(amount: int)
signal contact_damage_applied(target: Node, damage: int)
signal hit_by_player_attack(attacker: Node, damage: int)

@export var enemy_name: String = "Enemy"
@export var is_boss: bool = false
@export var max_hp: int = 100
@export var starting_hp: int = 100
@export var contact_damage: int = 10
@export var attack_power: int = 10
@export var move_speed: float = 100.0
@export var gravity_scale: float = 1.0
@export var contact_knockback: Vector2 = Vector2(260.0, -220.0)
@export var contact_damage_cooldown: float = 0.4
@export_flags_2d_physics var body_collision_layer: int = 4
@export_flags_2d_physics var body_collision_mask: int = 1
@export_flags_2d_physics var contact_hitbox_collision_layer: int = 32
@export_flags_2d_physics var contact_hitbox_collision_mask: int = 22

var hp: int = 0
var is_dead: bool = false
var contact_damage_cooldowns: Dictionary = {}
var active_attack_hitboxes: Dictionary = {}
var overlapping_player_bodies: Dictionary = {}

@onready var contact_hitbox: Area2D = get_node_or_null("ContactHitbox") as Area2D

func _enter_tree() -> void:
	collision_layer = body_collision_layer
	collision_mask = body_collision_mask

func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		add_to_group("bosses")
	hp = clampi(starting_hp, 0, max_hp)
	health_changed.emit(hp, max_hp)
	if contact_hitbox != null:
		contact_hitbox.collision_layer = contact_hitbox_collision_layer
		contact_hitbox.collision_mask = contact_hitbox_collision_mask
		contact_hitbox.monitoring = true
		contact_hitbox.monitorable = true
		contact_hitbox.body_entered.connect(_on_contact_hitbox_body_entered)
		contact_hitbox.body_exited.connect(_on_contact_hitbox_body_exited)
		contact_hitbox.area_entered.connect(_on_contact_hitbox_area_entered)
		contact_hitbox.area_exited.connect(_on_contact_hitbox_area_exited)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	update_contact_damage_cooldowns(delta)
	update_overlapping_contact_damage()
	update_overlapping_attack_hitboxes()
	apply_gravity(delta)
	move_and_slide()

func take_damage(amount: int) -> void:
	if is_dead:
		return

	var applied_damage: int = max(amount, 0)
	if applied_damage == 0:
		return

	hp = max(hp - applied_damage, 0)
	damaged.emit(applied_damage)
	health_changed.emit(hp, max_hp)

	if hp == 0:
		die()

func heal(amount: int) -> void:
	if is_dead:
		return

	hp = clampi(hp + max(amount, 0), 0, max_hp)
	health_changed.emit(hp, max_hp)

func die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit()

func apply_gravity(delta: float) -> void:
	if is_on_floor():
		return

	velocity += get_gravity() * gravity_scale * delta

func update_contact_damage_cooldowns(delta: float) -> void:
	var expired_instance_ids: Array[int] = []

	for instance_id_variant in contact_damage_cooldowns.keys():
		var instance_id: int = int(instance_id_variant)
		var remaining_cooldown: float = float(contact_damage_cooldowns[instance_id]) - delta
		if remaining_cooldown <= 0.0:
			expired_instance_ids.append(instance_id)
		else:
			contact_damage_cooldowns[instance_id] = remaining_cooldown

	for instance_id in expired_instance_ids:
		contact_damage_cooldowns.erase(instance_id)

func _on_contact_hitbox_body_entered(body: Node) -> void:
	if is_dead:
		return
	if contact_hitbox == null:
		return
	if not body.is_in_group("player"):
		return

	var body_instance_id: int = body.get_instance_id()
	overlapping_player_bodies[body_instance_id] = body
	if contact_damage_cooldowns.has(body_instance_id):
		return

	apply_contact_damage_to_body(body)

func _on_contact_hitbox_body_exited(body: Node) -> void:
	var body_instance_id: int = body.get_instance_id()
	if overlapping_player_bodies.has(body_instance_id):
		overlapping_player_bodies.erase(body_instance_id)
	if contact_damage_cooldowns.has(body_instance_id):
		contact_damage_cooldowns.erase(body_instance_id)

func _on_contact_hitbox_area_entered(area: Area2D) -> void:
	if is_dead:
		return
	if not area.is_in_group("player_attack_hitboxes"):
		return

	var attack_hitbox_instance_id: int = area.get_instance_id()
	if active_attack_hitboxes.has(attack_hitbox_instance_id):
		return

	active_attack_hitboxes[attack_hitbox_instance_id] = true
	apply_player_attack_damage(area)

func _on_contact_hitbox_area_exited(area: Area2D) -> void:
	var attack_hitbox_instance_id: int = area.get_instance_id()
	if active_attack_hitboxes.has(attack_hitbox_instance_id):
		active_attack_hitboxes.erase(attack_hitbox_instance_id)

func apply_contact_damage(target: Node) -> void:
	if contact_damage <= 0:
		return
	if not target.has_method("take_damage"):
		return

	target.call("take_damage", contact_damage)
	var knockback_direction_x: float = signf(target.global_position.x - global_position.x)
	if knockback_direction_x == 0.0:
		knockback_direction_x = -1.0 if scale.x < 0.0 else 1.0

	var applied_knockback: Vector2 = Vector2(contact_knockback.x * knockback_direction_x, contact_knockback.y)
	if target.has_method("apply_knockback"):
		target.call("apply_knockback", applied_knockback)

	contact_damage_applied.emit(target, contact_damage)

func apply_contact_damage_to_body(target: Node) -> void:
	var body_instance_id: int = target.get_instance_id()
	contact_damage_cooldowns[body_instance_id] = contact_damage_cooldown
	apply_contact_damage(target)

func update_overlapping_contact_damage() -> void:
	if overlapping_player_bodies.is_empty():
		return

	var stale_instance_ids: Array[int] = []

	for body_instance_id_variant in overlapping_player_bodies.keys():
		var body_instance_id: int = int(body_instance_id_variant)
		var target: Node = overlapping_player_bodies[body_instance_id] as Node
		if target == null or not is_instance_valid(target):
			stale_instance_ids.append(body_instance_id)
			continue
		if contact_damage_cooldowns.has(body_instance_id):
			continue

		apply_contact_damage_to_body(target)

	for body_instance_id in stale_instance_ids:
		overlapping_player_bodies.erase(body_instance_id)

func update_overlapping_attack_hitboxes() -> void:
	if contact_hitbox == null:
		return

	var overlapping_areas: Array = contact_hitbox.get_overlapping_areas()
	var still_overlapping_hitbox_ids: Dictionary = {}

	for area_variant in overlapping_areas:
		var area: Area2D = area_variant as Area2D
		if area == null:
			continue
		if not area.is_in_group("player_attack_hitboxes"):
			continue

		var attack_hitbox_instance_id: int = area.get_instance_id()
		still_overlapping_hitbox_ids[attack_hitbox_instance_id] = true

		if active_attack_hitboxes.has(attack_hitbox_instance_id):
			continue

		active_attack_hitboxes[attack_hitbox_instance_id] = true
		apply_player_attack_damage(area)

	var stale_attack_hitbox_ids: Array[int] = []

	for attack_hitbox_instance_id_variant in active_attack_hitboxes.keys():
		var attack_hitbox_instance_id: int = int(attack_hitbox_instance_id_variant)
		if still_overlapping_hitbox_ids.has(attack_hitbox_instance_id):
			continue
		stale_attack_hitbox_ids.append(attack_hitbox_instance_id)

	for attack_hitbox_instance_id in stale_attack_hitbox_ids:
		active_attack_hitboxes.erase(attack_hitbox_instance_id)

func apply_player_attack_damage(attack_hitbox: Area2D) -> void:
	var attacker: Node = attack_hitbox.get_parent()
	if attacker == null:
		return
	if not attacker.is_in_group("player"):
		return
	if not attacker.has_method("get_attack_power"):
		return

	var attack_damage: int = int(attacker.call("get_attack_power"))
	if attack_damage <= 0:
		return

	take_damage(attack_damage)
	hit_by_player_attack.emit(attacker, attack_damage)
