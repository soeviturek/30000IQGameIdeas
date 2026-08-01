extends Node2D
# 升级光效：金色能量环扩散 + 上升灵光，纯 _draw 绘制，无素材依赖，播完自毁。

var _t := 0.0
const DUR := 1.05
var _motes: Array = []

func _ready() -> void:
	z_index = 60
	for i in 8:
		_motes.append({
			"ang": randf() * TAU,
			"rad": randf_range(6.0, 26.0),
			"spd": randf_range(48.0, 96.0),
			"sz": randf_range(2.0, 4.5),
		})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DUR:
		queue_free()

func _draw() -> void:
	var p := clampf(_t / DUR, 0.0, 1.0)
	var eo := 1.0 - pow(1.0 - p, 3.0)
	var alpha := 1.0 - p
	# 中心光晕
	draw_circle(Vector2.ZERO, (1.0 - p) * 42.0, Color(1.0, 0.9, 0.5, alpha * 0.22))
	# 扩散能量环
	for k in 3:
		var r := eo * (58.0 + k * 26.0) + 8.0
		var a := alpha * (0.5 - k * 0.12)
		if a > 0.0:
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, a), 3.0 - k * 0.6, true)
	# 上升灵光
	for m in _motes:
		var rise: float = m.spd * _t
		var pos: Vector2 = Vector2(cos(m.ang), sin(m.ang)) * m.rad + Vector2(0.0, -rise)
		draw_circle(pos, m.sz * (1.0 - p * 0.5), Color(1.0, 0.92, 0.6, alpha * 0.9))
