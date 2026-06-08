extends Node3D
## 游戏主场景：三小时单局、不可暂停、离开操作失败、里程碑提示与结局弹窗。

const INACTIVITY_FAIL_SECONDS: float = 60.0
const INACTIVITY_WARNING_SECONDS: float = 10.0
const ONE_HOUR_SECONDS: float = 3600.0
const TWO_AND_HALF_HOURS_SECONDS: float = 9000.0
const DESERT_SKY_START: Color = Color(0.96, 0.46, 0.20)
const DESERT_SKY_END: Color = Color(0.42, 0.16, 0.10)
const DESERT_FOG_START: Color = Color(0.96, 0.67, 0.34)
const DESERT_FOG_END: Color = Color(0.58, 0.25, 0.14)
const DESERT_SUN_LIGHT_START: Color = Color(1.0, 0.76, 0.48)
const DESERT_SUN_LIGHT_END: Color = Color(1.0, 0.36, 0.16)

var _map_config: MapConfig
var _road: RoadGenerator
var _car: CarController
var _weather: WeatherSystem
var _camera: Camera3D
var _environment: WorldEnvironment
var _env: Environment
var _sun_light: DirectionalLight3D
var _sun_visual: MeshInstance3D
var _sun_material: StandardMaterial3D
var _played_label: Label
var _toast_label: Label
var _modal: PanelContainer
var _modal_text: RichTextLabel
var _elapsed: float = 0.0
var _last_input_elapsed: float = 0.0
var _focus_lost_ticks_msec: int = -1
var _running: bool = false
var _one_hour_shown: bool = false
var _two_half_hours_shown: bool = false
var _inactivity_warning_shown: bool = false
var _toast_hide_time: float = 0.0

func _ready() -> void:
	_map_config = GameState.selected_map()
	AudioManager.play_preset(GameState.selected_audio_preset())
	_build_world()
	_build_hud()
	GameState.start_run()
	_running = true
	_last_input_elapsed = 0.0

func _notification(what: int) -> void:
	if not _running:
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
	_update_sun_progress()
	_update_hud()
	_update_milestones()

	if _elapsed >= _map_config.target_duration_seconds:
		_complete_run()

func _unhandled_input(event: InputEvent) -> void:
	# 跑酷不能暂停；Esc/ui_cancel 不打开暂停菜单。
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _build_world() -> void:
	_environment = WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = _map_config.sky_color
	_env.fog_enabled = true
	_env.fog_light_color = _map_config.fog_color
	_env.fog_density = 0.018 if _map_config.weather_enabled else 0.009
	_environment.environment = _env
	add_child(_environment)

	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "LowSun"
	_sun_light.light_color = Color(1.0, 0.74, 0.46) if _map_config.atmosphere == &"desert" else Color(0.72, 0.88, 0.70)
	_sun_light.light_energy = 2.6 if _map_config.atmosphere == &"desert" else 1.4
	_sun_light.rotation_degrees = Vector3(-18.0, -38.0, 0.0)
	add_child(_sun_light)

	if _map_config.atmosphere == &"desert":
		_add_setting_sun()
		_update_sun_progress()

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

func _add_setting_sun() -> void:
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 12.0
	sun_mesh.height = 24.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.34, 0.12)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.28, 0.08)
	material.emission_energy_multiplier = 1.8

	_sun_material = material
	_sun_visual = MeshInstance3D.new()
	_sun_visual.name = "SettingSun"
	_sun_visual.mesh = sun_mesh
	_sun_visual.material_override = material
	_sun_visual.position = Vector3(-96.0, 34.0, -260.0)
	add_child(_sun_visual)

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

func _update_camera(delta: float) -> void:
	var forward := _road.sample_tangent(_car.distance_traveled)
	var target := _car.global_position - forward * 9.0 + Vector3.UP * 5.2
	_camera.global_position = _camera.global_position.lerp(target, clampf(delta * 4.0, 0.0, 1.0))
	_camera.look_at(_car.global_position + Vector3.UP * 1.1, Vector3.UP)

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
			return "계속 운전하지 않으면 곧 종료됩니다."
		_:
			return "请继续驾驶，否则本局即将结束"

func _update_sun_progress() -> void:
	if _map_config == null or _map_config.atmosphere != &"desert":
		return
	var progress := clampf(_elapsed / maxf(_map_config.target_duration_seconds, 1.0), 0.0, 1.0)
	var eased_progress := progress * progress * (3.0 - 2.0 * progress)
	if _sun_visual != null:
		var height := lerpf(44.0, 10.0, eased_progress)
		var distance_z := lerpf(-238.0, -306.0, eased_progress)
		_sun_visual.position = Vector3(-96.0, height, distance_z)
		_sun_visual.scale = Vector3.ONE * lerpf(0.92, 1.18, eased_progress)
	if _sun_material != null:
		_sun_material.albedo_color = DESERT_SUN_LIGHT_START.lerp(DESERT_SUN_LIGHT_END, eased_progress)
		_sun_material.emission = DESERT_SUN_LIGHT_START.lerp(DESERT_SUN_LIGHT_END, eased_progress)
		_sun_material.emission_energy_multiplier = lerpf(2.1, 1.1, eased_progress)
	if _sun_light != null:
		_sun_light.rotation_degrees = Vector3(lerpf(-25.0, -7.0, eased_progress), -38.0, 0.0)
		_sun_light.light_color = DESERT_SUN_LIGHT_START.lerp(DESERT_SUN_LIGHT_END, eased_progress)
		_sun_light.light_energy = lerpf(2.8, 1.1, eased_progress)
	if _env != null:
		_env.background_color = DESERT_SKY_START.lerp(DESERT_SKY_END, eased_progress)
		_env.fog_light_color = DESERT_FOG_START.lerp(DESERT_FOG_END, eased_progress)

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

func _fail_run() -> void:
	if not _running:
		return
	_running = false
	SaveManager.record_run(_elapsed)
	GameState.fail_run()
	_show_result(TranslationService.text("result.failed"))

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
