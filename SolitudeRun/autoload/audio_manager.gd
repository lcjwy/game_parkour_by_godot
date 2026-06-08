extends Node
## 使用 AudioStreamGenerator 生成三种默认环境音，占位但可直接运行。

const MIX_RATE: float = 22050.0

var _player: AudioStreamPlayer
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _preset: AudioPreset
var _phase: float = 0.0
var _pulse_phase: float = 0.0
var _noise_seed: int = 17

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_generator = AudioStreamGenerator.new()
	_generator.mix_rate = MIX_RATE
	_generator.buffer_length = 0.25
	_player.stream = _generator
	_player.bus = "Master"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	set_preset(GameState.selected_audio_preset())
	set_process(true)

func set_preset(preset: AudioPreset) -> void:
	_preset = preset
	if _player != null:
		_player.volume_db = preset.volume_db

func _process(_delta: float) -> void:
	if _playback == null or _preset == null:
		return
	var frames_available := _playback.get_frames_available()
	for frame_index in range(frames_available):
		var sample := _next_sample()
		_playback.push_frame(Vector2(sample, sample))

func _next_sample() -> float:
	_phase = fmod(_phase + TAU * _preset.frequency_hz / MIX_RATE, TAU)
	_pulse_phase = fmod(_pulse_phase + TAU * _preset.pulse_speed / MIX_RATE, TAU)
	_noise_seed = int((_noise_seed * 1103515245 + 12345) & 0x7fffffff)
	var noise := (float(_noise_seed % 2000) / 1000.0) - 1.0
	var pulse := 0.65 + sin(_pulse_phase) * 0.35
	var tone := sin(_phase) * (1.0 - _preset.noise_amount)
	return (tone + noise * _preset.noise_amount) * pulse * SettingsManager.sfx_volume * 0.25
