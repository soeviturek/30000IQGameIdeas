extends Control
# 大雷问道 · 洞府（局外枢纽）
#   消耗灵石永久强化 → 出关挑战（下副本）→ 归来再强化，无限成长闭环。
#   参照「守卫雅典娜 / 巨魔与精灵」：平时在洞府经营变强，进战斗是一次副本。

const COL_GOLD := Color("f0d98c")
const COL_TEXT := Color("eee0c8")
const COL_DIM := Color("9a8ac0")
const COL_STONE := Color("bfe8ff")

var _meta: Node
var _stone_lbl: Label
var _rows: Array = []

func _ready() -> void:
	_meta = get_node_or_null("/root/Meta")
	_build()

func _build() -> void:
	var theme := Theme.new()
	var font = load("res://font.ttf")
	if font:
		theme.default_font = font
	theme.default_font_size = 20
	self.theme = theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://bg_scene3.jpg"):
		bg.texture = load("res://bg_scene3.jpg")
	add_child(bg)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 90
	col.offset_right = -90
	col.offset_top = 34
	col.offset_bottom = -26
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	col.add_child(header)
	header.add_child(_label("洞 府", 44, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_stone_lbl = _label("", 30, COL_STONE, HORIZONTAL_ALIGNMENT_RIGHT)
	header.add_child(_stone_lbl)

	col.add_child(_label("消耗灵石永久精进 · 每次出关归来皆有所得 · 道行无止境", 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	if _meta:
		for u in _meta.get_all():
			list.add_child(_make_row(u))

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 20)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(footer)
	var go := _menu_button("出 关 挑 战", 260)
	go.pressed.connect(_on_challenge)
	footer.add_child(go)
	var back := _menu_button("返 回 菜 单", 220)
	back.pressed.connect(_on_menu)
	footer.add_child(back)

	_refresh()
	go.grab_focus()

func _make_row(u: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.16, 0.86)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.45, 0.38, 0.6, 0.7)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	panel.add_child(hb)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(info)
	var name_lbl := _label("", 24, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	info.add_child(name_lbl)
	info.add_child(_label(str(u["desc"]), 16, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	var cost_lbl := _label("", 18, COL_STONE, HORIZONTAL_ALIGNMENT_RIGHT)
	cost_lbl.custom_minimum_size = Vector2(160, 0)
	hb.add_child(cost_lbl)
	var btn := _menu_button("提 升", 120)
	btn.pressed.connect(_on_buy.bind(str(u["id"])))
	hb.add_child(btn)

	_rows.append({"id": str(u["id"]), "name": str(u["name"]), "name_lbl": name_lbl, "cost_lbl": cost_lbl, "btn": btn})
	return panel

func _refresh() -> void:
	if _meta == null:
		return
	_stone_lbl.text = "灵石 ×%d" % int(_meta.stones)
	for r in _rows:
		var id := str(r["id"])
		r["name_lbl"].text = "%s  Lv.%d" % [str(r["name"]), int(_meta.get_level(id))]
		if _meta.is_maxed(id):
			r["cost_lbl"].text = "已 圆 满"
			r["btn"].disabled = true
		else:
			r["cost_lbl"].text = "%d 灵石" % int(_meta.cost(id))
			r["btn"].disabled = not _meta.can_afford(id)

func _on_buy(id: String) -> void:
	if _meta and _meta.buy(id):
		Sfx.play("levelup", -4.0, 0.02)
		_refresh()
	else:
		Sfx.play("hurt", -8.0)

func _on_challenge() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().change_scene_to_file("res://mainscene.tscn")

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://main_menu.tscn")

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		_on_menu()

func _menu_button(text: String, width: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 48)
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1a1330")
	sb.set_border_width_all(2)
	sb.border_color = COL_GOLD
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color("2a1f4a")
	sbh.border_color = Color("ffe8a8")
	var sbd := sb.duplicate() as StyleBoxFlat
	sbd.bg_color = Color(0.10, 0.09, 0.14, 0.8)
	sbd.border_color = Color(0.4, 0.36, 0.46, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color("fff0c0"))
	b.add_theme_color_override("font_focus_color", Color("fff0c0"))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.56, 0.66))
	return b

func _label(text: String, size: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
