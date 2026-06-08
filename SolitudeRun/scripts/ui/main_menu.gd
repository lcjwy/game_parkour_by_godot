extends Control
## 主菜单：地图选择、音效选择、设置页入口和启动游戏。

const MAP_PATHS: Array[String] = [
	"res://resources/maps/desert.tres",
	"res://resources/maps/jungle.tres"
]
const AUDIO_PATHS: Array[String] = [
	"res://resources/audio_presets/wind.tres",
	"res://resources/audio_presets/rain.tres",
	"res://resources/audio_presets/engine.tres"
]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080)
]

var _background: ColorRect
var _title_label: Label
var _map_label: Label
var _audio_label: Label
var _price_label: Label
var _description_label: RichTextLabel
var _map_option: OptionButton
var _audio_option: OptionButton
var _start_button: Button
var _settings_button: Button
var _settings_panel: PanelContainer
var _language_label: Label
var _resolution_label: Label
var _master_label: Label
var _sfx_label: Label
var _controller_label: Label
var _keybinds_label: Label
var _back_button: Button

func _ready() -> void:
	_build_layout()
	_populate_map_options()
	_populate_audio_options()
	TranslationService.locale_changed.connect(_refresh_text)
	_refresh_text()
	_refresh_selected_map()

func _build_layout() -> void:
	_background = ColorRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 56)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_right", 56)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 44)
	root.add_child(_title_label)

	_description_label = RichTextLabel.new()
	_description_label.custom_minimum_size = Vector2(720, 96)
	_description_label.fit_content = true
	_description_label.scroll_active = false
	root.add_child(_description_label)

	var map_row := _create_row()
	_map_label = map_row["label"] as Label
	_map_option = OptionButton.new()
	_map_option.custom_minimum_size = Vector2(260, 42)
	_map_option.item_selected.connect(_on_map_selected)
	(map_row["container"] as HBoxContainer).add_child(_map_option)
	root.add_child(map_row["container"] as HBoxContainer)

	var audio_row := _create_row()
	_audio_label = audio_row["label"] as Label
	_audio_option = OptionButton.new()
	_audio_option.custom_minimum_size = Vector2(260, 42)
	_audio_option.item_selected.connect(_on_audio_selected)
	(audio_row["container"] as HBoxContainer).add_child(_audio_option)
	root.add_child(audio_row["container"] as HBoxContainer)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	_start_button = Button.new()
	_start_button.custom_minimum_size = Vector2(180, 48)
	_start_button.pressed.connect(_start_game)
	button_row.add_child(_start_button)
	_settings_button = Button.new()
	_settings_button.custom_minimum_size = Vector2(180, 48)
	_settings_button.pressed.connect(_show_settings)
	button_row.add_child(_settings_button)
	root.add_child(button_row)

	_price_label = Label.new()
	root.add_child(_price_label)

	_build_settings_panel()

func _create_row() -> Dictionary:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.custom_minimum_size = Vector2(100, 42)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	container.add_child(label)
	return {"container": container, "label": label}

func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.visible = false
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(520, 430)
	add_child(_settings_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_settings_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var language_row := _create_row()
	_language_label = language_row["label"] as Label
	var language_option := OptionButton.new()
	language_option.add_item("中文", 0)
	language_option.set_item_metadata(0, "zh")
	language_option.add_item("English", 1)
	language_option.set_item_metadata(1, "en")
	language_option.add_item("한국어", 2)
	language_option.set_item_metadata(2, "ko")
	language_option.select(maxi(0, TranslationService.SUPPORTED_LOCALES.find(SettingsManager.locale)))
	language_option.item_selected.connect(func(index: int) -> void:
		SettingsManager.set_locale(str(language_option.get_item_metadata(index)))
	)
	(language_row["container"] as HBoxContainer).add_child(language_option)
	root.add_child(language_row["container"] as HBoxContainer)

	var resolution_row := _create_row()
	_resolution_label = resolution_row["label"] as Label
	var resolution_option := OptionButton.new()
	for index in range(RESOLUTIONS.size()):
		var size := RESOLUTIONS[index]
		resolution_option.add_item("%dx%d" % [size.x, size.y], index)
		resolution_option.set_item_metadata(index, size)
	resolution_option.select(maxi(0, RESOLUTIONS.find(SettingsManager.resolution)))
	resolution_option.item_selected.connect(func(index: int) -> void:
		var selected_resolution: Vector2i = resolution_option.get_item_metadata(index)
		SettingsManager.set_resolution(selected_resolution)
	)
	(resolution_row["container"] as HBoxContainer).add_child(resolution_option)
	root.add_child(resolution_row["container"] as HBoxContainer)

	_master_label = Label.new()
	root.add_child(_master_label)
	var master_slider := HSlider.new()
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.01
	master_slider.value = SettingsManager.master_volume
	master_slider.value_changed.connect(SettingsManager.set_master_volume)
	root.add_child(master_slider)

	_sfx_label = Label.new()
	root.add_child(_sfx_label)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.01
	sfx_slider.value = SettingsManager.sfx_volume
	sfx_slider.value_changed.connect(SettingsManager.set_sfx_volume)
	root.add_child(sfx_slider)

	var controller_row := _create_row()
	_controller_label = controller_row["label"] as Label
	var controller_check := CheckButton.new()
	controller_check.button_pressed = SettingsManager.controller_enabled
	controller_check.toggled.connect(SettingsManager.set_controller_enabled)
	(controller_row["container"] as HBoxContainer).add_child(controller_check)
	root.add_child(controller_row["container"] as HBoxContainer)

	_keybinds_label = Label.new()
	_keybinds_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_keybinds_label)

	_back_button = Button.new()
	_back_button.custom_minimum_size = Vector2(160, 44)
	_back_button.pressed.connect(func() -> void: _settings_panel.visible = false)
	root.add_child(_back_button)

func _populate_map_options() -> void:
	_map_option.clear()
	for index in range(MAP_PATHS.size()):
		var map_config := load(MAP_PATHS[index]) as MapConfig
		_map_option.add_item(TranslationService.text(map_config.display_key), index)
		_map_option.set_item_metadata(index, MAP_PATHS[index])

func _populate_audio_options() -> void:
	_audio_option.clear()
	for index in range(AUDIO_PATHS.size()):
		var preset := load(AUDIO_PATHS[index]) as AudioPreset
		_audio_option.add_item(TranslationService.text(preset.display_key), index)
		_audio_option.set_item_metadata(index, AUDIO_PATHS[index])

func _refresh_text() -> void:
	_title_label.text = TranslationService.text("game.title")
	_map_label.text = TranslationService.text("menu.map")
	_audio_label.text = TranslationService.text("menu.audio")
	_start_button.text = TranslationService.text("menu.start")
	_settings_button.text = TranslationService.text("menu.settings")
	_price_label.text = TranslationService.text("menu.price")
	_language_label.text = TranslationService.text("settings.language")
	_resolution_label.text = TranslationService.text("settings.resolution")
	_master_label.text = TranslationService.text("settings.master_volume")
	_sfx_label.text = TranslationService.text("settings.sfx_volume")
	_controller_label.text = TranslationService.text("settings.controller")
	_keybinds_label.text = "%s: %s" % [TranslationService.text("settings.keybinds"), SettingsManager.format_keybinds()]
	_back_button.text = TranslationService.text("settings.back")
	_populate_map_options()
	_populate_audio_options()
	_refresh_selected_map()

func _refresh_selected_map() -> void:
	if _map_option.item_count <= 0 or _map_option.selected < 0:
		return
	var map_path := str(_map_option.get_item_metadata(_map_option.selected))
	var map_config := load(map_path) as MapConfig
	_description_label.text = TranslationService.text(map_config.description_key)
	_background.color = map_config.sky_color.darkened(0.28)

func _on_map_selected(_index: int) -> void:
	_refresh_selected_map()

func _on_audio_selected(index: int) -> void:
	var preset := load(str(_audio_option.get_item_metadata(index))) as AudioPreset
	AudioManager.set_preset(preset)

func _show_settings() -> void:
	_settings_panel.visible = true

func _start_game() -> void:
	var map_path := str(_map_option.get_item_metadata(_map_option.selected))
	var audio_path := str(_audio_option.get_item_metadata(_audio_option.selected))
	GameState.set_selection(map_path, audio_path)
	AudioManager.set_preset(load(audio_path) as AudioPreset)
	get_tree().change_scene_to_file("res://scenes/game/game_root.tscn")
