extends Node
# 大雷问道 · 全局状态 / 进度系统（自动加载单例）

signal xp_changed(xp: int, xp_to_next: int, level: int)
signal kills_changed(kills: int)
signal leveled_up(level: int)
signal game_over_changed(is_over: bool)
signal victory_changed(is_win: bool)
signal stage_cleared(reward: int)

var game_over: bool = false:
	set(value):
		if game_over == value:
			return
		game_over = value
		if value and not victory:
			_end_defeat()
		game_over_changed.emit(value)

var victory: bool = false:
	set(value):
		if victory == value:
			return
		victory = value
		victory_changed.emit(value)

var spirit_stones: int = 0
var run_xianyu: int = 0   # 本局到手仙缘玉（通关妖王首杀 → 合欢宫货币，供结算展示）

# 险地难度：玩家手动 +/- 的挑战偏移（0=寻常，正=更凶更肥，负=手下留情）。
# 敌人有效强度 = 境界基线（自动）× 险地系数。可在战斗中随时按 [ / ] 调整，
# 立即作用于之后刷出的敌人。负险地不削弱境界奖励基线（见 difficulty.gd）。
var danger_tier: int = 0
const DANGER_MIN := -3
const DANGER_MAX := 8

signal danger_changed(danger: int)

# 手动增减险地档位，返回是否真的变化了（用于 HUD 反馈）。
func adjust_danger(delta: int) -> bool:
	var nv: int = clampi(danger_tier + delta, DANGER_MIN, DANGER_MAX)
	if nv == danger_tier:
		return false
	danger_tier = nv
	danger_changed.emit(danger_tier)
	return true

var kills: int = 0
var xp: int = 0
var level: int = 1
var xp_to_next: int = 14
var elapsed: float = 0.0

# 三通道拆分：XP（局内升级）/ 修为（境界脊柱）/ 灵石（收获）各自独立，互不放大。
# run_loot = 本局累积收获（已按境界/险地放大）→ 只喂结算灵石。
var run_loot: int = 0
# 局内升级 XP：只按怪种基础值，不随境界/险地放大 → 升级节奏恒定可控。
const XP_BY_THREAT := [4, 7, 50]     # 杂鱼 / 飞妖 / 妖王
# 修为：只按怪种 + 险地温和放大（不吃自身境界，避免随境界暴涨、瞬间封顶）。
const CULT_BY_THREAT := [2, 4, 40]   # 杂鱼 / 飞妖 / 妖王

func _ready() -> void:
	# 运行时补充按键映射：WASD 移动 + R 重开（方向键为引擎默认映射，天然可用）
	_add_key("ui_left", KEY_A)
	_add_key("ui_right", KEY_D)
	_add_key("ui_up", KEY_W)
	_add_key("ui_down", KEY_S)
	if not InputMap.has_action("restart"):
		InputMap.add_action("restart")
	_add_key("restart", KEY_R)
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
	_add_key("dash", KEY_SPACE)

# 全局震屏便捷入口：任何脚本 GameState.shake(时长, 强度)
func shake(dur: float, strength: float) -> void:
	var s = get_tree().get_first_node_in_group("shaker")
	if s and s.has_method("shake"):
		s.shake(dur, strength)

func _add_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

func _process(delta: float) -> void:
	if not game_over and not victory:
		elapsed += delta

func win_stage() -> void:
	if victory:
		return
	# 通关灵石结算：底数 + 斩妖数 + 道行等级加成，再乘洞府「敛财」倍率
	var reward := int((300 + run_loot * 0.5 + level * 20) * _stone_mult())
	spirit_stones = reward
	_bank(reward)
	_award_xianyu()
	_flush_meta()
	victory = true
	stage_cleared.emit(spirit_stones)

# 失败也有收获（roguelite 元进度：每局都在攒灵石变强，努力不白费）
func _end_defeat() -> void:
	var reward := int((80 + run_loot * 0.3 + level * 10) * _stone_mult())
	spirit_stones = reward
	_bank(reward)
	_flush_meta()

func _stone_mult() -> float:
	if has_node("/root/Meta"):
		return float(get_node("/root/Meta").stone_mult())
	return 1.0

func _bank(amount: int) -> void:
	if has_node("/root/Meta"):
		get_node("/root/Meta").add_stones(amount)

# 剿灭妖王（通关）→ 掉仙缘玉：稀有货币，只能去合欢宫抽（Boss 首杀语义）。
func _award_xianyu() -> void:
	if has_node("/root/Meta"):
		var m = get_node("/root/Meta")
		run_xianyu = int(m.WIN_XIANYU)
		m.add_xianyu(run_xianyu)

# 修为脊柱：每次斩妖累积「修为」（跨局永久，推进境界）。
# 只按怪种基础值 + 险地温和放大，不吃自身境界 → 杜绝"境界越高修为越快、瞬间封顶"的失控。
func _gain_cultivation(threat_index: int) -> void:
	if not has_node("/root/Meta"):
		return
	var base: int = CULT_BY_THREAT[clampi(threat_index, 0, CULT_BY_THREAT.size() - 1)]
	var gain: int = int(round(base * (1.0 + 0.15 * float(maxi(0, danger_tier)))))
	get_node("/root/Meta").add_cultivation(maxi(1, gain))

# 出关落盘：把本局累积的修为/境界写入存档（银行结算已顺带存档，这里兜底一次）
func _flush_meta() -> void:
	if has_node("/root/Meta"):
		get_node("/root/Meta").save_game()

func add_kill(loot_value: int, threat: int = 0) -> void:
	kills += 1
	run_loot += maxi(0, loot_value)
	kills_changed.emit(kills)
	var ti: int = clampi(threat, 0, XP_BY_THREAT.size() - 1)
	add_xp(XP_BY_THREAT[ti])
	_gain_cultivation(ti)

# 妖王清场补偿：被清掉的杂鱼折算成战功（计入 kills → 最终灵石），不触发升级刷屏
func add_bonus_kills(n: int) -> void:
	if n <= 0:
		return
	kills += n
	kills_changed.emit(kills)

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = int(xp_to_next * 1.15) + 6
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

func reset() -> void:
	kills = 0
	run_loot = 0
	xp = 0
	level = 1
	xp_to_next = 14
	elapsed = 0.0
	game_over = false
	victory = false
	spirit_stones = 0
	run_xianyu = 0
	xp_changed.emit(xp, xp_to_next, level)
	kills_changed.emit(kills)
