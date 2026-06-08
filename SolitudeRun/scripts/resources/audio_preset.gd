class_name AudioPreset
extends Resource
## 程序化环境音配置，避免早期依赖外部音频素材。

@export var id: StringName = &"wind"
@export var display_key: String = "audio.wind"
@export_range(40.0, 1200.0, 1.0) var frequency_hz: float = 120.0
@export_range(0.0, 1.0, 0.01) var noise_amount: float = 0.35
@export_range(0.0, 12.0, 0.1) var pulse_speed: float = 0.8
@export_range(-36.0, 0.0, 0.5) var volume_db: float = -18.0

