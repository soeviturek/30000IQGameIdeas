extends MonsterBase

@export var projectile_scene: PackedScene
@export var attack_range: float = 300.0
@export var safe_range: float = 250.0
@export var projectile_speed: float = 200.0
@export var attack_cooldown: float = 3.6
@export var prediction_factor: float = 0.1

var can_attack: bool = true
var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	super._ready()
	stats.init_character(
		"FlyingDemon",
		110.0,          # speed（降低移速，更好拉扯）
		1,              # type = enemy
		80,             # hp
		300,            # attack range
		2,              # attack speed
		28,             # attack damage（略降 35→28，配合开火预警可反应躲避）
		20              # loot
	)
	_init_health()
	threat_priority = 1   # 远程妖：武器优先锁定，解决"够不到又抢不上目标"
	_base_scale = animated_sprite.scale

func _move(_delta: float) -> void:
	if not can_move:
		return
	if not _has_target():
		# Use base class wander when no target
		_wander(_delta)
		return
	var distance = global_position.distance_to(_player.global_position)
	var direction = (_player.global_position - global_position).normalized()
	if distance < safe_range:
		# Flee from player
		velocity = -direction * stats.get_move_speed()
		animated_sprite.play("walk")
		animated_sprite.flip_h = velocity.x > 0
	elif distance > attack_range:
		# Approach player
		velocity = direction * stats.get_move_speed()
		animated_sprite.play("walk")
		animated_sprite.flip_h = velocity.x > 0
	else:
		# In attack range — stop moving
		velocity = velocity.move_toward(Vector2.ZERO, stats.get_move_speed() * _delta * 5.0)
		animated_sprite.play("idle")
		animated_sprite.flip_h = _player.global_position.x > global_position.x

func _attack() -> void:
	if not can_attack or not _has_target():
		return
	var distance = global_position.distance_to(_player.global_position)
	if distance > attack_range:
		return
	can_attack = false
	_telegraph_then_fire()

func _telegraph_then_fire() -> void:
	# 开火预警：放大 + 闪红 0.35s，给玩家可读的躲避信号（此前无预警＝纯猜拳）
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", Color(1, 0.3, 0.3), 0.35)
	tw.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.25, 0.35)
	await tw.finished
	if not is_instance_valid(self):
		return
	animated_sprite.modulate = Color.WHITE
	animated_sprite.scale = _base_scale
	_fire_projectile()
	get_tree().create_timer(attack_cooldown).timeout.connect(func():
		if is_instance_valid(self):
			can_attack = true
	)

func _fire_projectile() -> void:
	if projectile_scene == null:
		return
	if not is_instance_valid(_player):
		return
	# Predict player position based on their velocity
	var player_velocity := Vector2.ZERO
	if _player is CharacterBody2D:
		player_velocity = _player.velocity
	var predicted_pos = _player.global_position + player_velocity * prediction_factor
	# Add small random offset for imperfection
	predicted_pos += Vector2(randf_range(-5, 5), randf_range(-5, 5))

	var direction = (predicted_pos - global_position).normalized()

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.init(direction, projectile_speed, stats.get_attack_damage())
