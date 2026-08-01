extends CanvasLayer
# 大雷问道 · HUD（纯代码构建）：顶栏 + 三选一升级 + 阵亡界面

const COL_BG := Color(0, 0, 0, 0.38)
const COL_GOLD := Color("f0d98c")
const COL_TEXT := Color("eee0c8")

# 升级立绘基准偏移（呼吸浮动/划入在此基础上叠加）
const AVA_L := 8.0
const AVA_R := 0.0
const AVA_T := 6.0
const AVA_B := 70.0
const AVA_SLIDE_PX := 240.0      # 划入距离（从左侧滑入）

# 造化（升级）池：id / 名称 / 稀有度 / 描述
const RARITY_COLORS := {
	"精良": Color("4a9cf0"),
	"稀有": Color("c060f0"),
	"进化": Color("f0c040"),
}
const UPGRADES := [
	{"id": "atk", "name": "惊鸿剑气", "rarity": "精良", "desc": "攻击力 +8"},
	{"id": "atk_mul", "name": "杀伐果决", "rarity": "稀有", "desc": "攻击力 +15%"},
	{"id": "atk_big", "name": "雷剑真解", "rarity": "进化", "desc": "攻击力 +20%\n攻击范围 +40"},
	{"id": "aspd", "name": "追风诀", "rarity": "稀有", "desc": "攻击冷却 -12%"},
	{"id": "spd", "name": "疾风步", "rarity": "精良", "desc": "移动速度 +12%"},
	{"id": "hp", "name": "罡气护体", "rarity": "精良", "desc": "气血上限 +40\n并立即回复"},
	{"id": "range", "name": "千里追魂", "rarity": "精良", "desc": "攻击范围 +60"},
	{"id": "heal", "name": "回春术", "rarity": "精良", "desc": "立即回复全部气血"},
	{"id": "crit", "name": "杀机毕现", "rarity": "稀有", "desc": "暴击率 +8%"},
	{"id": "crit_dmg", "name": "血溅七步", "rarity": "进化", "desc": "暴击伤害 +50%"},
	{"id": "qi", "name": "惊鸿剑气·凝", "rarity": "精良", "desc": "剑气 +1 道 · 剑伤 +10%\n(满3道 + 符箓术 → 化虹)"},
	{"id": "fulu", "name": "符箓术", "rarity": "稀有", "desc": "剑气附灵符\n(与惊鸿剑气凑齐则化虹)"},
]

# 升级弹窗角色台词（阶段4）：随机角色 + 台词，强化"角色在教你变强"的陪伴感
const LEVELUP_LINES := {
	"baiyi": [
		"挑一样趁手的，为姐看好你。",
		"稳扎稳打，招招要打实。",
		"这几路都不俗，看你悟性了。",
	],
	"qingshan": [
		"哟，又精进啦？可别骄傲~",
		"选个狠的，姐带你杀穿这片林子！",
		"磨蹭啥呢，妖都要笑你啦！",
	],
}

var _root: Control
var _timer_lbl: Label
var _kills_lbl: Label
var _level_lbl: Label
var _xp_bar: ProgressBar
var _levelup_root: Control
var _cards_box: BoxContainer
var _gameover_root: Control
var _victory_root: Control
var _boss_bar: ProgressBar
var _boss_name: Label
var _banner_lbl: Label
var _banner_time: float = 0.0
var _pending_levelups: int = 0
var _levelup_avatar: TextureRect
var _levelup_line: Label
var _levelup_quote: PanelContainer
var _ava_slide: float = 0.0      # 1=完全滑出屏幕左侧，0=归位
var _ava_bob_t: float = 0.0      # 呼吸浮动计时
var _ava_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	GameState.xp_changed.connect(_on_xp_changed)
	GameState.kills_changed.connect(_on_kills_changed)
	GameState.leveled_up.connect(_on_leveled_up)
	GameState.game_over_changed.connect(_on_game_over_changed)
	GameState.stage_cleared.connect(_on_stage_cleared)
	_on_xp_changed(GameState.xp, GameState.xp_to_next, GameState.level)
	_on_kills_changed(GameState.kills)
	call_deferred("_connect_director")

func _connect_director() -> void:
	var dir = get_tree().current_scene.get_node_or_null("MosnterSpawningPoint")
	if dir and dir.has_signal("announce"):
		dir.announce.connect(_show_banner)

func _build_ui() -> void:
	var theme := Theme.new()
	var font = load("res://font.ttf")
	if font:
		theme.default_font = font
	theme.default_font_size = 20

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)

	# 顶栏底色条
	var strip := ColorRect.new()
	strip.color = COL_BG
	_set_anchor(strip, 0, 0, 1, 0)
	_set_offset(strip, 0, 0, 0, 52)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(strip)

	# 章节（左）
	var chapter := _make_label("第一章 · 幽篁秘境", 20, COL_GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_set_anchor(chapter, 0, 0, 0, 0)
	_set_offset(chapter, 16, 12, 420, 44)
	_root.add_child(chapter)

	# 计时（中）
	_timer_lbl = _make_label("00:00", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchor(_timer_lbl, 0.5, 0, 0.5, 0)
	_set_offset(_timer_lbl, -120, 6, 120, 48)
	_root.add_child(_timer_lbl)

	# 击杀（右）
	_kills_lbl = _make_label("击杀 0", 22, Color("ff9c6c"), HORIZONTAL_ALIGNMENT_RIGHT)
	_set_anchor(_kills_lbl, 1, 0, 1, 0)
	_set_offset(_kills_lbl, -240, 12, -16, 44)
	_root.add_child(_kills_lbl)

	# 道行 Lv（中下）
	_level_lbl = _make_label("道行 Lv.1", 16, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchor(_level_lbl, 0.5, 0, 0.5, 0)
	_set_offset(_level_lbl, -120, 56, 120, 80)
	_root.add_child(_level_lbl)

	# 修为经验条
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.max_value = GameState.xp_to_next
	_xp_bar.value = GameState.xp
	_set_anchor(_xp_bar, 0.5, 0, 0.5, 0)
	_set_offset(_xp_bar, -180, 82, 180, 98)
	_style_xp_bar(_xp_bar)
	_root.add_child(_xp_bar)

	# 底部操作提示
	var hint := _make_label("方向键 / WASD 移动 · 自动攻击 · 升级时按 1/2/3 或点击卡牌选择造化", 15, Color("a89ac8"), HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchor(hint, 0, 1, 1, 1)
	_set_offset(hint, 0, -34, 0, -10)
	_root.add_child(hint)

	# 妖王名（关底 Boss 出现时显示）
	_boss_name = _make_label("噬魂法王", 18, Color("ff8a7a"), HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchor(_boss_name, 0.5, 0, 0.5, 0)
	_set_offset(_boss_name, -260, 104, 260, 128)
	_boss_name.visible = false
	_root.add_child(_boss_name)

	# 妖王血条
	_boss_bar = ProgressBar.new()
	_boss_bar.show_percentage = false
	_boss_bar.max_value = 100
	_boss_bar.value = 100
	_set_anchor(_boss_bar, 0.5, 0, 0.5, 0)
	_set_offset(_boss_bar, -280, 130, 280, 150)
	_style_boss_bar(_boss_bar)
	_boss_bar.visible = false
	_root.add_child(_boss_bar)

	# 波次横幅（居中大字，淡出）
	_banner_lbl = _make_label("", 46, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_set_anchor(_banner_lbl, 0.5, 0.30, 0.5, 0.30)
	_set_offset(_banner_lbl, -420, -40, 420, 40)
	_banner_lbl.visible = false
	_root.add_child(_banner_lbl)

	_build_levelup_panel()
	_build_gameover_panel()
	_build_victory_panel()

func _build_levelup_panel() -> void:
	_levelup_root = Control.new()
	_levelup_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_levelup_root.visible = false
	_root.add_child(_levelup_root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.70)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup_root.add_child(dim)

	# —— 左半屏：顶天立地大立绘（占据半边屏幕，突出美少女）——
	_levelup_avatar = TextureRect.new()
	_levelup_avatar.anchor_left = 0.0
	_levelup_avatar.anchor_top = 0.0
	_levelup_avatar.anchor_right = 0.52
	_levelup_avatar.anchor_bottom = 1.0
	_levelup_avatar.offset_left = AVA_L
	_levelup_avatar.offset_top = AVA_T
	_levelup_avatar.offset_right = AVA_R
	_levelup_avatar.offset_bottom = AVA_B
	_levelup_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_levelup_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_levelup_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_levelup_root.add_child(_levelup_avatar)

	# 立绘底部台词框（骚气点评）
	var quote_wrap := PanelContainer.new()
	quote_wrap.anchor_left = 0.0
	quote_wrap.anchor_right = 0.52
	quote_wrap.anchor_top = 1.0
	quote_wrap.anchor_bottom = 1.0
	quote_wrap.offset_left = 34
	quote_wrap.offset_right = -22
	quote_wrap.offset_top = -104
	quote_wrap.offset_bottom = -22
	quote_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var qsb := StyleBoxFlat.new()
	qsb.bg_color = Color(0.06, 0.03, 0.10, 0.72)
	qsb.set_corner_radius_all(12)
	qsb.set_content_margin_all(12)
	qsb.set_border_width_all(2)
	qsb.border_color = Color("d59bff")
	quote_wrap.add_theme_stylebox_override("panel", qsb)
	_levelup_root.add_child(quote_wrap)
	_levelup_quote = quote_wrap

	_levelup_line = _make_label("", 20, Color("ffe0f0"), HORIZONTAL_ALIGNMENT_CENTER)
	_levelup_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_levelup_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quote_wrap.add_child(_levelup_line)

	# —— 右半屏：标题 + 三选一（纵向卡片，给立绘让出半屏）——
	var right := VBoxContainer.new()
	right.anchor_left = 0.52
	right.anchor_right = 1.0
	right.anchor_top = 0.0
	right.anchor_bottom = 1.0
	right.offset_left = 24
	right.offset_right = -44
	right.offset_top = 40
	right.offset_bottom = -40
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 12)
	_levelup_root.add_child(right)

	var title := _make_label("选 择 造 化", 40, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	right.add_child(title)
	var sub := _make_label("— 道行提升 · 三选其一 —", 16, Color("c9b8e8"), HORIZONTAL_ALIGNMENT_CENTER)
	right.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	right.add_child(gap)

	_cards_box = VBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cards_box.add_theme_constant_override("separation", 14)
	right.add_child(_cards_box)

func _build_gameover_panel() -> void:
	_gameover_root = Control.new()
	_gameover_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameover_root.visible = false
	_root.add_child(_gameover_root)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameover_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameover_root.add_child(center)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	center.add_child(hbox)

	hbox.add_child(_make_portrait("res://portraits/baiyi_gameover.png"))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	hbox.add_child(vbox)

	var title := _make_label("道 陨", 56, Color("ff5c5c"), HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(title)
	_gameover_root.set_meta("summary", _make_label("", 22, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(_gameover_root.get_meta("summary"))
	var flavor := _make_label("“莫怕，回来歇口气，再战便是。”", 20, Color("ffd0d0"), HORIZONTAL_ALIGNMENT_CENTER)
	flavor.custom_minimum_size = Vector2(340, 0)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(flavor)
	var again := _make_label("按 R 重入秘境", 20, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(again)

func _build_victory_panel() -> void:
	_victory_root = Control.new()
	_victory_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_root.visible = false
	_root.add_child(_victory_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.06, 0.04, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_victory_root.add_child(center)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	center.add_child(hbox)

	hbox.add_child(_make_portrait("res://portraits/baiyi_victory.png"))

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	hbox.add_child(vbox)

	var title := _make_label("道 成 · 出 关", 56, Color("7be0a0"), HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(title)
	var sub := _make_label("— 第一章《幽篁秘境》通关 —", 18, Color("cfeadd"), HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(sub)
	_victory_root.set_meta("summary", _make_label("", 24, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(_victory_root.get_meta("summary"))
	var flavor := _make_label("“做得好，为姐没白教你。”", 20, Color("ffe9a8"), HORIZONTAL_ALIGNMENT_CENTER)
	flavor.custom_minimum_size = Vector2(340, 0)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(flavor)
	var again := _make_label("按 R 再入秘境", 20, COL_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vbox.add_child(again)

# ---------- 信号回调 ----------

func _process(delta: float) -> void:
	var total := int(GameState.elapsed)
	_timer_lbl.text = "%02d:%02d" % [total / 60, total % 60]
	_update_boss_bar()
	if _levelup_root and _levelup_root.visible:
		_ava_bob_t += delta
		_apply_avatar_transform()
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner_lbl.modulate.a = clamp(_banner_time / 0.7, 0.0, 1.0)
		if _banner_time <= 0.0:
			_banner_lbl.visible = false
	if (GameState.game_over or GameState.victory) and Input.is_action_just_pressed("restart"):
		_restart()

func _update_boss_bar() -> void:
	var boss: Node = null
	for b in get_tree().get_nodes_in_group("Boss"):
		if is_instance_valid(b):
			boss = b
			break
	if boss == null:
		if _boss_bar.visible:
			_boss_bar.visible = false
			_boss_name.visible = false
		return
	var hb = boss.health_bar
	if hb == null:
		return
	_boss_bar.max_value = hb.max_health
	_boss_bar.value = hb.current_health
	_boss_bar.visible = true
	_boss_name.visible = true

func _show_banner(text: String, color: Color) -> void:
	_banner_lbl.text = text
	_banner_lbl.add_theme_color_override("font_color", color)
	_banner_lbl.modulate.a = 1.0
	_banner_time = 2.4
	_banner_lbl.visible = true

func _on_stage_cleared(reward: int) -> void:
	Sfx.play("victory")
	var total := int(GameState.elapsed)
	var summary: Label = _victory_root.get_meta("summary")
	summary.text = "剿灭妖王 · 用时 %02d:%02d\n斩妖 %d · 道行 Lv.%d · 获得灵石 ×%d" % [total / 60, total % 60, GameState.kills, GameState.level, reward]
	_levelup_root.visible = false
	_victory_root.visible = true
	get_tree().paused = true

func _on_xp_changed(xp: int, xp_to_next: int, level: int) -> void:
	_xp_bar.max_value = xp_to_next
	_xp_bar.value = xp
	_level_lbl.text = "道行 Lv.%d" % level

func _on_kills_changed(kills: int) -> void:
	_kills_lbl.text = "击杀 %d" % kills

func _on_leveled_up(_level: int) -> void:
	Sfx.play("levelup")
	_pending_levelups += 1
	if not _levelup_root.visible:
		_show_next_choice()

func _on_game_over_changed(is_over: bool) -> void:
	if is_over:
		var total := int(GameState.elapsed)
		var summary: Label = _gameover_root.get_meta("summary")
		summary.text = "斩妖 %d · 存活 %02d:%02d · 道行 Lv.%d" % [GameState.kills, total / 60, total % 60, GameState.level]
		_gameover_root.visible = true
		get_tree().paused = true

# ---------- 三选一逻辑 ----------

func _show_next_choice() -> void:
	if _pending_levelups <= 0:
		_levelup_root.visible = false
		get_tree().paused = false
		return
	_pending_levelups -= 1
	for c in _cards_box.get_children():
		c.queue_free()
	var pool := UPGRADES.duplicate()
	pool.shuffle()
	var shown := []
	for i in range(min(3, pool.size())):
		shown.append(pool[i])
		_cards_box.add_child(_make_card(pool[i], i + 1))
	_set_levelup_speaker(shown)
	_levelup_root.visible = true
	_start_avatar_intro()
	get_tree().paused = true

func _set_ava_slide(v: float) -> void:
	_ava_slide = v
	_apply_avatar_transform()

func _apply_avatar_transform() -> void:
	if _levelup_avatar == null:
		return
	var slide_px := _ava_slide * -AVA_SLIDE_PX
	var bob := sin(_ava_bob_t * 1.6) * 7.0
	_levelup_avatar.offset_left = AVA_L + slide_px
	_levelup_avatar.offset_right = AVA_R + slide_px
	_levelup_avatar.offset_top = AVA_T + bob
	_levelup_avatar.offset_bottom = AVA_B + bob
	if _levelup_avatar.size.x > 1.0:
		_levelup_avatar.pivot_offset = _levelup_avatar.size * 0.5
	var s := 1.0 + sin(_ava_bob_t * 1.15 + 0.6) * 0.013
	_levelup_avatar.scale = Vector2(s, s)

func _start_avatar_intro() -> void:
	_ava_slide = 1.0
	_ava_bob_t = 0.0
	_levelup_avatar.modulate.a = 0.0
	_apply_avatar_transform()
	if _levelup_quote:
		_levelup_quote.modulate.a = 0.0
	if _ava_tween and _ava_tween.is_valid():
		_ava_tween.kill()
	_ava_tween = create_tween()
	_ava_tween.set_parallel(true)
	_ava_tween.tween_property(_levelup_avatar, "modulate:a", 1.0, 0.32)
	_ava_tween.tween_method(_set_ava_slide, 1.0, 0.0, 0.44) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _levelup_quote:
		_ava_tween.tween_property(_levelup_quote, "modulate:a", 1.0, 0.5) \
			.set_delay(0.18)

func _avatar_tex(who: String) -> Texture2D:
	# 优先放大半身立绘（升级面板左栏），无则回退头肩像
	var candidates := ["res://portraits/levelup_%s.png" % who, "res://portraits/avatar_%s.png" % who]
	for p in candidates:
		if ResourceLoader.exists(p):
			return load(p)
	return null

func _set_levelup_speaker(shown: Array) -> void:
	var who := ""
	var line := ""
	# 若本次三选一里出现"雷剑真解(进化)"，白衣仙子专属点评（呼应 review7 示例）
	var has_big := false
	for d in shown:
		if d.id == "atk_big":
			has_big = true
	if has_big:
		who = "baiyi"
		line = "雷剑真解…这招是为姐压箱底的，接住了。"
	else:
		who = ["baiyi", "qingshan"][randi() % 2]
		var arr: Array = LEVELUP_LINES[who]
		line = arr[randi() % arr.size()]
	if _levelup_avatar:
		_levelup_avatar.texture = _avatar_tex(who)
	if _levelup_line:
		_levelup_line.text = "「%s」" % line

func _make_card(data: Dictionary, index: int) -> Control:
	var rarity_col: Color = RARITY_COLORS.get(data.rarity, COL_GOLD)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 122)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("18122b")
	sb.set_border_width_all(3)
	sb.border_color = rarity_col
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	vb.add_child(head)
	var rarity := _make_label("【%s】" % data.rarity, 15, rarity_col, HORIZONTAL_ALIGNMENT_LEFT)
	head.add_child(rarity)
	var name_lbl := _make_label(data.name, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	head.add_child(name_lbl)

	var desc := _make_label(data.desc, 16, Color("c9bcd8"), HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(desc)

	var btn := Button.new()
	btn.text = "选择\n[%d]" % index
	btn.custom_minimum_size = Vector2(100, 0)
	btn.size_flags_vertical = Control.SIZE_FILL
	btn.pressed.connect(_on_pick.bind(data.id))
	hb.add_child(btn)
	return panel

func _input(event: InputEvent) -> void:
	if not _levelup_root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		if event.keycode == KEY_1: idx = 0
		elif event.keycode == KEY_2: idx = 1
		elif event.keycode == KEY_3: idx = 2
		if idx >= 0 and idx < _cards_box.get_child_count():
			var card := _cards_box.get_child(idx)
			var btn := card.get_child(0).get_child(card.get_child(0).get_child_count() - 1)
			if btn is Button:
				btn.emit_signal("pressed")

func _on_pick(upgrade_id: String) -> void:
	_apply_upgrade(upgrade_id)
	_show_next_choice()

# ---------- 造化生效 ----------

func _player() -> Node:
	return get_tree().current_scene.get_node_or_null("Player")

func _add_mod(stat: int, mtype: int, val: float) -> void:
	var p := _player()
	if p == null:
		return
	p.stats.add_modifier(Modifier.create(stat, mtype, val))
	if p.has_method("_on_stats_changed"):
		p._on_stats_changed()

func _sword() -> Node:
	var p := _player()
	return p.get_node_or_null("SlashWeapon") if p else null

func _sword_add_qi() -> void:
	var w := _sword()
	if w and w.has_method("add_qi_level"):
		w.add_qi_level()

func _sword_add_fulu() -> void:
	var w := _sword()
	if w and w.has_method("add_fulu"):
		w.add_fulu()

func _heal(amount: int) -> void:
	var p := _player()
	if p == null or p.health_bar == null:
		return
	var hb = p.health_bar
	if amount < 0:
		hb.set_health(hb.max_health)
	else:
		hb.set_health(min(hb.current_health + amount, hb.max_health))

# _scale_cooldown 已弃用：攻速统一走 ATTACK_SPEED modifier（weapon_stats.get_final_cooldown 里按 get_attack_speed() 缩放冷却）
func _scale_cooldown(_mult: float) -> void:
	pass

func _apply_upgrade(id: String) -> void:
	match id:
		"atk": _add_mod(Modifier.StatType.ATTACK_DAMAGE, Modifier.ModType.ADD, 8)
		"atk_mul": _add_mod(Modifier.StatType.ATTACK_DAMAGE, Modifier.ModType.MUL, 0.15)
		"atk_big":
			_add_mod(Modifier.StatType.ATTACK_DAMAGE, Modifier.ModType.MUL, 0.20)
			_add_mod(Modifier.StatType.ATTACK_RANGE, Modifier.ModType.ADD, 40)
		"spd": _add_mod(Modifier.StatType.MOVE_SPEED, Modifier.ModType.MUL, 0.12)
		"range": _add_mod(Modifier.StatType.ATTACK_RANGE, Modifier.ModType.ADD, 60)
		"hp":
			_add_mod(Modifier.StatType.MAX_HEALTH, Modifier.ModType.ADD, 40)
			_heal(40)
		"heal": _heal(-1)
		"aspd": _add_mod(Modifier.StatType.ATTACK_SPEED, Modifier.ModType.MUL, 0.12)
		"crit": _add_mod(Modifier.StatType.CRIT_CHANCE, Modifier.ModType.ADD, 0.08)
		"crit_dmg": _add_mod(Modifier.StatType.CRIT_DAMAGE, Modifier.ModType.ADD, 0.5)
		"qi": _sword_add_qi()
		"fulu": _sword_add_fulu()

func _restart() -> void:
	get_tree().paused = false
	_levelup_root.visible = false
	_gameover_root.visible = false
	_victory_root.visible = false
	_pending_levelups = 0
	GameState.reset()
	get_tree().reload_current_scene()

# ---------- 小工具 ----------

func _make_portrait(res_path: String) -> TextureRect:
	var tr := TextureRect.new()
	if ResourceLoader.exists(res_path):
		tr.texture = load(res_path)
	tr.custom_minimum_size = Vector2(420, 680)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _make_label(text: String, size: int, col: Color, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _style_xp_bar(bar: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("1a1522")
	bg.set_corner_radius_all(8)
	bg.set_border_width_all(2)
	bg.border_color = Color("4a3a2a")
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("6ad0f0")
	fg.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

func _style_boss_bar(bar: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("2a1414")
	bg.set_corner_radius_all(6)
	bg.set_border_width_all(2)
	bg.border_color = Color("6a2a2a")
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("e0463c")
	fg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

func _set_anchor(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b

func _set_offset(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b
