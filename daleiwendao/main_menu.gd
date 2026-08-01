extends Control
# 大雷问道 · 主菜单（纯代码构建）：背景 + 立绘 + 标题 + 开始/退出。

const COL_GOLD := Color("f0d98c")
const COL_TEXT := Color("eee0c8")

func _ready() -> void:
	_build()

func _build() -> void:
	var theme := Theme.new()
	var font = load("res://font.ttf")
	if font:
		theme.default_font = font
	theme.default_font_size = 22
	self.theme = theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 背景
	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://bg_scene3.jpg"):
		bg.texture = load("res://bg_scene3.jpg")
	add_child(bg)

	# 暗化叠层（提升文字可读性）
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.52)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# 立绘（右半屏）
	var ava := TextureRect.new()
	ava.anchor_left = 0.52
	ava.anchor_right = 1.0
	ava.anchor_top = 0.0
	ava.anchor_bottom = 1.0
	ava.offset_left = 20
	ava.offset_top = 16
	ava.offset_bottom = -8
	ava.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ava.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ava.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cand in ["res://portraits/levelup_baiyi.png", "res://portraits/avatar_baiyi.png"]:
		if ResourceLoader.exists(cand):
			ava.texture = load(cand)
			break
	add_child(ava)

	# 左半屏：标题 + 按钮
	var col := VBoxContainer.new()
	col.anchor_left = 0.0
	col.anchor_right = 0.52
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.offset_left = 64
	col.offset_right = -20
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	var title := _label("大 雷 问 道", 72, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(title)
	var sub := _label("第一章 · 幽篁秘境", 28, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(sub)
	var tag := _label("— 修仙 · 割草 · Roguelite 试玩 Demo —", 18, Color("c9b8e8"), HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(tag)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)

	var start_btn := _menu_button("开 始 征 途")
	start_btn.pressed.connect(_on_start)
	col.add_child(start_btn)

	var quit_btn := _menu_button("退 出")
	quit_btn.pressed.connect(_on_quit)
	col.add_child(quit_btn)

	var hint := _label("Enter / 点击「开始征途」   ·   Esc 退出", 15, Color("9a8ac0"), HORIZONTAL_ALIGNMENT_LEFT)
	col.add_child(hint)

	start_btn.grab_focus()

	# 标题微光呼吸
	var tw := create_tween().set_loops()
	tw.tween_property(title, "modulate", Color(1.15, 1.1, 0.92, 1.0), 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "modulate", Color(0.88, 0.86, 0.78, 1.0), 1.4).set_trans(Tween.TRANS_SINE)

func _menu_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 58)
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a1330")
	sb.set_border_width_all(2)
	sb.border_color = COL_GOLD
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color("2a1f4a")
	sbh.border_color = Color("ffe8a8")
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color("fff0c0"))
	b.add_theme_color_override("font_focus_color", Color("fff0c0"))
	return b

func _label(text: String, size: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _on_start() -> void:
	get_tree().change_scene_to_file("res://cave.tscn")

func _on_quit() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
		_on_start()
	elif key.keycode == KEY_ESCAPE:
		_on_quit()
