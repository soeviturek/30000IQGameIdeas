extends Control
# 大雷问道 · 合欢宫（局外·第四货币场所）
#   仙缘玉 → 街机老虎机抽卡：只出皮肤/CG/收藏（0 战力），无空抽 + 保底 + 重复转玉髓。
#   抽卡数据/逻辑全在 Meta（meta_progress.gd），本场景只负责演出 + 图鉴。
#   纯代码构建，沿用洞府（cave.gd）的 Theme/StyleBox/Tween 约定。

const COL_GOLD := Color("f0d98c")
const COL_TEXT := Color("eee0c8")
const COL_DIM := Color("c9a8d8")
const COL_ROSE := Color("ff8fb0")
const COL_CYAN := Color("bfe8ff")

# font.ttf 为中文字库（无 emoji），品阶符号改用主题汉字，杜绝豆腐块
const RSYM := {"N": "常", "R": "泳", "SR": "浴", "SSR": "升", "UR": "囍"}
const REEL_SYMS := ["常", "泳", "浴", "升", "囍"]

var _reels: Array = []
var _xy_lbl: Label
var _sui_lbl: Label
var _pity_lbl: Label
var _dex_lbl: Label
var _speak_lbl: Label
var _dex_grid: GridContainer
var _pull1_btn: Button
var _pull10_btn: Button
var _busy := false
var _overlay: Control = null

func _ready() -> void:
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
	dim.color = Color(0.10, 0.02, 0.10, 0.74)   # 合欢宫·暖紫夜色
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 64
	col.offset_right = -64
	col.offset_top = 26
	col.offset_bottom = -22
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	# —— 顶栏：标题 + 钱袋 ——
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	col.add_child(header)
	var title := _label("合 欢 宫", 44, COL_ROSE, HORIZONTAL_ALIGNMENT_LEFT)
	header.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_xy_lbl = _chip(header, "仙缘玉", COL_GOLD)
	_sui_lbl = _chip(header, "合欢玉髓", COL_CYAN)
	_pity_lbl = _chip(header, "距飞升", COL_ROSE)
	_dex_lbl = _chip(header, "合欢录", COL_TEXT)

	col.add_child(_label("仙缘玉 · 只换师姐皮相 · CG · 收藏 —— 永不换战力，抽到即赚，绝不后悔", 15, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	# —— 主体：左 老虎机 / 右 图鉴 ——
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	col.add_child(body)
	body.add_child(_build_slot_column())
	body.add_child(_build_dex_column())

	# —— 底栏 ——
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 18)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(footer)
	var back := _menu_button("返 回 洞 府", 220)
	back.pressed.connect(_on_back)
	footer.add_child(back)
	var demo := _menu_button("仙缘玉 +10（试玩·BOSS首杀）", 320)
	demo.pressed.connect(_on_demo_grant)
	footer.add_child(demo)

	_refresh()
	_rebuild_dex()
	_pull1_btn.grab_focus()

	# 标题呼吸辉光
	var tw := create_tween().set_loops()
	tw.tween_property(title, "modulate", Color(1.2, 1.0, 1.1, 1.0), 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "modulate", Color(0.85, 0.8, 0.85, 1.0), 1.3).set_trans(Tween.TRANS_SINE)

func _build_slot_column() -> Control:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_stretch_ratio = 0.92
	wrap.add_theme_constant_override("separation", 12)

	# 宫主立绘（占位）+ 台词
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	wrap.add_child(top)
	var ava := TextureRect.new()
	ava.custom_minimum_size = Vector2(150, 210)
	ava.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ava.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ava.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for cand in ["res://portraits/levelup_qingshan.png", "res://portraits/avatar_qingshan.png", "res://portraits/levelup_baiyi.png"]:
		if ResourceLoader.exists(cand):
			ava.texture = load(cand)
			break
	top.add_child(_frame(ava, COL_ROSE))
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 6)
	top.add_child(side)
	side.add_child(_label("宫主 · 妙音", 24, COL_ROSE, HORIZONTAL_ALIGNMENT_LEFT))
	side.add_child(_label("（立绘占位）", 13, COL_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	_speak_lbl = _label("公子今日手气如何？掷一把便知。", 18, COL_TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_speak_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speak_lbl.custom_minimum_size = Vector2(220, 0)
	side.add_child(_speak_lbl)

	# 老虎机三转轮
	var slot := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.04, 0.12, 0.9)
	sb.set_border_width_all(2)
	sb.border_color = COL_ROSE
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(16)
	slot.add_theme_stylebox_override("panel", sb)
	wrap.add_child(slot)
	var reels := HBoxContainer.new()
	reels.alignment = BoxContainer.ALIGNMENT_CENTER
	reels.add_theme_constant_override("separation", 16)
	slot.add_child(reels)
	_reels.clear()
	for i in range(3):
		var cell := _make_reel()
		reels.add_child(cell.get_meta("frame"))
		_reels.append(cell)

	# 抽卡按钮
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	wrap.add_child(btns)
	_pull1_btn = _menu_button("单 抽 · 1 玉", 220)
	_pull1_btn.pressed.connect(_do_pull.bind(1))
	btns.add_child(_pull1_btn)
	_pull10_btn = _menu_button("十 连 · 10 玉（保底浴衣+）", 320)
	_pull10_btn.pressed.connect(_do_pull.bind(10))
	btns.add_child(_pull10_btn)

	wrap.add_child(_label("第 10 掷保底「飞升形态」· 十连必得「浴衣」以上 · 重复自动折算玉髓", 14, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	return wrap

func _build_dex_column() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.08
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.12, 0.82)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.55, 0.4, 0.6, 0.7)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	vb.add_child(_label("合 欢 录 · 图鉴", 24, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	_dex_grid = GridContainer.new()
	_dex_grid.columns = 4
	_dex_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dex_grid.add_theme_constant_override("h_separation", 10)
	_dex_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_dex_grid)
	return panel

func _make_reel() -> Label:
	var l := Label.new()
	l.text = REEL_SYMS[randi() % REEL_SYMS.size()]
	l.add_theme_font_size_override("font_size", 74)
	l.add_theme_color_override("font_color", COL_GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(104, 128)
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.05, 0.95)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.7, 0.55, 0.3, 0.85)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", sb)
	frame.add_child(l)
	l.set_meta("frame", frame)
	return l

# —— 刷新 ——
func _refresh() -> void:
	_xy_lbl.text = "%d" % int(Meta.xianyu)
	_sui_lbl.text = "%d" % int(Meta.yusui)
	_pity_lbl.text = "%d" % int(Meta.pity_remaining())
	_dex_lbl.text = "%d / %d" % [int(Meta.owned_count()), int(Meta.pool_size())]
	if _pull1_btn:
		_pull1_btn.disabled = _busy or not Meta.can_pull(1)
		_pull10_btn.disabled = _busy or not Meta.can_pull(10)

func _rebuild_dex() -> void:
	if _dex_grid == null:
		return
	for c in _dex_grid.get_children():
		c.queue_free()
	for p in Meta.POOL:
		_dex_grid.add_child(_dex_card(p))

func _dex_card(p: Dictionary) -> Control:
	var id := str(p["id"])
	var ra := str(p["ra"])
	var cnt := int(Meta.dex_count(id))
	var owned := cnt > 0
	var mra: Dictionary = Meta.RA[ra]
	var rcol := Color(str(mra["col"]))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 130)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.08, 0.9) if owned else Color(0.04, 0.04, 0.05, 0.7)
	sb.set_border_width_all(2 if owned else 1)
	sb.border_color = rcol if owned else Color(0.3, 0.28, 0.34, 0.7)
	sb.set_corner_radius_all(9)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)

	var sym := _label(str(RSYM[ra]) if owned else "？", 40, rcol if owned else Color(0.4, 0.38, 0.44), HORIZONTAL_ALIGNMENT_CENTER)
	sym.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(sym)
	vb.add_child(_label("%s · %s" % [ra, str(mra["nm"])], 13, rcol if owned else COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var nm := _label(str(p["nm"]) if owned else "？？？", 15, COL_GOLD if owned else Color(0.45, 0.42, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(nm)
	if cnt > 1:
		vb.add_child(_label("×%d" % cnt, 14, COL_CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	return panel

# —— 抽卡演出 ——
func _do_pull(n: int) -> void:
	if _busy:
		return
	if not Meta.can_pull(n):
		_speak("仙缘玉不够 —— 去打 Boss、渡个劫再来。")
		Sfx.play("hurt", -8.0)
		return
	_busy = true
	_refresh()
	Sfx.play("dash", -3.0)
	var results: Array = Meta.pull(n)
	if results.is_empty():
		_busy = false
		_refresh()
		return
	var best_ra := _best_ra(results)
	await _spin_reels(str(RSYM[best_ra]))
	_refresh()
	_rebuild_dex()
	_reveal(results)   # 弹展示层；关闭时解锁按钮

func _spin_reels(final_sym: String) -> void:
	for i in range(16):
		for cell in _reels:
			cell.text = REEL_SYMS[randi() % REEL_SYMS.size()]
			cell.add_theme_color_override("font_color", COL_GOLD)
		Sfx.play("attack", -20.0, 0.3)
		await get_tree().create_timer(0.045).timeout
	for cell in _reels:
		cell.text = final_sym
		cell.add_theme_color_override("font_color", COL_ROSE)
		_pulse(cell)
		Sfx.play("kill", -9.0)
		await get_tree().create_timer(0.13).timeout

func _pulse(n: CanvasItem) -> void:
	var tw := create_tween()
	n.modulate = Color(1.7, 1.5, 1.2)
	tw.tween_property(n, "modulate", Color(1, 1, 1), 0.35)

func _reveal(results: Array) -> void:
	var best := _best_rank(results)
	if best >= 3:
		Sfx.play("victory", -2.0)
		Sfx.play("crit", -4.0)
		_speak("哎呀～这一相可遇不可求，公子好福气。")
	elif best >= 1:
		Sfx.play("levelup", -4.0)
		_speak("缘分到了，公子好眼力。")
	else:
		Sfx.play("kill", -9.0)
		_speak("先收着，慢慢就凑齐了。")

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var od := ColorRect.new()
	od.color = Color(0.02, 0.0, 0.04, 0.86)
	od.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	od.mouse_filter = Control.MOUSE_FILTER_STOP
	od.gui_input.connect(_on_overlay_input)
	_overlay.add_child(od)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	center.add_child(vb)
	var htxt := "十 连 · 缘 起" if results.size() >= 10 else "缘 起"
	vb.add_child(_label(htxt, 40, COL_ROSE, HORIZONTAL_ALIGNMENT_CENTER))

	var grid := GridContainer.new()
	grid.columns = mini(5, results.size())
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vb.add_child(grid)
	var cards: Array = []
	for res in results:
		var card := _reveal_card(res)
		grid.add_child(card)
		cards.append(card)

	vb.add_child(_label("点击任意处继续", 16, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	# 逐张淡入弹出
	for i in range(cards.size()):
		var c: Control = cards[i]
		c.modulate = Color(1, 1, 1, 0)
		var tw := create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(c, "modulate", Color(1, 1, 1, 1), 0.2)

func _reveal_card(res: Dictionary) -> Control:
	var it: Dictionary = res["it"]
	var ra := str(res["ra"])
	var mra: Dictionary = Meta.RA[ra]
	var rcol := Color(str(mra["col"]))
	var dupe := bool(res.get("dupe", false))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(158, 214)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.04, 0.10, 0.96)
	sb.set_border_width_all(3)
	sb.border_color = rcol
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	var sym := _label(str(RSYM[ra]), 62, rcol, HORIZONTAL_ALIGNMENT_CENTER)
	sym.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(sym)
	vb.add_child(_label("%s · %s" % [ra, str(mra["nm"])], 15, rcol, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(_label(str(it["who"]), 15, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var nm := _label(str(it["nm"]), 17, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(nm)
	if dupe:
		vb.add_child(_label("重复 · 玉髓 +%d" % int(res.get("sui", 0)), 14, COL_CYAN, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		vb.add_child(_label("NEW · 初 遇", 14, COL_ROSE, HORIZONTAL_ALIGNMENT_CENTER))
	return panel

func _on_overlay_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		_close_overlay()

func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	_busy = false
	_refresh()

func _best_ra(results: Array) -> String:
	var best := "N"
	var br := -1
	for r in results:
		var rk := int(Meta.RA[str(r["ra"])]["rank"])
		if rk > br:
			br = rk
			best = str(r["ra"])
	return best

func _best_rank(results: Array) -> int:
	var br := 0
	for r in results:
		br = maxi(br, int(Meta.RA[str(r["ra"])]["rank"]))
	return br

func _speak(t: String) -> void:
	if _speak_lbl:
		_speak_lbl.text = t

func _on_demo_grant() -> void:
	Meta.add_xianyu(10)
	Sfx.play("levelup", -5.0)
	_speak("又得了缘玉？来，掷一把。")
	_refresh()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://cave.tscn")

func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if _overlay != null:
		_close_overlay()
		return
	if key.keycode == KEY_ESCAPE:
		if not _busy:
			_on_back()

# —— UI 辅助（沿用 cave.gd 风格）——
func _chip(parent: HBoxContainer, name: String, val_col: Color) -> Label:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	box.add_child(_label(name, 13, COL_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	var v := _label("0", 26, val_col, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(v)
	return v

func _frame(inner: Control, border: Color) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.05, 0.9)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(4)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(inner)
	return p

func _menu_button(text: String, width: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 48)
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2a1030")
	sb.set_border_width_all(2)
	sb.border_color = COL_ROSE
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8)
	var sbh := sb.duplicate() as StyleBoxFlat
	sbh.bg_color = Color("451a4a")
	sbh.border_color = Color("ffc0d8")
	var sbd := sb.duplicate() as StyleBoxFlat
	sbd.bg_color = Color(0.12, 0.09, 0.14, 0.8)
	sbd.border_color = Color(0.4, 0.32, 0.4, 0.5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color("fff0f5"))
	b.add_theme_color_override("font_focus_color", Color("fff0f5"))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.54, 0.62))
	return b

func _label(text: String, size: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
