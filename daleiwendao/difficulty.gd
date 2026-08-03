extends RefCounted
class_name Difficulty
# 敌人缩放中枢：有效强度 = 境界基线（自动）× 险地系数（玩家进关前选，默认 0）
#   境界基线 → 吸收洞府强化带来的碾压，让「你变强，怪也变强」→ 修复「大乘一刀秒怪」
#   险地系数 → 玩家主动赌命的 risk/reward 旋钮（越高越难，但奖励涨得更快）
#   奖励系数刻意 > 血量系数：高难更「划算」但更险 → 制造真正的决策，而非纯堆数值
# 视觉分级：怪按有效档位染色 白→橙→红→深红→黑血，一眼看出牛逼（self_modulate，不冲突闪红）

const HP_PER_REALM := 0.35
const HP_PER_DANGER := 0.25
const DMG_PER_REALM := 0.20
const DMG_PER_DANGER := 0.18
const LOOT_PER_REALM := 0.50   # 修为源随境界快速增长 → 修复「进度爬得慢」
const LOOT_PER_DANGER := 0.50
const SPD_PER_DANGER := 0.06    # 只有险地加移速；境界不加，避免后期怪追不上/躲不掉失衡

static func hp_mult(realm: int, danger: int) -> float:
	return (1.0 + HP_PER_REALM * float(realm)) * (1.0 + HP_PER_DANGER * float(danger))

static func dmg_mult(realm: int, danger: int) -> float:
	return (1.0 + DMG_PER_REALM * float(realm)) * (1.0 + DMG_PER_DANGER * float(danger))

static func loot_mult(realm: int, danger: int) -> float:
	return (1.0 + LOOT_PER_REALM * float(realm)) * (1.0 + LOOT_PER_DANGER * float(danger))

static func speed_mult(danger: int) -> float:
	return 1.0 + SPD_PER_DANGER * float(danger)

# 有效档位 → 颜色（境界 + 险地 叠加）。0=寻常白，越高越血红。
static func tier_color(tier: int) -> Color:
	match clampi(tier, 0, 7):
		0: return Color(1.0, 1.0, 1.0)
		1: return Color(1.0, 0.84, 0.62)
		2: return Color(1.0, 0.66, 0.48)
		3: return Color(1.0, 0.46, 0.40)
		4: return Color(0.96, 0.30, 0.28)
		5: return Color(0.82, 0.22, 0.24)
		6: return Color(0.64, 0.16, 0.20)
		_: return Color(0.48, 0.12, 0.16)
