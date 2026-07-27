extends CharacterBase
class_name MonsterBase

@onready var moving_timer = $MovingTimer

@export var knockback_strength := 180.0
@export var knockback_time := 0.12
@export var hit_flash_time := 0.08
# 索敌威胁等级：0=杂鱼 1=远程妖 2=妖王，武器优先攻击高威胁目标
@export var threat_priority: int = 0

var can_move: bool = true
var _player: Node2D = null

# Wander state
var _wander_direction := Vector2.ZERO
var _wander_timer := 0.0
@export var wander_speed_factor := 0.4

func _ready() -> void:
	super._ready()
	_player = get_node_or_null("/root/Main/Player")

func _has_target() -> bool:
	return _player != null and is_instance_valid(_player)

func _physics_process(_delta: float) -> void:
	if _has_target():
		_move(_delta)
		_attack()
	else:
		_wander(_delta)
	move_and_slide()

func _move(_delta: float) -> void:
	if not can_move:
		return
	var direction = (_player.global_position - global_position).normalized()
	velocity = direction * stats.get_move_speed()
	if velocity.length() > 0:
		animated_sprite.play("walk")
		animated_sprite.flip_h = velocity.x < 0

func _wander(delta: float) -> void:
	if not can_move:
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(1.0, 3.0)
		if randf() < 0.4:
			_wander_direction = Vector2.ZERO
		else:
			_wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	if _wander_direction == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, stats.get_move_speed() * delta * 5.0)
		animated_sprite.play("idle")
	else:
		velocity = _wander_direction * stats.get_move_speed() * wander_speed_factor
		animated_sprite.play("walk")
		animated_sprite.flip_h = velocity.x < 0

func _attack() -> void:
	pass

func take_damage(damage: int, attacker_position: Vector2, is_crit: bool = false) -> void:
	can_move = false
	var knockback_dir := (global_position - attacker_position).normalized()
	velocity = knockback_dir * (knockback_strength * (1.6 if is_crit else 1.0))
	moving_timer.start(knockback_time)
	flash_red()
	BloodBurst.spawn(get_tree().current_scene, global_position, knockback_dir, is_crit, damage)
	super.take_damage(damage, attacker_position, is_crit)

func die() -> void:
	if not GameState.game_over:
		GameState.add_kill(stats.get_loot_drop())
	Sfx.play("kill", -8.0)
	super.die()

func flash_red() -> void:
	animated_sprite.modulate = Color(1, 0.2, 0.2)
	await get_tree().create_timer(hit_flash_time).timeout
	animated_sprite.modulate = Color.WHITE

func _on_moving_timer_timeout() -> void:
	can_move = true
