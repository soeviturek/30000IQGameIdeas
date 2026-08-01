extends WeaponBase
class_name SlashWeapon

@export var sword_qi_scene: PackedScene

@onready var pivot = $Pivot
@onready var animation_player = $AnimationPlayer

const QI_SPAWN_FORWARD := 40.0

# —— 法宝进化：惊鸿剑气 →（集齐符箓术）→ 剑气化虹 ——
const QI_MAX_LEVEL := 3
var qi_level: int = 0        # 惊鸿剑气·凝 层数：每层 +1 道剑气 & +10% 剑伤
var has_fulu: bool = false   # 是否已得符箓术
var evolved: bool = false    # 剑气化虹（究极形态）

var slashing: bool = false

func _ready() -> void:
	super._ready()
	if not stats.configured:
		stats.configured = true
		stats.attack_dmg = 25
		stats.default_cooldown = 1.2
		stats.attack_range = 200

# —— 造化接口（升级时由 HUD 调用）——
func add_qi_level() -> void:
	qi_level += 1
	_try_evolve()

func add_fulu() -> void:
	has_fulu = true
	_try_evolve()

func _try_evolve() -> void:
	if not evolved and qi_level >= QI_MAX_LEVEL and has_fulu:
		_evolve()

func _evolve() -> void:
	evolved = true
	GameState.shake(0.4, 10.0)
	Sfx.play("levelup")

# 剑本体范围/伤害的本地加成（只作用于剑，不波及弓）
func _range_bonus() -> float:
	return 80.0 if evolved else 0.0

func _dmg_mult() -> float:
	return (1.35 if evolved else 1.0) * (1.0 + 0.10 * float(qi_level))

func _can_perform_attack() -> bool:
	return not slashing

func _update_aiming(_delta: float) -> void:
	if slashing:
		return
	var target = get_closest_enemy()
	if target:
		pivot.look_at(target.global_position)
	# No target in range — don't aim anywhere

func _start_attack(attack_data: Dictionary, target: Node2D) -> void:
	slashing = true
	animation_player.play("slash")
	Sfx.play("attack", -5.0)
	_spawn_sword_qi(target)
	# 剑本体：范围内 AoE 伤害（含进化/凝气本地加成）
	var enemies = get_tree().get_nodes_in_group("Enemy")
	var final_range = stats.get_final_range(_char_stats) + _range_bonus()
	var base_dmg = int(round(attack_data.damage * _dmg_mult()))
	for enemy in enemies:
		var dist = (enemy.global_position - global_position).length()
		if dist <= final_range and enemy.has_method("take_damage"):
			var roll := _roll_damage(base_dmg)
			enemy.take_damage(roll.damage, global_position, roll.crit)

func _spawn_sword_qi(target: Node2D) -> void:
	if sword_qi_scene == null or target == null:
		return
	var dir := (target.global_position - global_position).angle()
	if evolved:
		# 剑气化虹：八方环绕
		var n := 8
		for i in n:
			_spawn_one_qi(dir + TAU * float(i) / float(n), true)
	else:
		# 惊鸿剑气：朝目标扇形，道数随凝气层数 (1 + qi_level)
		var count := 1 + qi_level
		var spread := deg_to_rad(16.0)
		for i in count:
			var off := (float(i) - float(count - 1) * 0.5) * spread
			_spawn_one_qi(dir + off, false)

func _spawn_one_qi(a: float, big: bool) -> void:
	var qi := sword_qi_scene.instantiate()
	get_tree().current_scene.add_child(qi)
	qi.global_position = global_position + Vector2.RIGHT.rotated(a) * QI_SPAWN_FORWARD
	qi.launch(a, big)

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	slashing = false
