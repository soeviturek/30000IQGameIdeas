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
var _last_hit_was_crit := false
var _last_hit_dir := Vector2.RIGHT

# Wander state
var _wander_direction := Vector2.ZERO
var _wander_timer := 0.0
@export var wander_speed_factor := 0.4

# 难度缩放 / 狂暴
var _tier_tint: Color = Color.WHITE
var _scaled := false
var _enraged := false

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
	_last_hit_was_crit = is_crit
	_last_hit_dir = knockback_dir
	velocity = knockback_dir * (knockback_strength * (1.6 if is_crit else 1.0))
	moving_timer.start(knockback_time)
	flash_red()
	if is_crit:
		BloodBurst.spawn(get_tree().current_scene, global_position, knockback_dir, is_crit, damage)
	super.take_damage(damage, attacker_position, is_crit)
	# 小兵残血狂暴（妖王有自己的三阶段狂暴，threat 2 排除）
	if not _enraged and threat_priority < 2 and is_instance_valid(self):
		var r := _health_ratio()
		if r > 0.0 and r < 0.30:
			_enrage()

func die() -> void:
	if not GameState.game_over:
		GameState.add_kill(stats.get_loot_drop())
	Sfx.play("kill", -8.0)
	if _last_hit_was_crit:
		BloodBurst.spawn_gib(get_tree().current_scene, global_position, _last_hit_dir)
	super.die()

func flash_red() -> void:
	animated_sprite.modulate = Color(1, 0.2, 0.2)
	await get_tree().create_timer(hit_flash_time).timeout
	animated_sprite.modulate = Color.WHITE

# 按当前境界（自动基线）+ 险地（玩家选）缩放本怪，并染色分级。spawner 在 add_child 后调用。
func apply_scaling(realm: int, danger: int) -> void:
	if _scaled:
		return
	_scaled = true
	if realm > 0 or danger > 0:
		stats.add_modifier(Modifier.create(Modifier.StatType.MAX_HEALTH, Modifier.ModType.MUL, Difficulty.hp_mult(realm, danger) - 1.0))
		stats.add_modifier(Modifier.create(Modifier.StatType.ATTACK_DAMAGE, Modifier.ModType.MUL, Difficulty.dmg_mult(realm, danger) - 1.0))
		stats.add_modifier(Modifier.create(Modifier.StatType.LOOT_DROP, Modifier.ModType.MUL, Difficulty.loot_mult(realm, danger) - 1.0))
		var spd_extra := Difficulty.speed_mult(danger) - 1.0
		if spd_extra > 0.0:
			stats.add_modifier(Modifier.create(Modifier.StatType.MOVE_SPEED, Modifier.ModType.MUL, spd_extra))
		_init_health()  # 用缩放后的上限重新拉满血
	_tier_tint = Difficulty.tier_color(realm + danger)
	if animated_sprite:
		animated_sprite.self_modulate = _tier_tint

func _health_ratio() -> float:
	if health_bar == null or health_bar.max_health <= 0:
		return 1.0
	return float(health_bar.current_health) / float(health_bar.max_health)

# 小兵残血狂暴：提速、扑向玩家、颜色再红一档
func _enrage() -> void:
	_enraged = true
	stats.add_modifier(Modifier.create(Modifier.StatType.MOVE_SPEED, Modifier.ModType.MUL, 0.30))
	if animated_sprite:
		animated_sprite.self_modulate = _tier_tint.lerp(Color(0.85, 0.12, 0.12), 0.6)
	if _has_target():
		can_move = true
		velocity = (_player.global_position - global_position).normalized() * stats.get_move_speed() * 1.6

func _on_moving_timer_timeout() -> void:
	can_move = true
