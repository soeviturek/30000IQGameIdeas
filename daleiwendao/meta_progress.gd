extends Node
# 大雷问道 · 洞府永久进度（自动加载单例 "Meta"）
#   局外无限成长：灵石银行 + 永久强化（每级更贵、效果线性叠加 → 永远有得买、越买越强）
#   每次出关（胜/负皆有灵石入账）归来，都能在洞府继续精进 → 下一局更强 → 挣更多灵石
#   境界脊柱：战斗掉「修为」跨局累积（永不清零，仅飞升重置），跨阈值 → 突破大境界（总闸+身份）
#   存档：user://meta.save（ConfigFile，跨启动持久）

signal realm_advanced(realm_index: int, realm_name: String)

const SAVE_PATH := "user://meta.save"

# 境界阶梯（身份脊柱）。修为为「闸门轨」：只推进境界，材料加速不了。
# REALM_THRESH = 到达该境所需的累计修为（provisional，实现后按 §2 时间线校准；P1 只用前 3 境）。
const REALMS := ["炼气", "筑基", "金丹", "元婴", "化神", "炼虚", "大乘", "飞升"]
const REALM_THRESH := [0, 300, 900, 2200, 4800, 9000, 16000, 28000]

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
	{"id": "jian_tai", "name": "剑胎", "kind": "start_qi", "desc": "出关起手 +1 层惊鸿剑气", "per": 1.0, "base_cost": 220, "growth": 1.9, "max": 1},
]

# ============================================================
# 合欢宫 · 仙缘玉抽卡（第四货币：只换皮肤/CG/收藏，永不直接买战力）
#   铁律：RNG 本体 0 战力；稀有 = 仅稀有；无空抽 + 保底 + 重复转「合欢玉髓」。
#   仙缘玉来源：Boss 首杀 / 渡劫 / 奇遇 / 隐藏事件（绝不普通刷怪）。
#   逐字对应 web 原型 hehuangong.html，行为一致。
# ============================================================
const PITY_CAP := 10   # 第 10 掷保底飞升(SSR)+

# 品阶：权重 w、重复折算玉髓 sui、图鉴框色 col、符号 sym、序 rank
const RA := {
	"N":   {"nm": "常服",     "col": "c3ccd6", "w": 600, "sui": 1,  "sym": "🎴", "rank": 0},
	"R":   {"nm": "泳装",     "col": "ff6f9d", "w": 250, "sui": 3,  "sym": "🌸", "rank": 1},
	"SR":  {"nm": "浴衣",     "col": "5fd8f2", "w": 110, "sui": 8,  "sym": "💮", "rank": 2},
	"SSR": {"nm": "飞升形态", "col": "ffd76a", "w": 36,  "sui": 20, "sym": "💎", "rank": 3},
	"UR":  {"nm": "婚礼CG",   "col": "ff6a4d", "w": 4,   "sui": 60, "sym": "👑", "rank": 4},
}
const RANKS := ["N", "R", "SR", "SSR", "UR"]

# 合欢录图鉴（占位美术：图鉴用品阶框 + 符号 + 名，无外部立绘依赖）
const POOL := [
	{"id": "ls_N",   "who": "青衫·凌霜", "ra": "N",   "nm": "炼器常服"},
	{"id": "ls_R",   "who": "青衫·凌霜", "ra": "R",   "nm": "寒潭·泳装"},
	{"id": "ls_SR",  "who": "青衫·凌霜", "ra": "SR",  "nm": "月华·浴衣"},
	{"id": "ls_SSR", "who": "青衫·凌霜", "ra": "SSR", "nm": "飞升·剑仙姿"},
	{"id": "ls_UR",  "who": "青衫·凌霜", "ra": "UR",  "nm": "合卺·凌霜"},
	{"id": "sx_N",   "who": "白衣·素心", "ra": "N",   "nm": "炼体常服"},
	{"id": "sx_R",   "who": "白衣·素心", "ra": "R",   "nm": "温泉·泳装"},
	{"id": "sx_SR",  "who": "白衣·素心", "ra": "SR",  "nm": "素雪·浴衣"},
	{"id": "sx_SSR", "who": "白衣·素心", "ra": "SSR", "nm": "飞升·药王姿"},
	{"id": "cs_N",   "who": "丹鼎·赤芍", "ra": "N",   "nm": "身法常服"},
	{"id": "cs_R",   "who": "丹鼎·赤芍", "ra": "R",   "nm": "火榴·泳装"},
	{"id": "cs_SR",  "who": "丹鼎·赤芍", "ra": "SR",  "nm": "丹霞·浴衣"},
	{"id": "cs_SSR", "who": "丹鼎·赤芍", "ra": "SSR", "nm": "飞升·丹尊姿"},
	{"id": "my_N",   "who": "宫主·妙音", "ra": "N",   "nm": "合欢常服"},
	{"id": "my_SR",  "who": "宫主·妙音", "ra": "SR",  "nm": "琵琶·浴衣"},
	{"id": "my_UR",  "who": "宫主·妙音", "ra": "UR",  "nm": "合卺·妙音"},
]
# 集齐一位师姐所有相 → 图鉴里程碑（≤5% 便利，确定性发放，永不 RNG 买战力）
const SETS := {"青衫·凌霜": "+1% 修为获取", "白衣·素心": "+2% 灵石掉落", "丹鼎·赤芍": "+1% 幸运"}

# 仙缘玉产出（Boss 首杀 / 渡劫），稀有 → 每次到手都是"又能去合欢宫了"
const WIN_XIANYU := 2      # 剿灭妖王通关一次
const REALM_XIANYU := 3    # 每突破一大境界（渡劫奇缘）

var stones: int = 0
var levels: Dictionary = {}
var cultivation: int = 0   # 累计修为（闸门轨，永不清零）
var realm: int = 0         # 当前大境界下标（0=炼气）
var xianyu: int = 8        # 仙缘玉（合欢宫抽卡货币）
var yusui: int = 0         # 合欢玉髓（重复折算，收藏向）
var pity: int = 0          # 保底计数（连续未出 SSR 的次数）
var dex: Dictionary = {}   # 图鉴：item_id → 拥有张数

func _ready() -> void:
	randomize()
	load_game()

# —— 存档读写 ——
func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	stones = int(cfg.get_value("meta", "stones", 0))
	cultivation = int(cfg.get_value("meta", "cultivation", 0))
	realm = int(cfg.get_value("meta", "realm", 0))
	realm = clampi(realm, 0, REALMS.size() - 1)
	xianyu = int(cfg.get_value("meta", "xianyu", 8))
	yusui = int(cfg.get_value("meta", "yusui", 0))
	pity = int(cfg.get_value("meta", "pity", 0))
	var saved_dex = cfg.get_value("meta", "dex", {})
	if saved_dex is Dictionary:
		for k in saved_dex.keys():
			dex[str(k)] = int(saved_dex[k])
	var saved = cfg.get_value("meta", "levels", {})
	if saved is Dictionary:
		for k in saved.keys():
			levels[str(k)] = int(saved[k])

func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "stones", stones)
	cfg.set_value("meta", "cultivation", cultivation)
	cfg.set_value("meta", "realm", realm)
	cfg.set_value("meta", "levels", levels)
	cfg.set_value("meta", "xianyu", xianyu)
	cfg.set_value("meta", "yusui", yusui)
	cfg.set_value("meta", "pity", pity)
	cfg.set_value("meta", "dex", dex)
	cfg.save(SAVE_PATH)

func reset_all() -> void:
	stones = 0
	cultivation = 0
	realm = 0
	levels.clear()
	xianyu = 8
	yusui = 0
	pity = 0
	dex.clear()
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

# —— 境界 / 修为（闸门轨）——
# 战斗中累积修为；跨阈值即当场突破大境界，逐境发 realm_advanced（供 HUD 演出 + 世界当场变）。
func add_cultivation(n: int) -> int:
	if n <= 0:
		return 0
	cultivation += n
	var advanced := 0
	while realm + 1 < REALMS.size() and cultivation >= REALM_THRESH[realm + 1]:
		realm += 1
		advanced += 1
		xianyu += REALM_XIANYU   # 渡劫奇缘 → 合欢宫抽卡货币
		realm_advanced.emit(realm, REALMS[realm])
	if advanced > 0:
		save_game()
	return advanced

func realm_name() -> String:
	return REALMS[clampi(realm, 0, REALMS.size() - 1)]

func realm_index() -> int:
	return realm

func is_max_realm() -> bool:
	return realm + 1 >= REALMS.size()

func next_realm_name() -> String:
	if is_max_realm():
		return ""
	return REALMS[realm + 1]

func next_realm_thresh() -> int:
	if is_max_realm():
		return REALM_THRESH[realm]
	return REALM_THRESH[realm + 1]

# 当前境界内已积攒的修为（用于进度条 "x / y"）
func cultivation_in_realm() -> int:
	return cultivation - REALM_THRESH[realm]

func realm_span() -> int:
	if is_max_realm():
		return 0
	return REALM_THRESH[realm + 1] - REALM_THRESH[realm]

func realm_progress() -> float:
	if is_max_realm():
		return 1.0
	var span := realm_span()
	if span <= 0:
		return 1.0
	return clampf(float(cultivation_in_realm()) / float(span), 0.0, 1.0)

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

# ============================================================
# 合欢宫 · 仙缘玉抽卡 API（逐字对应 web 原型：无空抽 + 保底 + 重复转玉髓）
# ============================================================
func add_xianyu(n: int) -> void:
	if n <= 0:
		return
	xianyu += n
	save_game()

func can_pull(n: int) -> bool:
	return xianyu >= n

# 花 n 枚仙缘玉抽 n 次；十连末抽保底浴衣(SR)+。返回逐抽结果数组（供合欢宫演出）。
func pull(n: int) -> Array:
	if xianyu < n:
		return []
	xianyu -= n
	var out: Array = []
	for i in range(n):
		var guarantee: bool = (n >= 10 and i == n - 1)
		out.append(draw_one(guarantee))
	save_game()
	return out

func draw_one(guarantee_sr: bool = false) -> Dictionary:
	var ra := _roll_rarity(guarantee_sr)
	if int(RA[ra]["rank"]) >= int(RA["SSR"]["rank"]):
		pity = 0
	else:
		pity += 1
	return _grant_item(ra)

func _weighted_rarity() -> String:
	var tot := 0
	for k in RANKS:
		tot += int(RA[k]["w"])
	var x := randf() * float(tot)
	for k in RANKS:
		x -= float(RA[k]["w"])
		if x < 0.0:
			return k
	return "N"

func _roll_rarity(guarantee_sr: bool) -> String:
	var r := _weighted_rarity()
	if pity >= PITY_CAP - 1 and int(RA[r]["rank"]) < int(RA["SSR"]["rank"]):
		r = "SSR"                                            # 第 10 掷保底飞升
	if guarantee_sr and int(RA[r]["rank"]) < int(RA["SR"]["rank"]):
		r = "SR"                                             # 十连保底浴衣+
	return r

# 无空抽：先给未拥有的新相；已集齐则重复 → 折算合欢玉髓。返回 {it, dupe, sui, ra}
func _grant_item(ra: String) -> Dictionary:
	var pool: Array = []
	for p in POOL:
		if str(p["ra"]) == ra:
			pool.append(p)
	var unowned: Array = []
	for p in pool:
		if not dex.has(str(p["id"])):
			unowned.append(p)
	if unowned.size() > 0:
		var it: Dictionary = unowned[randi() % unowned.size()]
		dex[str(it["id"])] = 1
		return {"it": it, "dupe": false, "sui": 0, "ra": ra}
	var it2: Dictionary = pool[randi() % pool.size()]
	dex[str(it2["id"])] = int(dex.get(str(it2["id"]), 1)) + 1
	var g := int(RA[ra]["sui"])
	yusui += g
	return {"it": it2, "dupe": true, "sui": g, "ra": ra}

# —— 图鉴查询（供合欢宫 UI）——
func owned_count() -> int:
	var c := 0
	for p in POOL:
		if dex.has(str(p["id"])):
			c += 1
	return c

func pool_size() -> int:
	return POOL.size()

func pity_remaining() -> int:
	return maxi(0, PITY_CAP - pity)

func dex_count(id: String) -> int:
	return int(dex.get(id, 0))
