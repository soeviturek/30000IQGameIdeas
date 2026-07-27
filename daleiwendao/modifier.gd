extends Resource
class_name Modifier

enum StatType {
	MOVE_SPEED,
	MAX_HEALTH,
	ATTACK_DAMAGE,
	ATTACK_RANGE,
	ATTACK_SPEED,
	LOOT_DROP,
	CRIT_CHANCE,
	CRIT_DAMAGE,
}

enum ModType {
	ADD,
	MUL,
}

@export var stat: StatType = StatType.MOVE_SPEED
@export var mod_type: ModType = ModType.ADD
@export var value: float = 0.0

static func create(s: StatType, mt: ModType, v: float) -> Modifier:
	var m = Modifier.new()
	m.stat = s
	m.mod_type = mt
	m.value = v
	return m
