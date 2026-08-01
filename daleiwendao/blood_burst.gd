extends Node2D
class_name BloodBurst
# 受击溅血特效（review 需求：暴击往击退方向溅血 + 留血迹）。纯代码零美术：
# 粒子贴图 = 程序生成的径向软光点，血迹 = 染色 Sprite2D。由 MonsterBase.take_damage 调
# BloodBurst.spawn() 生成，挂到世界根节点，暴击血迹留在原地缓慢淡出。

static var _drop: GradientTexture2D
static var _font: Font

const CRIT_TINT := Color(0.92, 0.10, 0.09)       # 鲜血红（暴击更亮但仍是血色，去掉橙火感）
const DECAL_CRIT := Color(0.48, 0.03, 0.03, 0.85)# 地面血渍

var _dir := Vector2.RIGHT
var _crit := false
var _amount := 0
var _gib := false

# 锐利血滴贴图：实心圆盘 + 极窄软边（比原来的大柔光点锐利，更像血珠/血线）
static func _drop_tex() -> GradientTexture2D:
	if _drop == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.7, Color(1, 1, 1, 1))
		_drop = GradientTexture2D.new()
		_drop.gradient = g
		_drop.fill = GradientTexture2D.FILL_RADIAL
		_drop.fill_from = Vector2(0.5, 0.5)
		_drop.fill_to = Vector2(1.0, 0.5)
		_drop.width = 24
		_drop.height = 24
	return _drop

static func _get_font() -> Font:
	if _font == null:
		_font = load("res://font.ttf")
	return _font

# world: 世界根节点(Main)；at: 受击世界坐标；dir: 溅血方向(击退方向)；crit: 是否暴击；amount: 伤害数值
static func spawn(world: Node, at: Vector2, dir: Vector2, crit: bool, amount: int) -> void:
	if world == null:
		return
	var b := BloodBurst.new()
	b._dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	b._crit = crit
	b._amount = amount
	b.position = at
	world.add_child(b)

# 暴击斩杀：全向大爆血 + 地面血泊（爆成一滩血）
static func spawn_gib(world: Node, at: Vector2, dir: Vector2) -> void:
	if world == null:
		return
	var b := BloodBurst.new()
	b._dir = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	b._crit = true
	b._gib = true
	b.position = at
	world.add_child(b)

func _ready() -> void:
	if _gib:
		_spawn_gib_burst()
		_spawn_streaks(10, 46.0, 40.0, 120.0)
		_spawn_puddle()
		GameState.shake(0.16, 6.0)
		await get_tree().create_timer(9.0).timeout
		queue_free()
		return
	if not _crit:
		queue_free()          # 普通命中不再喷血，仅暴击出血
		return
	_spawn_spray()
	_spawn_streaks(6, 20.0, 34.0, 82.0)
	_spawn_decals()
	_spawn_crit_number()
	Sfx.play("crit", -3.0)
	GameState.shake(0.10, 3.5)
	await get_tree().create_timer(6.5).timeout
	queue_free()

func _spawn_spray() -> void:
	# 细小血滴沿击退方向高速飙出、强重力成弧下坠。小尺寸 + 锐利贴图，不再糊住弹幕
	var p := GPUParticles2D.new()
	p.texture = _drop_tex()
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.z_index = 6
	p.amount = 22
	p.lifetime = 0.5
	p.modulate = CRIT_TINT
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(_dir.x, _dir.y, 0.0)
	mat.spread = 30.0
	mat.initial_velocity_min = 260.0
	mat.initial_velocity_max = 560.0
	mat.gravity = Vector3(0, 760, 0)          # 强重力：飙出即成弧下坠
	mat.damping_min = 20.0
	mat.damping_max = 60.0
	mat.scale_min = 0.12
	mat.scale_max = 0.5
	p.process_material = mat
	add_child(p)
	p.emitting = true

func _spawn_decals() -> void:
	for i in 4:
		var s := Sprite2D.new()
		s.texture = _drop_tex()
		s.z_index = -2
		s.modulate = DECAL_CRIT
		var along := _dir * randf_range(18.0, 78.0)   # 沿溅血方向落点
		s.position = along + Vector2(randf_range(-18, 18), randf_range(-14, 14))
		s.rotation = randf() * TAU
		var sc := randf_range(0.22, 0.5)
		s.scale = Vector2(sc, sc * randf_range(0.6, 0.95))  # 小血渍，不糊屏
		add_child(s)
		var tw := create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(s, "modulate:a", 0.0, 3.0)

func _spawn_streaks(count: int, spread_deg: float, dist_min: float, dist_max: float) -> void:
	# 飙血：沿击退方向甩出数条细长血线，快速飞出并拉长淡出，像伤口喷出的血
	var tex := _drop_tex()
	for i in count:
		var ang := _dir.angle() + deg_to_rad(randf_range(-spread_deg, spread_deg))
		var d := Vector2.RIGHT.rotated(ang)
		var s := Sprite2D.new()
		s.texture = tex
		s.z_index = 5
		s.modulate = CRIT_TINT
		s.rotation = ang
		var stretch := randf_range(0.9, 1.8)
		var thin := randf_range(0.18, 0.34)
		s.scale = Vector2(stretch, thin)
		s.position = d * randf_range(4.0, 12.0)
		add_child(s)
		var travel := d * randf_range(dist_min, dist_max)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "position", s.position + travel, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale:x", stretch * 1.6, 0.2)
		tw.tween_property(s, "modulate:a", 0.0, 0.24).set_delay(0.04)
		tw.chain().tween_callback(s.queue_free)

func _spawn_crit_number() -> void:
	var l := Label.new()
	l.text = "暴击 %d" % _amount
	var f := _get_font()
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	l.add_theme_color_override("font_outline_color", Color(0.45, 0.04, 0.0))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 20
	l.position = Vector2(-32, -72)
	l.pivot_offset = Vector2(34, 22)              # 以文字中心缩放
	l.scale = Vector2(0.25, 0.25)
	l.modulate = Color(1.7, 1.7, 1.7, 1.0)        # 出现瞬间过曝闪白
	add_child(l)
	# 弹跳放大 punch：0.25→1.4→1.0，制造"闪"一下的爆点感
	var pop := create_tween()
	pop.tween_property(l, "scale", Vector2(1.4, 1.4), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(l, "scale", Vector2(1.0, 1.0), 0.09).set_trans(Tween.TRANS_SINE)
	# 同时：闪白快速回落 + 上浮 + 淡出
	var mv := create_tween()
	mv.set_parallel(true)
	mv.tween_property(l, "modulate", Color(1, 1, 1, 1), 0.14)
	mv.tween_property(l, "position:y", -134.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	mv.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.55)

# 暴击斩杀专用：全向大爆血
func _spawn_gib_burst() -> void:
	var p := GPUParticles2D.new()
	p.texture = _drop_tex()
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.z_index = 6
	p.amount = 40
	p.lifetime = 0.7
	p.modulate = CRIT_TINT
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(_dir.x, _dir.y, 0.0)
	mat.spread = 120.0                        # 偏击退方向的大扇面爆血（不再全向糊屏）
	mat.initial_velocity_min = 160.0
	mat.initial_velocity_max = 560.0
	mat.gravity = Vector3(0, 780, 0)
	mat.damping_min = 30.0
	mat.damping_max = 90.0
	mat.scale_min = 0.18
	mat.scale_max = 0.85
	p.process_material = mat
	add_child(p)
	p.emitting = true

# 地面血泊：一摊较大的暗红血迹，长时间残留后淡出
func _spawn_puddle() -> void:
	for i in 7:
		var s := Sprite2D.new()
		s.texture = _drop_tex()
		s.z_index = -2
		s.modulate = Color(0.42, 0.03, 0.03, 0.9)
		s.position = Vector2(randf_range(-30, 30), randf_range(-20, 24))
		s.rotation = randf() * TAU
		var sc := randf_range(0.5, 1.3)
		s.scale = Vector2(sc, sc * randf_range(0.6, 0.95))
		add_child(s)
		var tw := create_tween()
		tw.tween_interval(5.0)
		tw.tween_property(s, "modulate:a", 0.0, 4.0)
