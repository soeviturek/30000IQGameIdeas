extends Node2D
class_name WeaponBase

@export var stats: WeaponStats
@export var owner_tag: String = "Player"

var can_attack: bool = true
var _cooldown_timer: Timer
var _char_stats: CharacterStats = null

func _ready() -> void:
	if stats == null:
		stats = WeaponStats.new()
	_cooldown_timer = Timer.new()
	_cooldown_timer.name = "CooldownTimer"
	_cooldown_timer.one_shot = true
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

func init_weapon(char_stats: Node) -> void:
	_char_stats = char_stats
	stats.init_from_character(char_stats)

func _process(delta: float) -> void:
	if not _is_active():
		return
	_update_aiming(delta)
	try_attack()

func try_attack() -> void:
	if not can_attack or not _can_perform_attack():
		return
	var target := get_closest_enemy()
	if target == null:
		return
	var attack_data := {
		"damage": stats.get_final_damage(_char_stats),
		"range": stats.get_final_range(_char_stats),
		"cooldown": stats.get_final_cooldown(_char_stats),
		"position": global_position,
	}
	can_attack = false
	_cooldown_timer.start(attack_data.cooldown)
	_start_attack(attack_data, target)

func _start_attack(_attack_data: Dictionary, _target: Node2D) -> void:
	pass

func _can_perform_attack() -> bool:
	return true

func _is_active() -> bool:
	return true

func _update_aiming(_delta: float) -> void:
	pass

func get_closest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	if enemies.is_empty():
		return null
	var final_range = stats.get_final_range(_char_stats)
	enemies = enemies.filter(func(e):
		return (e.global_position - global_position).length() <= final_range
	)
	if enemies.is_empty():
		return null
	# 威胁优先：远程妖(1)/妖王(2) 高于杂鱼(0)，同威胁再比距离
	enemies.sort_custom(_sort_by_threat)
	return enemies[0]

func get_closest_enemy_any_range() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("Enemy")
	if enemies.is_empty():
		return null
	enemies.sort_custom(_sort_by_distance)
	return enemies[0]

func _threat_of(n: Node2D) -> int:
	var p = n.get("threat_priority")
	return p if p != null else 0

func _sort_by_threat(a: Node2D, b: Node2D) -> bool:
	var ta := _threat_of(a)
	var tb := _threat_of(b)
	if ta != tb:
		return ta > tb
	return (a.global_position - global_position).length() < (b.global_position - global_position).length()

func _sort_by_distance(a: Node2D, b: Node2D) -> bool:
	return (a.global_position - global_position).length() < (b.global_position - global_position).length()

func _on_cooldown_timeout() -> void:
	can_attack = true

# 掷暴击并算最终伤害。返回 {"damage": int, "crit": bool}。非玩家武器(无 roll_crit)则不暴击。
func _roll_damage(base_dmg: int) -> Dictionary:
	var crit := false
	var mult := 1.0
	if _char_stats and _char_stats.has_method("roll_crit"):
		var r: Dictionary = _char_stats.roll_crit()
		crit = r.get("crit", false)
		mult = r.get("mult", 1.0)
	return {"damage": int(round(base_dmg * mult)), "crit": crit}
