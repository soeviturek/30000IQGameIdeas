extends Node
# 大雷问道 · 洞府永久进度（自动加载单例 "Meta"）
#   局外无限成长：灵石银行 + 永久强化（每级更贵、效果线性叠加 → 永远有得买、越买越强）
#   每次出关（胜/负皆有灵石入账）归来，都能在洞府继续精进 → 下一局更强 → 挣更多灵石
#   存档：user://meta.save（ConfigFile，跨启动持久）

const SAVE_PATH := "user://meta.save"

# 永久强化目录。kind 决定出关时如何生效：
#   maxhp / atk_mul / move_mul / crit_add  → 直接叠 Modifier
#   stones_mul → 灵石获取倍率；start_qi → 起手剑气层数；start_points → 起手造化点
# max = 0 表示无上限（无限成长）
const UPGRADES := [
	{"id": "gen_gu", "name": "根骨", "kind": "maxhp", "desc": "每级 +25 气血上限", "per": 25.0, "base_cost": 60, "growth": 1.26, "max": 0},
	{"id": "gang_qi", "name": "罡气", "kind": "atk_mul", "desc": "每级 +12% 攻击", "per": 0.12, "base_cost": 80, "growth": 1.30, "max": 0},
	{"id": "dun_fa", "name": "遁法", "kind": "move_mul", "desc": "每级 +4% 移速", "per": 0.04, "base_cost": 70, "growth": 1.27, "max": 0},
	{"id": "shen_shi", "name": "神识", "kind": "crit_add", "desc": "每级 +2% 暴击率", "per": 0.02, "base_cost": 100, "growth": 1.33, "max": 25},
	{"id": "lian_cai", "name": "敛财", "kind": "stones_mul", "desc": "每级 +10% 灵石获取", "per": 0.10, "base_cost": 120, "growth": 1.30, "max": 0},
	{"id": "zao_hua", "name": "造化", "kind": "start_points", "desc": "每级 出关起手 +1 造化点", "per": 1.0, "base_cost": 150, "growth": 1.6, "max": 8},
	{"id": "jian_tai", "name": "剑胎", "kind": "start_qi", "desc": "每级 出关起手 +1 层惊鸿剑气", "per": 1.0, "base_cost": 220, "growth": 1.9, "max": 3},
]

var stones: int = 0
var levels: Dictionary = {}

func _ready() -> void:
	load_game()

# —— 存档读写 ——
func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	stones = int(cfg.get_value("meta", "stones", 0))
	var saved = cfg.get_value("meta", "levels", {})
	if saved is Dictionary:
		for k in saved.keys():
			levels[str(k)] = int(saved[k])

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "stones", stones)
	cfg.set_value("meta", "levels", levels)
	cfg.save(SAVE_PATH)

func reset_all() -> void:
	stones = 0
	levels.clear()
	save_game()

# —— 查询 ——
func get_all() -> Array:
	return UPGRADES

func _spec(id: String) -> Dictionary:
	for u in UPGRADES:
		if u["id"] == id:
			return u
	return {}

func get_level(id: String) -> int:
	return int(levels.get(id, 0))

func is_maxed(id: String) -> bool:
	var s := _spec(id)
	var mx := int(s.get("max", 0))
	return mx > 0 and get_level(id) >= mx

func cost(id: String) -> int:
	var s := _spec(id)
	if s.is_empty():
		return 0
	return int(round(float(s["base_cost"]) * pow(float(s["growth"]), get_level(id))))

func can_afford(id: String) -> bool:
	return not is_maxed(id) and stones >= cost(id)

func buy(id: String) -> bool:
	if not can_afford(id):
		return false
	stones -= cost(id)
	levels[id] = get_level(id) + 1
	save_game()
	return true

func add_stones(n: int) -> void:
	if n <= 0:
		return
	stones += n
	save_game()

# —— 出关时生效 ——
func _total(id: String) -> float:
	var s := _spec(id)
	if s.is_empty():
		return 0.0
	return float(get_level(id)) * float(s["per"])

func stone_mult() -> float:
	return 1.0 + _total("lian_cai")

func starting_qi() -> int:
	return get_level("jian_tai")

func starting_points() -> int:
	return get_level("zao_hua")

# 把永久属性强化叠加到玩家 stats（出关瞬间调用一次）
func apply_to_stats(stats: CharacterStats) -> void:
	var hp := _total("gen_gu")
	if hp > 0.0:
		stats.add_modifier(Modifier.create(Modifier.StatType.MAX_HEALTH, Modifier.ModType.ADD, hp))
	var atk := _total("gang_qi")
	if atk > 0.0:
		stats.add_modifier(Modifier.create(Modifier.StatType.ATTACK_DAMAGE, Modifier.ModType.MUL, atk))
	var mv := _total("dun_fa")
	if mv > 0.0:
		stats.add_modifier(Modifier.create(Modifier.StatType.MOVE_SPEED, Modifier.ModType.MUL, mv))
	var cc := _total("shen_shi")
	if cc > 0.0:
		stats.add_modifier(Modifier.create(Modifier.StatType.CRIT_CHANCE, Modifier.ModType.ADD, cc))
