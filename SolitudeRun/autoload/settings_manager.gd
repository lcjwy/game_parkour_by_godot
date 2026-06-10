extends Node
## 管理分辨率、音量、语言、键位与手柄输入映射。

signal settings_changed
signal locale_changed(locale: String)

const CONFIG_PATH: String = "user://settings.cfg"
const DEFAULT_RESOLUTION: Vector2i = Vector2i(1280, 720)

var locale: String = "zh"
var resolution: Vector2i = DEFAULT_RESOLUTION
var master_volume: float = 0.8
var sfx_volume: float = 0.8

func _ready() -> void:
	_load_settings()
	_ensure_input_map()
	_apply_window_settings()
	_apply_audio_settings()

func set_locale(value: String) -> void:
	if locale == value:
		return
	locale = value
	_save_settings()
	locale_changed.emit(locale)
	settings_changed.emit()

func set_resolution(value: Vector2i) -> void:
	resolution = value
	_apply_window_settings()
	_save_settings()
	settings_changed.emit()

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_save_settings()
	settings_changed.emit()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_save_settings()
	settings_changed.emit()

func format_keybinds() -> String:
	return "W: forward, Shift+W: 120% boost"

func _apply_window_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(resolution)

func _apply_audio_settings() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	locale = str(config.get_value("general", "locale", locale))
	resolution = config.get_value("display", "resolution", resolution)
	master_volume = float(config.get_value("audio", "master_volume", master_volume))
	sfx_volume = float(config.get_value("audio", "sfx_volume", sfx_volume))

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.set_value("display", "resolution", resolution)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(CONFIG_PATH)

func _ensure_input_map() -> void:
	_set_key_action(&"accelerate", KEY_W)
	_set_key_action(&"boost", KEY_SHIFT)
	_remove_action(&"brake")
	_remove_action(&"steer_left")
	_remove_action(&"steer_right")
	_set_confirm_actions()

func _set_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	else:
		InputMap.action_erase_events(action_name)
	_add_key_action(action_name, keycode)

func _set_confirm_actions() -> void:
	if not InputMap.has_action(&"confirm"):
		InputMap.add_action(&"confirm")
	else:
		InputMap.action_erase_events(&"confirm")
	_add_key_action(&"confirm", KEY_ENTER)
	_add_key_action(&"confirm", KEY_SPACE)

func _remove_action(action_name: StringName) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)

func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action_name, event)
