extends Node2D
class_name BloodBurst
# 受击溅血特效（review 需求：暴击往击退方向溅血 + 留血迹）。纯代码零美术：
# 粒子贴图 = 程序生成的径向软光点，血迹 = 染色 Sprite2D。由 MonsterBase.take_damage 调
# BloodBurst.spawn() 生成，挂到世界根节点，暴击血迹留在原地缓慢淡出。

static var _dot: GradientTexture2D
static var _font: Font

const NORMAL_TINT := Color(0.80, 0.06, 0.09)     # 暗红喷血
const CRIT_TINT := Color(1.0, 0.32, 0.06)        # 橙红（暴击更骚更亮）
const DECAL_CRIT := Color(0.66, 0.05, 0.02, 0.9) # 地面血迹

var _dir := Vector2.RIGHT
var _crit := false
var _amount := 0
var _gib := false

static func _dot_tex() -> GradientTexture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_dot = GradientTexture2D.new()
		_dot.gradient = g
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		_dot.width = 32
		_dot.height = 32
	return _dot

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
		_spawn_puddle()
		GameState.shake(0.18, 7.0)
		GameState.hitstop(0.09, 0.04)
		await get_tree().create_timer(11.0).timeout
		queue_free()
		return
	_spawn_spray()
	var ttl := 1.2
	if _crit:
		_spawn_decals()
		_spawn_crit_number()
		GameState.shake(0.12, 4.0)
		GameState.hitstop()
		ttl = 8.5
	await get_tree().create_timer(ttl).timeout
	queue_free()

func _spawn_spray() -> void:
	var p := GPUParticles2D.new()
	p.texture = _dot_tex()
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.z_index = 6
	p.amount = 30 if _crit else 12
	p.lifetime = 0.7 if _crit else 0.45
	p.modulate = CRIT_TINT if _crit else NORMAL_TINT
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(_dir.x, _dir.y, 0.0)
	mat.spread = 42.0
	mat.initial_velocity_min = 200.0 if _crit else 110.0
	mat.initial_velocity_max = 420.0 if _crit else 230.0
	mat.gravity = Vector3(0, 420, 0)          # 溅出后下坠，像血
	mat.damping_min = 30.0
	mat.damping_max = 80.0
	mat.scale_min = 0.5
	mat.scale_max = 1.9 if _crit else 1.1
	p.process_material = mat
	add_child(p)
	p.emitting = true

func _spawn_decals() -> void:
	for i in 6:
		var s := Sprite2D.new()
		s.texture = _dot_tex()
		s.z_index = -2
		s.modulate = DECAL_CRIT
		var along := _dir * randf_range(8.0, 60.0)   # 沿溅血方向铺开
		s.position = along + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		s.rotation = randf() * TAU
		var sc := randf_range(0.7, 1.6)
		s.scale = Vector2(sc, sc * randf_range(0.55, 0.9))  # 椭圆，更像血迹
		add_child(s)
		var tw := create_tween()
		tw.tween_interval(4.0)
		tw.tween_property(s, "modulate:a", 0.0, 4.0)

func _spawn_crit_number() -> void:
	var l := Label.new()
	l.text = "暴击 %d" % _amount
	var f := _get_font()
	if f:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(1.0, 0.86, 0.24))
	l.add_theme_color_override("font_outline_color", Color(0.45, 0.04, 0.0))
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 20
	l.position = Vector2(-28, -70)
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", -128.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.75).set_delay(0.28)

# 暴击斩杀专用：全向大爆血
func _spawn_gib_burst() -> void:
	var p := GPUParticles2D.new()
	p.texture = _dot_tex()
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.z_index = 6
	p.amount = 64
	p.lifetime = 0.9
	p.modulate = CRIT_TINT
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0                        # 2D 下 ±180 = 全向喷射
	mat.initial_velocity_min = 120.0
	mat.initial_velocity_max = 480.0
	mat.gravity = Vector3(0, 520, 0)
	mat.damping_min = 40.0
	mat.damping_max = 110.0
	mat.scale_min = 0.7
	mat.scale_max = 2.4
	p.process_material = mat
	add_child(p)
	p.emitting = true

# 地面血泊：一摊较大的暗红血迹，长时间残留后淡出
func _spawn_puddle() -> void:
	for i in 10:
		var s := Sprite2D.new()
		s.texture = _dot_tex()
		s.z_index = -2
		s.modulate = Color(0.5, 0.03, 0.03, 0.92)
		s.position = Vector2(randf_range(-48, 48), randf_range(-32, 36))
		s.rotation = randf() * TAU
		var sc := randf_range(1.1, 2.7)
		s.scale = Vector2(sc, sc * randf_range(0.55, 0.9))
		add_child(s)
		var tw := create_tween()
		tw.tween_interval(6.5)
		tw.tween_property(s, "modulate:a", 0.0, 4.5)
