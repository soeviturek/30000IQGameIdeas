extends MonsterBase
class_name BossMonster
# 关底妖王 · 噬魂法王：多花样弹幕战 + 场地灼烧 + 连续突进
#   招式：环形/双环封锁、扇形点名、旋转螺旋弹幕、地火危害区（逼走位）
#   连续突进：首击带蓄力预警，之后 2~3 段追身连突（每段重新锁向）
#   血量三阶段（100–50 / 50–25 / <25）逐级狂暴：更密弹幕 + 更快冷却 + 更多地火
# 复用 fire_bullet.tscn（命中 Player 自动走受击反馈）；HazardZone 地火

const BULLET := preload("res://fire_bullet.tscn")

enum BossState { IDLE, TELEGRAPH, FIRE, SPIRAL, DASH_TELEGRAPH, DASH, DASH_PAUSE, RECOVER }
enum Attack { RING, FAN, SPIRAL, HAZARD }

# 竞技场边界（地火落点 clamp，略内缩于墙体 1120/600）
const ARENA_X := 1080.0
const ARENA_Y := 560.0
const HAZARD_SPREAD := 380.0   # 地火围绕玩家散布半径

# —— 节奏时长（秒） ——
const TELEGRAPH_TIME := 0.42
const FIRE_TIME := 0.3
const SPIRAL_TIME := 1.25
const DASH_TELEGRAPH_TIME := 0.85   # 连段首击蓄力预警（红色冲击走廊显形 ~1s）
const DASH_TIME := 0.53             # 走廊长度 ÷ 冲刺速度（冲满整条走廊）
const DASH_PAUSE_TIME := 0.55       # 连段间隙（重新锁向 + 重划走廊）
const RECOVER_TIME := 0.5           # 连段收招硬直（玩家输出窗口）

# —— 冲刺（红色走廊预警 → 高速冲过，接触即伤） ——
const DASH_SPEED := 1050.0
const DASH_DAMAGE := 42
const DASH_HIT_RANGE := 72.0        # 接触判定半径（约走廊半宽 + 余量）
const DASH_PREDICT := 0.12
const DASH_RANGE := 560.0           # 冲刺走廊长度（预警区）
const DASH_WIDTH := 104.0           # 冲刺走廊宽度（显示与判定参照）

# —— 弹幕（更密更快） ——
const RING_COUNT := 16
const RING_SPEED := 255.0
const FAN_COUNT := 7
const FAN_SPREAD_DEG := 60.0
const FAN_SPEED := 360.0
const SPIRAL_SPEED := 205.0
const SPIRAL_EMIT := 0.05           # 螺旋每股发射间隔（更密）
const SPIRAL_ARMS := 3
const SPIRAL_STEP := 0.30           # 每股旋转步进（弧度）
const BULLET_DAMAGE := 16

# —— 地火 ——
const HAZARD_RADIUS := 86.0
const HAZARD_DAMAGE := 16

@export var attack_interval := 1.2   # 近身接触攻击间隔（秒）

var can_attack: bool = true
var _state: int = BossState.IDLE
var _state_timer: float = 0.0
var _pattern_cd: float = 0.8         # 首个招式 ~0.8s（开局即压迫）
var _dash_cd: float = 4.5            # 首次连突 ~4.5s
var _dash_dir: Vector2 = Vector2.ZERO
var _dash_hit_done: bool = false
var _dashes_left: int = 0
var _pending_attack: int = Attack.RING
var _last_attack: int = -1
var _base_scale: Vector2 = Vector2.ONE
var _phase: int = 1                   # 1/2/3 随血量升级
# 螺旋运行态
var _spiral_angle: float = 0.0
var _spiral_emit: float = 0.0

func _ready() -> void:
	super._ready()
	stats.init_character(
		"噬魂法王",   # 名字
		112.0,        # 移速（提高压迫）
		1,            # 类型：妖
		4500,         # 气血（关底血量 ×3 强化）
		130,          # 近身攻击范围
		1.2,          # 攻击冷却
		28,           # 接触伤害
		0             # 掉落（结算另算灵石）
	)
	_init_health()
	knockback_strength = 55.0   # 妖王更抗击退
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
	_update_phase()

	match _state:
		BossState.IDLE:
			_tick_idle()
		BossState.TELEGRAPH:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			if _state_timer <= 0.0:
				_dispatch_attack()
		BossState.FIRE:
			velocity = Vector2.ZERO
			if _state_timer <= 0.0:
				_end_pattern()
		BossState.SPIRAL:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			_tick_spiral(delta)
			if _state_timer <= 0.0:
				_end_pattern()
		BossState.DASH_TELEGRAPH:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			if _state_timer <= 0.0:
				_begin_dash()
		BossState.DASH:
			velocity = _dash_dir * DASH_SPEED
			animated_sprite.play("walk")
			animated_sprite.flip_h = _dash_dir.x < 0
			_try_dash_hit()
			if _state_timer <= 0.0:
				_dashes_left -= 1
				if _dashes_left > 0:
					_enter_dash_pause()
				else:
					_state = BossState.RECOVER
					_state_timer = RECOVER_TIME
		BossState.DASH_PAUSE:
			velocity = Vector2.ZERO
			animated_sprite.play("idle")
			if _state_timer <= 0.0:
				_begin_dash()
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
		_enter_dash_combo()
	elif _pattern_cd <= 0.0:
		_enter_telegraph()

# —— 起手预警（挑一招） ——
func _enter_telegraph() -> void:
	_pending_attack = _pick_attack()
	_state = BossState.TELEGRAPH
	_state_timer = TELEGRAPH_TIME
	_face_player()
	var col := Color(1, 0.4, 0.4)
	if _pending_attack == Attack.HAZARD:
		col = Color(1, 0.55, 0.2)   # 地火橙警
		_spawn_hazards()            # 预警圈随起手落地（自带 warn 阶段）
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", col, TELEGRAPH_TIME)
	tw.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.16, TELEGRAPH_TIME)

func _dispatch_attack() -> void:
	animated_sprite.modulate = Color.WHITE
	animated_sprite.scale = _base_scale
	match _pending_attack:
		Attack.RING:
			_fire_ring()
			_after_instant()
		Attack.FAN:
			_fire_fan()
			_after_instant()
		Attack.HAZARD:
			_after_instant()   # 地火已在预警阶段生成
		Attack.SPIRAL:
			_spiral_angle = randf() * TAU
			_spiral_emit = 0.0
			Sfx.play("boss", -6.0)
			_state = BossState.SPIRAL
			_state_timer = SPIRAL_TIME

func _after_instant() -> void:
	Sfx.play("boss", -6.0)
	GameState.shake(0.12, 4.0)
	_state = BossState.FIRE
	_state_timer = FIRE_TIME

func _end_pattern() -> void:
	_state = BossState.IDLE
	_pattern_cd = _pattern_cooldown()

# 招式池随阶段扩充，避免连续重复
func _pick_attack() -> int:
	var pool := [Attack.RING, Attack.FAN, Attack.HAZARD]
	if _phase >= 2:
		pool.append(Attack.SPIRAL)
		pool.append(Attack.FAN)      # 提高点名频率
	if _phase >= 3:
		pool.append(Attack.SPIRAL)   # 螺旋权重更高
		pool.append(Attack.HAZARD)
	var pick: int = pool[randi() % pool.size()]
	if pick == _last_attack and pool.size() > 1:
		pick = pool[randi() % pool.size()]
	_last_attack = pick
	return pick

# —— 弹幕招式 ——
func _fire_ring() -> void:
	var speed := RING_SPEED * _bullet_speed_mult()
	var offset := randf_range(0.0, TAU / float(RING_COUNT))   # 每次微旋，死角不固定
	for i in RING_COUNT:
		var ang := offset + TAU * float(i) / float(RING_COUNT)
		_spawn_bullet(Vector2.RIGHT.rotated(ang), speed)
	# 阶段3：叠加反向偏移的第二环（双环封锁）
	if _phase >= 3:
		var off2 := offset + PI / float(RING_COUNT)
		for i in RING_COUNT:
			var a2 := off2 + TAU * float(i) / float(RING_COUNT)
			_spawn_bullet(Vector2.RIGHT.rotated(a2), speed * 0.82)

func _fire_fan() -> void:
	if not is_instance_valid(_player):
		return
	var speed := FAN_SPEED * _bullet_speed_mult()
	var count := FAN_COUNT + (2 if _phase >= 2 else 0)
	var spread := deg_to_rad(FAN_SPREAD_DEG + (18.0 if _phase >= 2 else 0.0))
	var base := (_player.global_position - global_position).angle()
	for i in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		_spawn_bullet(Vector2.RIGHT.rotated(base + t * spread), speed)

func _tick_spiral(delta: float) -> void:
	_spiral_emit -= delta
	if _spiral_emit > 0.0:
		return
	_spiral_emit = SPIRAL_EMIT
	var speed := SPIRAL_SPEED * _bullet_speed_mult()
	for arm in SPIRAL_ARMS:
		var a := _spiral_angle + TAU * float(arm) / float(SPIRAL_ARMS)
		_spawn_bullet(Vector2.RIGHT.rotated(a), speed)
	_spiral_angle += SPIRAL_STEP

func _spawn_bullet(dir: Vector2, speed: float) -> void:
	var b := BULLET.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = global_position
	b.init(dir, speed, BULLET_DAMAGE)

# —— 地火危害区 ——
func _spawn_hazards() -> void:
	var n := 3
	if _phase >= 2:
		n = 4
	if _phase >= 3:
		n = 5
	var base: Vector2 = _player.global_position if is_instance_valid(_player) else global_position
	for i in n:
		var pos: Vector2
		if i == 0 and is_instance_valid(_player):
			# 第一枚砸向玩家预测落点（惩罚站桩）
			pos = _player.global_position
			if _player is CharacterBody2D:
				pos += _player.velocity * 0.25
		else:
			# 其余围绕玩家散布（大地图下才追得到人）
			pos = base + Vector2(randf_range(-HAZARD_SPREAD, HAZARD_SPREAD), randf_range(-HAZARD_SPREAD, HAZARD_SPREAD))
		pos.x = clampf(pos.x, -ARENA_X, ARENA_X)
		pos.y = clampf(pos.y, -ARENA_Y, ARENA_Y)
		var h := HazardZone.new()
		get_tree().current_scene.add_child(h)
		h.setup(pos, HAZARD_RADIUS, HAZARD_DAMAGE)
	Sfx.play("boss", -8.0)
	GameState.shake(0.1, 3.0)

# —— 连续突进 ——
func _enter_dash_combo() -> void:
	_dashes_left = 3 if _phase >= 2 else 2
	_state = BossState.DASH_TELEGRAPH
	_state_timer = DASH_TELEGRAPH_TIME
	_relock_dash()
	_spawn_dash_warning(DASH_TELEGRAPH_TIME)
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", Color(1, 0.55, 0.2), DASH_TELEGRAPH_TIME)
	tw.parallel().tween_property(animated_sprite, "scale", _base_scale * 1.22, DASH_TELEGRAPH_TIME)
	Sfx.play("boss", -10.0)

func _enter_dash_pause() -> void:
	_state = BossState.DASH_PAUSE
	_state_timer = DASH_PAUSE_TIME
	_relock_dash()   # 连段追身：重新锁向玩家
	_spawn_dash_warning(DASH_PAUSE_TIME)
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", Color(1, 0.55, 0.2), DASH_PAUSE_TIME * 0.8)

func _relock_dash() -> void:
	var target := global_position + Vector2.RIGHT
	if is_instance_valid(_player):
		target = _player.global_position
		if _player is CharacterBody2D:
			target += _player.velocity * DASH_PREDICT
	_dash_dir = (target - global_position).normalized()
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2.RIGHT
	animated_sprite.flip_h = _dash_dir.x < 0

func _spawn_dash_warning(warn: float) -> void:
	# 沿锁定方向铺一条红色冲击走廊，蓄力期显形，冲刺瞬间随之消散
	var w := DashWarning.new()
	get_tree().current_scene.add_child(w)
	w.setup(global_position, _dash_dir, DASH_RANGE, DASH_WIDTH, warn)

func _begin_dash() -> void:
	animated_sprite.modulate = Color.WHITE
	animated_sprite.scale = _base_scale
	_state = BossState.DASH
	_state_timer = DASH_TIME
	_dash_hit_done = false
	GameState.shake(0.08, 4.0)
	Sfx.play("dash", -3.0)

func _try_dash_hit() -> void:
	if _dash_hit_done or not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) <= DASH_HIT_RANGE:
		_dash_hit_done = true
		if _player.has_method("take_damage"):
			_player.take_damage(DASH_DAMAGE, global_position)
		GameState.shake(0.16, 6.0)
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

# —— 血量阶段 ——
func _hp_ratio() -> float:
	if health_bar and health_bar.max_health > 0:
		return float(health_bar.current_health) / float(health_bar.max_health)
	return 1.0

func _update_phase() -> void:
	var r := _hp_ratio()
	var target := 1
	if r <= 0.25:
		target = 3
	elif r <= 0.5:
		target = 2
	if target > _phase:
		_phase = target
		# 狂暴阶段不再弹横幅（与"妖王降临"雷同、重复、多余）：只用震屏反馈
		if _phase == 2:
			GameState.shake(0.22, 6.0)
		elif _phase == 3:
			GameState.shake(0.4, 10.0)

func _pattern_cooldown() -> float:
	# 弹幕招式冷却减半 → 攻击频率翻倍
	if _phase >= 3:
		return 0.7
	elif _phase >= 2:
		return 1.05
	return 1.5

func _dash_cooldown() -> float:
	if _phase >= 3:
		return 4.5
	elif _phase >= 2:
		return 6.0
	return 8.5

func _bullet_speed_mult() -> float:
	if _phase >= 3:
		return 1.25
	elif _phase >= 2:
		return 1.12
	return 1.0

func die() -> void:
	# 妖王陨落 = 通关：只记一次击杀 + 少量经验，随后进入通关结算
	if not GameState.game_over and not GameState.victory:
		GameState.add_kill(30)
		GameState.win_stage()
	queue_free()
