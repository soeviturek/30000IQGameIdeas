extends Node
# 全局音效管理（autoload 名 Sfx）：AudioStreamPlayer 池 + 随机微调音高，避免机械重复。
# 音源为程序化占位音（res://sfx/*.wav），后续可无痛替换为正式素材。

const POOL_SIZE := 12
const SFX_NAMES := ["attack", "hurt", "levelup", "kill", "victory", "defeat", "dash", "boss", "crit"]

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams := {}

func _ready() -> void:
	# 暂停时（升级/通关/阵亡）仍要能播放音效
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	for n in SFX_NAMES:
		var path := "res://sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)

func play(sfx_name: String, volume_db: float = 0.0, pitch_var: float = 0.1) -> void:
	if not _streams.has(sfx_name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = _streams[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
