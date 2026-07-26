extends MonsterBase
class_name BossMonster
# 关底妖王 · 噬魂法王：大血量近战，击败即通关

var can_attack: bool = true
@export var attack_interval := 1.3   # 妖王攻击间隔（秒）。独立字段，避免复用 attackSpeed 语义混淆

func _ready() -> void:
	super._ready()
	stats.init_character(
		"噬魂法王",   # 名字
		95.0,         # 移速（缓慢逼近）
		1,            # 类型：妖
		1400,         # 气血（关底血量，可调）
		130,          # 攻击范围（大体型近战）
		1.3,          # 攻击冷却
		28,           # 接触伤害
		0             # 掉落（结算另算灵石）
	)
	_init_health()
	# 妖王更抗击退
	knockback_strength = 60.0
	threat_priority = 2   # 妖王：最高索敌优先级

func _attack() -> void:
	if _player == null or not can_attack:
		return
	var distance = global_position.distance_to(_player.global_position)
	if distance <= stats.get_attack_range():
		if _player.has_method("take_damage"):
			_player.take_damage(stats.get_attack_damage(), global_position)
			can_attack = false
			get_tree().create_timer(attack_interval).timeout.connect(func(): can_attack = true)

func die() -> void:
	# 妖王陨落 = 通关：只记一次击杀 + 少量经验，随后进入通关结算
	if not GameState.game_over and not GameState.victory:
		GameState.add_kill(30)
		GameState.win_stage()
	queue_free()
