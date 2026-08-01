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

var kills: int = 0
var xp: int = 0
var level: int = 1
var xp_to_next: int = 16
var elapsed: float = 0.0

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
	var reward := int((300 + kills * 5 + level * 20) * _stone_mult())
	spirit_stones = reward
	_bank(reward)
	victory = true
	stage_cleared.emit(spirit_stones)

# 失败也有收获（roguelite 元进度：每局都在攒灵石变强，努力不白费）
func _end_defeat() -> void:
	var reward := int((80 + kills * 3 + level * 10) * _stone_mult())
	spirit_stones = reward
	_bank(reward)

func _stone_mult() -> float:
	if has_node("/root/Meta"):
		return float(get_node("/root/Meta").stone_mult())
	return 1.0

func _bank(amount: int) -> void:
	if has_node("/root/Meta"):
		get_node("/root/Meta").add_stones(amount)

func add_kill(xp_value: int) -> void:
	kills += 1
	kills_changed.emit(kills)
	add_xp(max(xp_value, 5))

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
		xp_to_next = int(xp_to_next * 1.16) + 8
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next, level)

func reset() -> void:
	kills = 0
	xp = 0
	level = 1
	xp_to_next = 16
	elapsed = 0.0
	game_over = false
	victory = false
	spirit_stones = 0
	xp_changed.emit(xp, xp_to_next, level)
	kills_changed.emit(kills)
