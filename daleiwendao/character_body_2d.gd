extends CharacterBase

@onready var weapon1 = $Weapon1
@onready var slash_weapon = $SlashWeapon

const DASH_SPEED_MULT := 3.0
const DASH_TIME := 0.15
const DASH_CD := 1.6
const IFRAME_TIME := 0.4
const KNOCKBACK_STRENGTH := 260.0
const KNOCKBACK_DECAY := 1400.0

var _iframe_left := 0.0        # >0 即无敌（受击 / 冲刺共用，单一来源避免多 timer 竞争）
var _knockback := Vector2.ZERO
var _dash_time_left := 0.0
var _dash_cd_left := 0.0
var _dash_dir := Vector2.RIGHT
var _facing := 1.0

func _ready() -> void:
	super._ready()
	stats.init_character(
		"大雷弟子",
		340.0,   # 移速
		0,       # 类型：玩家
		300,     # 气血
		0,       # 攻击范围加成（武器自带范围）
		1,       # 攻击速度
		8,       # 攻击力加成
		0        # 掉落
	)
	_init_health()
	stats.critChance = 0.10
	stats.critMultiplier = 2.0
	_apply_meta()
	weapon1.init_weapon(stats)
	slash_weapon.init_weapon(stats)
	_apply_meta_qi()

# 洞府永久强化：气血/攻击/移速/暴击叠加，并按新上限刷新血条
func _apply_meta() -> void:
	if not has_node("/root/Meta"):
		return
	get_node("/root/Meta").apply_to_stats(stats)
	health_bar.set_max_health(stats.get_max_health())
	health_bar.set_health(stats.get_max_health())

# 剑胎：出关起手即带若干层惊鸿剑气
func _apply_meta_qi() -> void:
	if not has_node("/root/Meta"):
		return
	var n := int(get_node("/root/Meta").starting_qi())
	for i in n:
		if slash_weapon and slash_weapon.has_method("add_qi_level"):
			slash_weapon.add_qi_level()

func _physics_process(delta: float) -> void:
	if _iframe_left > 0.0:
		_iframe_left -= delta
	if _dash_cd_left > 0.0:
		_dash_cd_left -= delta

	# 冲刺进行中：高速位移，无视输入与击退
	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity = _dash_dir * stats.get_move_speed() * DASH_SPEED_MULT
		animated_sprite.play("walk")
		move_and_slide()
		return

	var direction := Input.get_axis("ui_left", "ui_right")
	var updown := Input.get_axis("ui_up", "ui_down")
	var speed = stats.get_move_speed()
	if direction != 0.0:
		_facing = signf(direction)

	# 冲刺起步（Space）
	if Input.is_action_just_pressed("dash") and _dash_cd_left <= 0.0:
		_start_dash(Vector2(direction, updown))
		return

	if direction or updown:
		velocity.x = direction * speed
		velocity.y = updown * speed
		animated_sprite.play("walk")
		animated_sprite.flip_h = direction > 0
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.y = move_toward(velocity.y, 0, speed)
		animated_sprite.play("idle")

	# 受击击退：单独存向量叠加，逐帧衰减（否则被移动输入冲掉）
	if _knockback.length() > 1.0:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	move_and_slide()

func _start_dash(input_vec: Vector2) -> void:
	if input_vec.length() > 0.01:
		_dash_dir = input_vec.normalized()
	else:
		_dash_dir = Vector2(_facing, 0.0)
	_dash_time_left = DASH_TIME
	_dash_cd_left = DASH_CD
	_iframe_left = max(_iframe_left, DASH_TIME + 0.05)
	_knockback = Vector2.ZERO
	GameState.shake(0.1, 3.0)
	Sfx.play("dash")

func take_damage(damage: int, attacker_position: Vector2, is_crit: bool = false) -> void:
	if _iframe_left > 0.0:
		return
	# 受击闪红 → 0.15s tween 回白
	animated_sprite.modulate = Color(1, 0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)
	# 无敌帧
	_iframe_left = IFRAME_TIME
	# 击退（远离攻击者）
	var dir := (global_position - attacker_position)
	if dir.length() > 0.01:
		_knockback = dir.normalized() * KNOCKBACK_STRENGTH
	# 震屏 + 音效
	GameState.shake(0.18, 7.0)
	Sfx.play("hurt")
	super.take_damage(damage, attacker_position, is_crit)

func die() -> void:
	GameState.game_over = true
	Sfx.play("defeat")
	super.die()
