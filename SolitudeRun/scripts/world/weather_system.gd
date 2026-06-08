class_name WeatherSystem
extends Node3D
## 雨林天气与沙漠孤烟表现。粒子和灯光集中管理，避免散落到玩法脚本。

var _config: MapConfig
var _rain: GPUParticles3D
var _lightning: OmniLight3D
var _time: float = 0.0

func configure(config: MapConfig) -> void:
	_config = config
	_clear_children()
	if config.weather_enabled:
		_build_rain()
	else:
		_build_desert_smoke()
	set_process(true)

func follow(target_position: Vector3) -> void:
	global_position = target_position + Vector3(0.0, 12.0, -18.0)

func _process(delta: float) -> void:
	_time += delta
	if _lightning == null:
		return
	var flash := sin(_time * 0.75) > 0.985
	_lightning.light_energy = 3.5 if flash else 0.0

func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "RainParticles"
	_rain.amount = 900
	_rain.lifetime = 1.25
	_rain.visibility_aabb = AABB(Vector3(-48, -30, -48), Vector3(96, 60, 96))
	_rain.emitting = true

	var process_material := ParticleProcessMaterial.new()
	process_material.gravity = Vector3(0.0, -48.0, 0.0)
	process_material.initial_velocity_min = 24.0
	process_material.initial_velocity_max = 38.0
	process_material.spread = 10.0
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = Vector3(46.0, 8.0, 46.0)
	_rain.process_material = process_material

	var rain_mesh := BoxMesh.new()
	rain_mesh.size = Vector3(0.035, 0.72, 0.035)
	_rain.draw_pass_1 = rain_mesh
	add_child(_rain)

	_lightning = OmniLight3D.new()
	_lightning.name = "Lightning"
	_lightning.light_color = Color(0.65, 0.82, 1.0)
	_lightning.omni_range = 70.0
	_lightning.light_energy = 0.0
	add_child(_lightning)

func _build_desert_smoke() -> void:
	var smoke := GPUParticles3D.new()
	smoke.name = "LoneSmokeColumn"
	smoke.amount = 80
	smoke.lifetime = 5.0
	smoke.position = Vector3(22.0, 0.0, -130.0)
	smoke.visibility_aabb = AABB(Vector3(-12, 0, -12), Vector3(24, 45, 24))
	smoke.emitting = true

	var process_material := ParticleProcessMaterial.new()
	process_material.gravity = Vector3(0.0, 1.8, 0.0)
	process_material.initial_velocity_min = 0.9
	process_material.initial_velocity_max = 2.4
	process_material.spread = 18.0
	process_material.scale_min = 0.5
	process_material.scale_max = 1.4
	smoke.process_material = process_material

	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.55
	smoke_mesh.height = 0.7
	smoke.draw_pass_1 = smoke_mesh
	add_child(smoke)

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_rain = null
	_lightning = null

