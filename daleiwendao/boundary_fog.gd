extends Node2D
# 边界紫雾（review9 P1）：纯代码生成，零新增美术依赖。
# 四条边各一条渐变暗角(Sprite2D + GradientTexture2D，边缘不透明→内侧透明)
# 叠一条缓慢向内飘的紫色粒子(GPUParticles2D，粒子贴图=程序生成的径向软光点)。
# 摆放全部读 ArenaBounds，以后改地图大小会自动跟随。

const FOG_DEPTH := 220.0                          # 雾带厚度（从边界向内延伸）
const FOG_TINT := Color(0.55, 0.25, 0.75)         # 紫
const EDGE_ALPHA := 0.42                          # 暗角在边界处的最大不透明度
const PARTICLE_TINT := Color(0.62, 0.32, 0.82, 0.5)

var _dot: GradientTexture2D

func _ready() -> void:
	z_index = -5   # 压在角色/怪物下面，别糊住玩家
	_dot = _make_dot()
	var hw := ArenaBounds.HALF_WIDTH
	var hh := ArenaBounds.HALF_HEIGHT
	# 每条边：暗角渐变 + 向内飘的粒子。inward = 指向地图中心的方向。
	# 上边
	_make_edge_gradient(Vector2(-hw, -hh), 2.0 * hw, FOG_DEPTH, Vector2(0.5, 0.0), Vector2(0.5, 1.0))
	_make_edge_particles(Vector2(0.0, -hh), Vector2(0, 1), 2.0 * hw, false)
	# 下边
	_make_edge_gradient(Vector2(-hw, hh - FOG_DEPTH), 2.0 * hw, FOG_DEPTH, Vector2(0.5, 1.0), Vector2(0.5, 0.0))
	_make_edge_particles(Vector2(0.0, hh), Vector2(0, -1), 2.0 * hw, false)
	# 左边
	_make_edge_gradient(Vector2(-hw, -hh), FOG_DEPTH, 2.0 * hh, Vector2(0.0, 0.5), Vector2(1.0, 0.5))
	_make_edge_particles(Vector2(-hw, 0.0), Vector2(1, 0), 2.0 * hh, true)
	# 右边
	_make_edge_gradient(Vector2(hw - FOG_DEPTH, -hh), FOG_DEPTH, 2.0 * hh, Vector2(1.0, 0.5), Vector2(0.0, 0.5))
	_make_edge_particles(Vector2(hw, 0.0), Vector2(-1, 0), 2.0 * hh, true)

func _make_dot() -> GradientTexture2D:
	# 径向软光点（白心→透明边），作粒子贴图；靠 material.color 染紫。
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 48
	t.height = 48
	return t

func _make_edge_gradient(top_left: Vector2, w: float, h: float, from: Vector2, to: Vector2) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(FOG_TINT.r, FOG_TINT.g, FOG_TINT.b, EDGE_ALPHA))  # 边界侧：紫
	g.set_color(1, Color(FOG_TINT.r, FOG_TINT.g, FOG_TINT.b, 0.0))         # 内侧：透明
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = from
	t.fill_to = to
	t.width = int(w)
	t.height = int(h)
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = top_left
	s.z_index = -5
	add_child(s)

func _make_edge_particles(center: Vector2, inward: Vector2, along_len: float, vertical_edge: bool) -> void:
	var p := GPUParticles2D.new()
	p.texture = _dot
	p.amount = 52
	p.lifetime = 3.6
	p.preprocess = 2.5          # 开局就已飘满，避免第一帧空荡
	p.position = center
	p.z_index = -4
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	if vertical_edge:
		mat.emission_box_extents = Vector3(14.0, along_len * 0.5, 0.0)
	else:
		mat.emission_box_extents = Vector3(along_len * 0.5, 14.0, 0.0)
	mat.direction = Vector3(inward.x, inward.y, 0.0)
	mat.spread = 22.0
	mat.initial_velocity_min = 18.0
	mat.initial_velocity_max = 38.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.8
	mat.scale_max = 1.9
	mat.color = PARTICLE_TINT
	p.process_material = mat
	add_child(p)
