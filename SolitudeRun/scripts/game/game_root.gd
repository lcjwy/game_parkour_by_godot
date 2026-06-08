extends Node3D
## 游戏主场景：三小时单局、不可暂停、离开操作失败、里程碑提示与结局弹窗。

const INACTIVITY_FAIL_SECONDS: float = 8.0
const ONE_HOUR_SECONDS: float = 3600.0
const TWO_AND_HALF_HOURS_SECONDS: float = 9000.0

var _map_config: MapConfig
var _road: RoadGenerator
var _car: CarController
var _weather: WeatherSystem
var _camera: Camera3D
var _played_label: Label
var _toast_label: Label
var _modal: PanelContainer
var _modal_text: RichTextLabel
var _elapsed: float = 0.0
var _last_input_elapsed: float = 0.0
var _running: bool = false
var _one_hour_shown: bool = false
var _two_half_hours_shown: bool = false
var _toast_hide_time: float = 0.0

func _ready() -> void:
	_map_config = GameState.selected_map()
	AudioManager.set_preset(GameState.selected_audio_preset())
	_build_world()
	_build_hud()
	GameState.start_run()
	_running = true
	_last_input_elapsed = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _running:
		_fail_run()

func _physics_process(delta: float) -> void:
	if not _running:
		return

	_elapsed += delta
	GameState.update_elapsed(_elapsed)

	var had_input := _car.physics_step(delta, _road)
	if had_input:
		_last_input_elapsed = _elapsed

	if _elapsed - _last_input_elapsed > INACTIVITY_FAIL_SECONDS:
		_fail_run()
		return

	_road.update_window(_car.distance_traveled)
	_weather.follow(_car.global_position)
	_update_camera(delta)
	_update_hud()
	_update_milestones()

	if _elapsed >= _map_config.target_duration_seconds:
		_complete_run()

func _unhandled_input(event: InputEvent) -> void:
	# 跑酷不能暂停；Esc/ui_cancel 不打开暂停菜单。
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = _map_config.sky_color
	env.fog_enabled = true
	env.fog_light_color = _map_config.fog_color
	env.fog_density = 0.018 if _map_config.weather_enabled else 0.009
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.name = "LowSun"
	sun.light_color = Color(1.0, 0.74, 0.46) if _map_config.atmosphere == &"desert" else Color(0.72, 0.88, 0.70)
	sun.light_energy = 2.6 if _map_config.atmosphere == &"desert" else 1.4
	sun.rotation_degrees = Vector3(-18.0, -38.0, 0.0)
	add_child(sun)

	if _map_config.atmosphere == &"desert":
		_add_setting_sun()

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

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SettingSun"
	mesh_instance.mesh = sun_mesh
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(-96.0, 34.0, -260.0)
	add_child(mesh_instance)

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
