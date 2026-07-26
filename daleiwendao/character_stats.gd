extends Node2D
class_name CharacterStats

@export var characterName: String = ""
@export var moveSpeed: float = 0
@export var type: int = 0 # 0 for player, 1 for monster
@export var health: int = 0
@export var attackRange: int = 0
@export var attackSpeed: float = 0
@export var attackDamage: int = 0
@export var lootDrop: int = 0

var modifiers: Array[Modifier] = []

func init_character(
		char_name: String,
		speed: float,
		char_type: int,
		hp: int,
		atk_range: int,
		atk_speed: float,
		atk_damage: int,
		loot: int = 0
	) -> void:
	characterName = char_name
	moveSpeed = speed
	type = char_type
	health = hp
	attackRange = atk_range
	attackSpeed = atk_speed
	attackDamage = atk_damage
	lootDrop = loot

# --- Modifier management ---

func add_modifier(mod: Modifier) -> void:
	modifiers.append(mod)

func remove_modifier(mod: Modifier) -> void:
	var idx = modifiers.find(mod)
	if idx >= 0:
		modifiers.remove_at(idx)

# --- Stat getters: (base + ADD) * (1 + MUL) ---

func _compute_stat(stat_type: Modifier.StatType, base: float) -> float:
	var add_total := 0.0
	var mul_total := 0.0
	for mod in modifiers:
		if mod.stat == stat_type:
			if mod.mod_type == Modifier.ModType.ADD:
				add_total += mod.value
			elif mod.mod_type == Modifier.ModType.MUL:
				mul_total += mod.value
	return (base + add_total) * (1.0 + mul_total)

func get_move_speed() -> float:
	return _compute_stat(Modifier.StatType.MOVE_SPEED, moveSpeed)

func get_max_health() -> int:
	return int(_compute_stat(Modifier.StatType.MAX_HEALTH, health))

func get_attack_damage() -> int:
	return int(_compute_stat(Modifier.StatType.ATTACK_DAMAGE, attackDamage))

func get_attack_range() -> int:
	return int(_compute_stat(Modifier.StatType.ATTACK_RANGE, attackRange))

func get_attack_speed() -> float:
	return _compute_stat(Modifier.StatType.ATTACK_SPEED, attackSpeed)

func get_loot_drop() -> int:
	return int(_compute_stat(Modifier.StatType.LOOT_DROP, lootDrop))
