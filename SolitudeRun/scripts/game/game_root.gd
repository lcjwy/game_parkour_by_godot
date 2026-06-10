extends Node3D

const INACTIVITY_FAIL_SECONDS: float = 60.0
const INACTIVITY_WARNING_SECONDS: float = 10.0
const ONE_HOUR_SECONDS: float = 3600.0
const TWO_AND_HALF_HOURS_SECONDS: float = 9000.0
const COUNTDOWN_SECONDS: float = 3.0
const GO_PROMPT_SECONDS: float = 0.75

var _map_config: MapConfig
var _road: RoadGenerator
var _car: CarController
var _weather: WeatherSystem
var _camera: Camera3D
var _environment: WorldEnvironment
var _env: Environment
var _scene_light: DirectionalLight3D
var _played_label: Label
var _toast_label: Label
var _countdown_label: Label
var _modal: PanelContainer
var _modal_text: RichTextLabel
var _elapsed: float = 0.0
var _start_prompt_remaining: float = COUNTDOWN_SECONDS + GO_PROMPT_SECONDS
var _last_input_elapsed: float = 0.0
var _focus_lost_ticks_msec: int = -1
var _running: bool = false
var _countdown_active: bool = true
var _one_hour_shown: bool = false
var _two_half_hours_shown: bool = false
var _inactivity_warning_shown: bool = false
var _toast_hide_time: float = 0.0

func _ready() -> void:
	_map_config = GameState.selected_map()
	AudioManager.set_preset(GameState.selected_audio_preset())
	_build_world()
	_build_hud()
	GameState.start_run()
	_running = true
	_countdown_active = true
	_start_prompt_remaining = COUNTDOWN_SECONDS + GO_PROMPT_SECONDS
	_last_input_elapsed = 0.0

func _notification(what: int) -> void:
	if not _running or _countdown_active:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_lost_ticks_msec = Time.get_ticks_msec()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		var focus_lost_seconds := _focus_lost_seconds()
		_focus_lost_ticks_msec = -1
		if focus_lost_seconds >= INACTIVITY_FAIL_SECONDS:
			_fail_run()
			return
		_last_input_elapsed = _elapsed
		_inactivity_warning_shown = false

func _physics_process(delta: float) -> void:
	if not _running:
		return

	if _countdown_active:
		_update_start_prompt(delta)
		_weather.follow(_car.global_position)
		_update_camera(delta)
		_update_hud()
		return

	if not Input.is_action_pressed("accelerate"):
		_fail_run("result.released_accelerate")
		return

	_elapsed += delta
	GameState.update_elapsed(_elapsed)

	var had_input := _car.physics_step(delta, _road)
	if had_input:
		_last_input_elapsed = _elapsed
		_inactivity_warning_shown = false

	if _check_inactivity_failure():
		return

	_road.update_window(_car.distance_traveled)
	_weather.follow(_car.global_position)
	_update_camera(delta)
	_update_hud()
	_update_milestones()

	if _elapsed >= _map_config.target_duration_seconds:
		_complete_run()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _build_world() -> void:
	_environment = WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = _map_config.sky_color
	_env.fog_enabled = true
	_env.fog_light_color = _map_config.fog_color
	if _map_config.atmosphere == &"desert":
		_env.fog_density = 0.0045
	elif _map_config.weather_enabled:
		_env.fog_density = 0.018
	else:
		_env.fog_density = 0.0065
	_environment.environment = _env
	add_child(_environment)

	_scene_light = DirectionalLight3D.new()
	_scene_light.name = "SceneLight"
	if _map_config.atmosphere == &"desert":
		_scene_light.light_color = Color(1.0, 0.84, 0.56)
		_scene_light.light_energy = 3.0
	else:
		_scene_light.light_color = Color(0.86, 0.96, 0.76)
		_scene_light.light_energy = 1.85
	_scene_light.rotation_degrees = Vector3(-18.0, -38.0, 0.0)
	add_child(_scene_light)

	_road = RoadGenerator.new()
	add_child(_road)
	_road.configure(_map_config)

	_car = CarController.new()
	add_child(_car)

	_weather = WeatherSystem.new()
	add_child(_weather)
	_weather.configure(_map_config)

	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 68.0
	add_child(_camera)
	_update_camera(1.0)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	layer.add_child(margin)

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(root)

	_played_label = Label.new()
	_played_label.add_theme_font_size_override("font_size", 24)
	root.add_child(_played_label)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 28)
	_toast_label.visible = false
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	layer.add_child(_toast_label)

	_build_countdown_label(layer)
	_build_result_modal(layer)
	_update_hud()

func _build_result_modal(layer: CanvasLayer) -> void:
	_modal = PanelContainer.new()
	_modal.visible = false
	_modal.set_anchors_preset(Control.PRESET_CENTER)
	_modal.custom_minimum_size = Vector2(600, 260)
	layer.add_child(_modal)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	_modal.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	margin.add_child(root)

	_modal_text = RichTextLabel.new()
	_modal_text.custom_minimum_size = Vector2(540, 130)
	_modal_text.fit_content = true
	_modal_text.scroll_active = false
	root.add_child(_modal_text)

	var back_button := Button.new()
	back_button.text = TranslationService.text("result.back")
	back_button.custom_minimum_size = Vector2(180, 44)
	back_button.pressed.connect(_return_to_menu)
	root.add_child(back_button)

func _build_countdown_label(layer: CanvasLayer) -> void:
	_countdown_label = Label.new()
	_countdown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 124)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.38))
	_countdown_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.01))
	_countdown_label.add_theme_constant_override("outline_size", 12)
	layer.add_child(_countdown_label)
	_update_start_prompt(0.0)

func _update_camera(delta: float) -> void:
	var forward := _road.sample_tangent(_car.distance_traveled)
	var target := _car.global_position - forward * 9.0 + Vector3.UP * 5.2
	_camera.global_position = _camera.global_position.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
	_camera.look_at(_car.global_position + Vector3.UP * 1.1, Vector3.UP)

func _update_start_prompt(delta: float) -> void:
	_start_prompt_remaining = maxf(_start_prompt_remaining - delta, 0.0)
	if _start_prompt_remaining <= 0.0:
		_begin_driving()
		return
	if _countdown_label == null:
		return
	if _start_prompt_remaining > GO_PROMPT_SECONDS:
		var count_value := int(ceil(_start_prompt_remaining - GO_PROMPT_SECONDS))
		_countdown_label.text = str(clampi(count_value, 1, int(COUNTDOWN_SECONDS)))
	else:
		_countdown_label.text = "GO!!!"
	_countdown_label.visible = true

func _begin_driving() -> void:
	if not _countdown_active:
		return
	_countdown_active = false
	_last_input_elapsed = _elapsed
	if _countdown_label != null:
		_countdown_label.visible = false
	if not Input.is_action_pressed("accelerate"):
		_fail_run("result.released_accelerate")
		return
	AudioManager.play_preset(GameState.selected_audio_preset())

func _check_inactivity_failure() -> bool:
	var inactivity_elapsed := _current_inactivity_elapsed()
	var remaining_seconds := INACTIVITY_FAIL_SECONDS - inactivity_elapsed
	if remaining_seconds <= 0.0:
		_fail_run()
		return true
	if remaining_seconds <= INACTIVITY_WARNING_SECONDS and not _inactivity_warning_shown:
		_inactivity_warning_shown = true
		_show_toast(_inactivity_warning_message(), maxf(remaining_seconds, 1.0))
	return false

func _current_inactivity_elapsed() -> float:
	return maxf(_elapsed - _last_input_elapsed, _focus_lost_seconds())

func _focus_lost_seconds() -> float:
	if _focus_lost_ticks_msec < 0:
		return 0.0
	return float(Time.get_ticks_msec() - _focus_lost_ticks_msec) / 1000.0

func _inactivity_warning_message() -> String:
	match TranslationService.current_locale():
		"en":
			return "Keep driving, or this run will end soon."
		"ko":
			return "Keep driving, or this run will end soon."
		_:
			return "请继续驾驶，否则本局即将结束"

func _update_hud() -> void:
	_played_label.text = "%s %s" % [TranslationService.text("hud.played"), _format_elapsed(_elapsed)]
	if _toast_label.visible and _elapsed >= _toast_hide_time:
		_toast_label.visible = false

func _update_milestones() -> void:
	if not _one_hour_shown and _elapsed >= ONE_HOUR_SECONDS:
		_one_hour_shown = true
		_show_toast(TranslationService.text("toast.one_hour"), 8.0)
	if not _two_half_hours_shown and _elapsed >= TWO_AND_HALF_HOURS_SECONDS:
		_two_half_hours_shown = true
		_show_toast(TranslationService.text("toast.two_half_hours"), 10.0)

func _show_toast(message: String, duration: float) -> void:
	_toast_label.text = message
	_toast_label.visible = true
	_toast_hide_time = _elapsed + duration

func _fail_run(result_key: String = "result.failed") -> void:
	if not _running:
		return
	_running = false
	SaveManager.record_run(_elapsed)
	GameState.fail_run(result_key)
	_show_result(TranslationService.text(result_key))

func _complete_run() -> void:
	if not _running:
		return
	_running = false
	SaveManager.record_run(_elapsed)
	GameState.complete_run()
	_show_result(TranslationService.text("result.success"))

func _show_result(message: String) -> void:
	AudioManager.stop_playback()
	_modal_text.text = message
	_modal.visible = true

func _return_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _format_elapsed(seconds: float) -> String:
	var total_seconds := int(seconds)
	var hours := int(total_seconds / 3600)
	var minutes := int((total_seconds % 3600) / 60)
	var secs := total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]
