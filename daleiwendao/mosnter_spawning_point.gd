extends Node2D
# 第一章《幽篁秘境》关卡导演：分阶段波次 → 关底妖王
# 依 GameState.elapsed 推进；通过 announce 信号驱动 HUD 横幅

signal announce(text: String, color: Color)

@export var monsters_to_spawn: Array[PackedScene] = []
const BOSS_SCENE := preload("res://boss_monster.tscn")

# —— 时间线（秒）——
const T_RANGED := 33.0   # 飞妖加入
const T_SWARM := 66.0    # 妖潮
const BOSS_TIME := 100.0 # 妖王降临（到点后停刷，肃清余孽方降临）
const BOSS_FORCE_DELAY := 25.0 # 到点后最多再等这么久仍未清场 → 强制降临（兜底防卡死）

const COL_GOLD := Color("f0d98c")
const COL_RED := Color("ff6a5c")

var _accum: float = 0.0
var _phase: int = -1
var _boss_spawned: bool = false
var _boss_pending: bool = false   # 已到时间：停止刷怪，等待玩家清场

func _process(delta: float) -> void:
	if GameState.game_over or GameState.victory:
		return
	var e: float = GameState.elapsed
	_update_phase(e)

	# 妖王降临：到点先停常规刷怪，肃清余孽后妖王方降临；超时则强制（兜底防卡死）
	if _boss_spawned:
		return
	if e >= BOSS_TIME:
		if not _boss_pending:
			_boss_pending = true
			announce.emit("妖气汇聚 · 肃清余孽，妖王将临", COL_RED)
			Sfx.play("monster", -3.0, 0.03)
		if _living_enemy_count() == 0 or e >= BOSS_TIME + BOSS_FORCE_DELAY:
			_spawn_boss()
		return
	if monsters_to_spawn.is_empty():
		return

	_accum += delta
	var t: float = clamp(e / BOSS_TIME, 0.0, 1.0)
	var interval: float = lerp(0.9, 0.28, t)
	if _accum >= interval:
		_accum = 0.0
		var batch: int = 1 + int(t * 2.0)
		for i in batch:
			_spawn_one(e)

func _update_phase(e: float) -> void:
	var p := 0
	if e >= T_SWARM:
		p = 2
	elif e >= T_RANGED:
		p = 1
	if p != _phase:
		_phase = p
		match p:
			0: announce.emit("第一波 · 妖群袭来", COL_GOLD)
			1: announce.emit("第二波 · 飞妖出没", COL_GOLD)
			2: announce.emit("妖潮涌动 · 全力御敌", COL_RED)
		Sfx.play("monster", -5.0, 0.06)   # 波次刷新时的妖物嘶吼

func _spawn_one(e: float) -> void:
	# 30秒前只出近战狗头人，之后混入远程飞妖
	var scene: PackedScene
	if e < T_RANGED or monsters_to_spawn.size() < 2:
		scene = monsters_to_spawn[0]
	else:
		scene = monsters_to_spawn.pick_random()
	var monster = scene.instantiate()
	get_tree().current_scene.add_child(monster)
	_apply_scaling(monster)
	monster.add_to_group("Enemy")
	monster.global_position = _pick_spawn_pos()

func _living_enemy_count() -> int:
	var n := 0
	for x in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(x):
			n += 1
	return n

func _spawn_boss() -> void:
	_boss_spawned = true
	# 妖王一掌清场：现有杂鱼折算成战功（计入击杀 → 最终灵石），避免"努力白费"
	var cleared := 0
	for e in get_tree().get_nodes_in_group("Enemy"):
		if is_instance_valid(e):
			cleared += 1
			e.queue_free()
	GameState.add_bonus_kills(cleared)
	GameState.shake(0.5, 11.0)
	Sfx.play("bossroar", -2.0, 0.03)
	announce.emit("妖王降临 · 噬魂法王", COL_RED)
	var boss = BOSS_SCENE.instantiate()
	get_tree().current_scene.add_child(boss)
	_apply_scaling(boss)
	boss.global_position = _pick_spawn_pos()

func _pick_spawn_pos() -> Vector2:
	var player = get_tree().current_scene.get_node_or_null("Player")
	var center: Vector2 = player.global_position if player else Vector2.ZERO
	# 在竞技场范围内随机取点，且与玩家保持一定距离，避免糊脸
	var pos: Vector2 = global_position
	for i in 10:
		pos = Vector2(randf_range(-ArenaBounds.HALF_WIDTH + ArenaBounds.MARGIN, ArenaBounds.HALF_WIDTH - ArenaBounds.MARGIN), randf_range(-ArenaBounds.HALF_HEIGHT + ArenaBounds.MARGIN, ArenaBounds.HALF_HEIGHT - ArenaBounds.MARGIN))
		if pos.distance_to(center) > 320.0:
			break
	return pos

# 按当前境界 + 险地缩放刚生成的敌人（含妖王）。境界从 Meta 读，险地从 GameState 读。
func _apply_scaling(node: Node) -> void:
	if node == null or not node.has_method("apply_scaling"):
		return
	var realm := 0
	var meta := get_node_or_null("/root/Meta")
	if meta:
		realm = meta.realm_index()
	node.apply_scaling(realm, GameState.danger_tier)
