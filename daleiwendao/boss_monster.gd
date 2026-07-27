extends MonsterBase
class_name BossMonster
# 关底妖王 · 噬魂法王：状态机弹幕战
#   IDLE 缓慢逼近 + 近身接触伤害
#   环形弹幕（360° 12 发）/ 扇形点名（朝玩家 5 发）轮换，均带 0.45s 预警
#   冲刺突进：蓄力锁向 0.5s → 突进 0.28s（命中重伤）→ 硬直 0.6s（输出窗口）
#   血量阶段：≤50% 出招/冲刺提速 + 弹速 +15% + 暴怒横幅
# 复用已验证的 fire_bullet.tscn（FireBullet.init(dir, speed, dmg)，命中 Player 组自动走受击反馈）

const BULLET := preload("res://fire_bullet.tscn")

enum BossState { IDLE, TELEGRAPH, FIRE, DASH_TELEGRAPH, DASH, RECOVER }

# —— 节奏时长（秒） ——
const TELEGRAPH_TIME := 0.45      # 弹幕预警
const FIRE_TIME := 0.35           # 出招后短硬直（弹幕出膛可读）
const DASH_TELEGRAPH_TIME := 0.5  # 冲刺蓄力（玩家走位躲避窗口）
const DASH_TIME := 0.28           # 突进
const RECOVER_TIME := 0.6         # 冲刺后硬直（玩家输出窗口）

# —— 冲刺参数 ——
const DASH_SPEED := 340.0
const DASH_DAMAGE := 45
const DASH_HIT_RANGE := 74.0
const DASH_PREDICT := 0.13        # 蓄力锁向的轻预判系数

# —— 弹幕参数 ——
const RING_COUNT := 12
const RING_SPEED := 190.0
const FAN_COUNT := 5
const FAN_SPREAD_DEG := 62.0
const FAN_SPEED := 280.0
const BULLET_DAMAGE := 18

@export var attack_interval := 1.3   # 近身接触攻击间隔（秒）

var can_attack: bool = true          # 近身接触攻击冷却
var _state: int = BossState.IDLE
var _state_timer: float = 0.0
var _pattern_cd: float = 2.0         # 距下次弹幕（首发 ~2s）
var _dash_cd: float = 6.0            # 距下次冲刺（首冲 ~6s）
var _dash_dir: Vector2 = Vector2.ZERO
var _dash_hit_done: bool = false
var _pattern_index: int = 0          # 环形 / 扇形轮换
var _base_scale: Vector2 = Vector2.ONE
var _enraged: bool = false           # ≤50% 暴怒横幅只播一次

func _ready() -> void:
	super._ready()
	stats.init_character(
		"噬魂法王",   # 名字
		95.0,         # 移速（缓慢逼近）
		1,            # 类型：妖
		1400,         # 气血（关底血量）
		130,          # 近身攻击范围
		1.3,          # 攻击冷却
		28,           # 接触伤害
		0             # 掉落（结算另算灵石）
	)
	_init_health()
	knockback_strength = 60.0   # 妖王更抗击退
	threat_priority = 2         # 最高索敌优先级
	_base_scale = animated_sprite.scale

# 完整接管物理帧：用状态机替代 MonsterBase 的 _move/_attack 直驱
func _physics_process(delta: float) -> void:
	if not _has_target():
		velocity = Vector2.ZERO
		animated_sprite.play("idle")
		move_and_slide()
		return

	_pattern_cd -= delta
	_dash_cd -= delta
	_state_timer -= delta
	_check_enrage()

	match _state:
		BossState.IDLE:
			_tick_idle()
		BossState.TELEGRAPH:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			if _state_timer <= 0.0:
				_do_fire()
		BossState.FIRE:
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_state = BossState.IDLE
				_pattern_cd = _pattern_cooldown()
		BossState.DASH_TELEGRAPH:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			if _state_timer <= 0.0:
				animated_sprite.modulate = Color.WHITE
				animated_sprite.scale = _base_scale
				_state = BossState.DASH
				_state_timer = DASH_TIME
				_dash_hit_done = false
		BossState.DASH:
			velocity = _dash_dir * DASH_SPEED
			animated_sprite.play("walk")
			animated_sprite.flip_h = _dash_dir.x < 0
			_try_dash_hit()
			if _state_timer <= 0.0:
				_state = BossState.RECOVER
				_state_timer = RECOVER_TIME
		BossState.RECOVER:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			if _state_timer <= 0.0:
				_state = BossState.IDLE
				_dash_cd = _dash_cooldown()

	move_and_slide()

# —— IDLE：逼近 + 近身接触 + 起手判定（冲刺优先于弹幕，互斥） ——
func _tick_idle() -> void:
	if can_move:
		var dir := (_player.global_position - global_position).normalized()
		velocity = dir * stats.get_move_speed()
		animated_sprite.play("walk")
		animated_sprite.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
	_try_contact_attack()
	if _dash_cd <= 0.0:
		_enter_dash_telegraph()
	elif _pattern_cd <= 0.0:
		_enter_telegraph()

# —— 弹幕预警 ——
func _enter_telegraph() -> void:
	_state = BossState.TELEGRAPH
	_state_timer = TELEGRAPH_TIME
	_face_player()
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", Color(1, 0.4, 0.4), TELEGRAPH_TIME)
	tw.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.16, TELEGRAPH_TIME)

func _do_fire() -> void:
	animated_sprite.modulate = Color.WHITE
	animated_sprite.scale = _base_scale
	# 招式轮换：偶数环形封锁，奇数扇形点名
	if _pattern_index % 2 == 0:
		_fire_ring()
	else:
		_fire_fan()
	_pattern_index += 1
	Sfx.play("boss", -6.0)
	GameState.shake(0.12, 4.0)
	_state = BossState.FIRE
	_state_timer = FIRE_TIME

func _fire_ring() -> void:
	var speed := RING_SPEED * _bullet_speed_mult()
	var offset := randf_range(0.0, TAU / float(RING_COUNT))   # 每次微旋，死角不固定
	for i in RING_COUNT:
		var ang := offset + TAU * float(i) / float(RING_COUNT)
		_spawn_bullet(Vector2.RIGHT.rotated(ang), speed)

func _fire_fan() -> void:
	if not is_instance_valid(_player):
		return
	var speed := FAN_SPEED * _bullet_speed_mult()
	var base := (_player.global_position - global_position).angle()
	var spread := deg_to_rad(FAN_SPREAD_DEG)
	for i in FAN_COUNT:
		var t := 0.0 if FAN_COUNT == 1 else float(i) / float(FAN_COUNT - 1) - 0.5
		var ang := base + t * spread
		_spawn_bullet(Vector2.RIGHT.rotated(ang), speed)

func _spawn_bullet(dir: Vector2, speed: float) -> void:
	var b := BULLET.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position
	b.init(dir, speed, BULLET_DAMAGE)

# —— 冲刺突进 ——
func _enter_dash_telegraph() -> void:
	_state = BossState.DASH_TELEGRAPH
	_state_timer = DASH_TELEGRAPH_TIME
	# 蓄力即锁向（含轻预判）；玩家可在蓄力窗口内走位闪开
	var target := _player.global_position
	if _player is CharacterBody2D:
		target += _player.velocity * DASH_PREDICT
	_dash_dir = (target - global_position).normalized()
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2.RIGHT
	animated_sprite.flip_h = _dash_dir.x < 0
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", Color(1, 0.55, 0.2), DASH_TELEGRAPH_TIME)
	tw.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.22, DASH_TELEGRAPH_TIME)
	Sfx.play("boss", -10.0)

func _try_dash_hit() -> void:
	if _dash_hit_done or not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) <= DASH_HIT_RANGE:
		_dash_hit_done = true
		if _player.has_method("take_damage"):
			_player.take_damage(DASH_DAMAGE, global_position)
		GameState.shake(0.18, 7.0)
		Sfx.play("boss", -4.0)

# —— 近身接触伤害（facehug 惩罚，非主要威胁） ——
func _try_contact_attack() -> void:
	if not can_attack or not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) <= stats.get_attack_range():
		if _player.has_method("take_damage"):
			_player.take_damage(stats.get_attack_damage(), global_position)
			can_attack = false
			get_tree().create_timer(attack_interval).timeout.connect(func():
				if is_instance_valid(self):
					can_attack = true)

func _face_player() -> void:
	if is_instance_valid(_player):
		animated_sprite.flip_h = _player.global_position.x < global_position.x

# —— 血量阶段（P1） ——
func _hp_ratio() -> float:
	if health_bar and health_bar.max_health > 0:
		return float(health_bar.current_health) / float(health_bar.max_health)
	return 1.0

func _pattern_cooldown() -> float:
	return 2.4 if _hp_ratio() <= 0.5 else 3.4

func _dash_cooldown() -> float:
	return 7.0 if _hp_ratio() <= 0.5 else 10.0

func _bullet_speed_mult() -> float:
	return 1.15 if _hp_ratio() <= 0.5 else 1.0

func _check_enrage() -> void:
	if _enraged:
		return
	if _hp_ratio() <= 0.5:
		_enraged = true
		_announce("妖王暴怒 · 噬魂法王", Color(1, 0.4, 0.35))

func _announce(text: String, color: Color) -> void:
	var dir = get_tree().current_scene.get_node_or_null("MosnterSpawningPoint")
	if dir and dir.has_signal("announce"):
		dir.announce.emit(text, color)

func die() -> void:
	# 妖王陨落 = 通关：只记一次击杀 + 少量经验，随后进入通关结算
	if not GameState.game_over and not GameState.victory:
		GameState.add_kill(30)
		GameState.win_stage()
	queue_free()
