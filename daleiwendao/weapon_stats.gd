extends Resource
class_name WeaponStats

@export var attack_dmg: int = 10
@export var attack_speed: float = 1.0
@export var default_cooldown: float = 0.5
@export var attack_range: int = 400
@export var projectile_speed: int = 0

var bonus_attack_dmg: int = 0
var bonus_attack_range: int = 0
# 各武器 _ready() 首次配置数值用；比"和默认值比较"更稳
var configured: bool = false

func get_final_damage(char_stats = null) -> int:
	var bonus = char_stats.get_attack_damage() if char_stats else bonus_attack_dmg
	return attack_dmg + bonus

func get_final_range(char_stats = null) -> int:
	var bonus = char_stats.get_attack_range() if char_stats else bonus_attack_range
	return attack_range + bonus

# 攻速走 modifier：get_attack_speed() 作冷却除数（基础 1.0 不变，buff >1 更快）
func get_final_cooldown(char_stats = null) -> float:
	if char_stats:
		var aspd: float = char_stats.get_attack_speed()
		if aspd > 0.0:
			return default_cooldown / aspd
	return default_cooldown

func init_from_character(char_stats: Node) -> void:
	bonus_attack_dmg = char_stats.get_attack_damage()
	bonus_attack_range = char_stats.get_attack_range()
