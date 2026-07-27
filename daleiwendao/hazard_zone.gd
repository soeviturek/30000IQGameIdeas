extends Node2D
class_name HazardZone
# 妖王场地危害 · 地火：预警圈 → 灼烧区，站入即受伤，逼迫玩家走位不能站桩

var radius: float = 86.0
var damage: int = 16
var warn_time: float = 0.9
var active_time: float = 2.1
var tick_interval: float = 0.45

var _t: float = 0.0
var _phase: int = 0          # 0=预警 1=灼烧 2=消散
var _tick: float = 0.0
var _player: Node2D = null
var _alpha: float = 1.0

func setup(pos: Vector2, r: float, dmg: int) -> void:
	global_position = pos
	radius = r
	damage = dmg

func _ready() -> void:
	_player = get_node_or_null("/root/Main/Player")

func _process(delta: float) -> void:
	_t += delta
	match _phase:
		0:
			if _t >= warn_time:
				_phase = 1
				_t = 0.0
				_tick = 0.0
		1:
			_tick -= delta
			if _tick <= 0.0:
				_tick = tick_interval
				_damage_if_inside()
			if _t >= active_time:
				_phase = 2
				_t = 0.0
		2:
			_alpha = clampf(1.0 - _t / 0.35, 0.0, 1.0)
			if _t >= 0.35:
				queue_free()
				return
	queue_redraw()

func _damage_if_inside() -> void:
	if not is_instance_valid(_player):
		return
	if global_position.distance_to(_player.global_position) <= radius:
		if _player.has_method("take_damage"):
			_player.take_damage(damage, global_position)

func _draw() -> void:
	if _phase == 0:
		# 预警：脉动红圈 + 渐显填充，明确"这里要着火"
		var grow: float = _t / warn_time
		var pulse: float = 0.5 + 0.5 * sin(_t * 14.0)
		draw_circle(Vector2.ZERO, radius, Color(0.95, 0.2, 0.12, 0.10 + 0.14 * grow))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 52, Color(1.0, 0.35, 0.2, 0.55 + 0.35 * pulse), 3.0, true)
	elif _phase == 1:
		# 灼烧：橙红实心 + 明亮边环
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.1, 0.34))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 52, Color(1.0, 0.62, 0.2, 0.9), 3.0, true)
	else:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.1, 0.3 * _alpha))
