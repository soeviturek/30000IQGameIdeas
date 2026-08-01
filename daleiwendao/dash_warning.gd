extends Node2D
class_name DashWarning
# 妖王突进预警 · 红色冲击走廊：锁定方向后脉动闪红，蓄力结束瞬间随冲刺消散。
# 仅作视觉预示（不造成伤害）；实际伤害由妖王冲刺本体接触判定。

var length: float = 560.0
var width: float = 104.0
var warn_time: float = 0.85

var _t: float = 0.0
var _fade: float = 0.0
var _fading: bool = false

const FADE_TIME := 0.16

func setup(pos: Vector2, dir: Vector2, corridor_len: float, corridor_w: float, warn: float) -> void:
	global_position = pos
	rotation = dir.angle()
	length = corridor_len
	width = corridor_w
	warn_time = warn

func _process(delta: float) -> void:
	_t += delta
	if not _fading and _t >= warn_time:
		_fading = true
	if _fading:
		_fade += delta
		if _fade >= FADE_TIME:
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	var grow: float = clampf(_t / warn_time, 0.0, 1.0)
	var pulse: float = 0.5 + 0.5 * sin(_t * 20.0)
	var a: float = 1.0
	if _fading:
		a = clampf(1.0 - _fade / FADE_TIME, 0.0, 1.0)
	var hw: float = width * 0.5
	# 走廊填充（沿 +X，rotation 已对齐冲刺方向）：渐显警示"这里要冲过来"
	draw_rect(Rect2(0.0, -hw, length, width), Color(0.95, 0.14, 0.1, (0.10 + 0.16 * grow) * a))
	# 边线脉动
	var edge := Color(1.0, 0.3, 0.2, (0.55 + 0.35 * pulse) * a)
	draw_line(Vector2(0.0, -hw), Vector2(length, -hw), edge, 3.0)
	draw_line(Vector2(0.0, hw), Vector2(length, hw), edge, 3.0)
	# 冲击端箭头
	draw_line(Vector2(length - 28.0, -hw), Vector2(length, 0.0), edge, 3.0)
	draw_line(Vector2(length - 28.0, hw), Vector2(length, 0.0), edge, 3.0)
