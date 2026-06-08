extends Node
## 只保存跨场景状态，不承载具体玩法逻辑。

signal selection_changed
signal run_started(map_config: MapConfig)
signal run_failed(reason_key: String)
signal run_completed

const MAP_PATHS: Array[String] = [
	"res://resources/maps/desert.tres",
	"res://resources/maps/jungle.tres"
]
const AUDIO_PRESET_PATHS: Array[String] = [
	"res://resources/audio_presets/wind.tres",
	"res://resources/audio_presets/rain.tres",
	"res://resources/audio_presets/engine.tres"
]

var selected_map_path: String = MAP_PATHS[0]
var selected_audio_path: String = AUDIO_PRESET_PATHS[0]
var current_run_elapsed: float = 0.0

func set_selection(map_path: String, audio_path: String) -> void:
	selected_map_path = map_path
	selected_audio_path = audio_path
	selection_changed.emit()

func selected_map() -> MapConfig:
	return load(selected_map_path) as MapConfig

func selected_audio_preset() -> AudioPreset:
	return load(selected_audio_path) as AudioPreset

func start_run() -> void:
	current_run_elapsed = 0.0
	run_started.emit(selected_map())

func update_elapsed(value: float) -> void:
	current_run_elapsed = value

func fail_run(reason_key: String = "result.failed") -> void:
	run_failed.emit(reason_key)

func complete_run() -> void:
	run_completed.emit()

