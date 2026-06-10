class_name CarController
extends Node3D
## 第三视角小汽车控制器。只负责车辆运动和外观，不处理游戏胜负。

signal control_input_received

const BOOST_MULTIPLIER: float = 1.2

@export var speed_mps: float = 24.0

var distance_traveled: float = 0.0
var lateral_offset: float = 0.0

func _ready() -> void:
	_build_vehicle_mesh()

func physics_step(delta: float, road: RoadGenerator) -> bool:
	var has_input := Input.is_action_pressed("accelerate")
	if has_input:
		control_input_received.emit()
		var boost_multiplier := BOOST_MULTIPLIER if Input.is_action_pressed("boost") else 1.0
		distance_traveled += speed_mps * boost_multiplier * delta
	place_on_road(road, distance_traveled)
	return has_input

func place_on_road(road: RoadGenerator, distance: float, lateral_offset_value: float = 0.0) -> void:
	distance_traveled = distance
	lateral_offset = lateral_offset_value
	var target_position := road.road_position(distance_traveled, lateral_offset)
	var tangent := road.sample_tangent(distance_traveled)
	global_position = target_position + Vector3.UP * 0.42
	look_at(global_position + tangent, Vector3.UP)

func _build_vehicle_mesh() -> void:
	var paint_material := _material(Color(0.78, 0.08, 0.06), 0.42)
	var glass_material := _material(Color(0.05, 0.10, 0.14), 0.18)
	var tire_material := _material(Color(0.015, 0.014, 0.013), 0.86)
	var hub_material := _material(Color(0.62, 0.64, 0.66), 0.32)
	var trim_material := _material(Color(0.03, 0.03, 0.035), 0.58)
	var headlight_material := _emissive_material(Color(1.0, 0.88, 0.58), 0.45)
	var tail_light_material := _emissive_material(Color(0.95, 0.04, 0.03), 0.35)

	_add_sedan_body(paint_material, trim_material)
	_add_windshield(glass_material)
	_add_wheel("FrontLeftWheel", Vector3(-1.12, 0.25, -1.26), tire_material, hub_material)
	_add_wheel("FrontRightWheel", Vector3(1.12, 0.25, -1.26), tire_material, hub_material)
	_add_wheel("RearLeftWheel", Vector3(-1.12, 0.25, 1.25), tire_material, hub_material)
	_add_wheel("RearRightWheel", Vector3(1.12, 0.25, 1.25), tire_material, hub_material)

	_add_box("LeftHeadlight", Vector3(0.46, 0.12, 0.08), Vector3(-0.52, 0.48, -2.08), headlight_material)
	_add_box("RightHeadlight", Vector3(0.46, 0.12, 0.08), Vector3(0.52, 0.48, -2.08), headlight_material)
	_add_box("LeftTailLight", Vector3(0.42, 0.13, 0.08), Vector3(-0.56, 0.45, 2.05), tail_light_material)
	_add_box("RightTailLight", Vector3(0.42, 0.13, 0.08), Vector3(0.56, 0.45, 2.05), tail_light_material)

func _add_sedan_body(paint_material: Material, trim_material: Material) -> void:
	_add_box("LowerBody", Vector3(2.18, 0.50, 3.95), Vector3(0.0, 0.46, 0.0), paint_material)
	_add_box("FrontHood", Vector3(1.86, 0.24, 1.12), Vector3(0.0, 0.80, -1.16), paint_material, Vector3(-4.0, 0.0, 0.0))
	_add_box("RearDeck", Vector3(1.84, 0.26, 1.02), Vector3(0.0, 0.78, 1.25), paint_material, Vector3(3.0, 0.0, 0.0))
	_add_box("FrontBumper", Vector3(2.02, 0.22, 0.20), Vector3(0.0, 0.34, -2.12), trim_material)
	_add_box("RearBumper", Vector3(2.02, 0.22, 0.20), Vector3(0.0, 0.34, 2.12), trim_material)
	_add_box("DoorLineLeft", Vector3(0.04, 0.36, 1.25), Vector3(-1.11, 0.62, 0.08), trim_material)
	_add_box("DoorLineRight", Vector3(0.04, 0.36, 1.25), Vector3(1.11, 0.62, 0.08), trim_material)

func _add_windshield(glass_material: Material) -> void:
	_add_box("CabinCore", Vector3(1.42, 0.56, 1.25), Vector3(0.0, 1.05, -0.02), glass_material)
	_add_box("Roof", Vector3(1.38, 0.16, 1.10), Vector3(0.0, 1.38, -0.02), glass_material)
	_add_box("FrontWindshield", Vector3(1.28, 0.08, 0.56), Vector3(0.0, 1.02, -0.77), glass_material, Vector3(-23.0, 0.0, 0.0))
	_add_box("RearWindshield", Vector3(1.24, 0.08, 0.54), Vector3(0.0, 1.00, 0.77), glass_material, Vector3(22.0, 0.0, 0.0))
	_add_box("LeftSideWindow", Vector3(0.08, 0.38, 0.92), Vector3(-0.76, 1.10, -0.02), glass_material)
	_add_box("RightSideWindow", Vector3(0.08, 0.38, 0.92), Vector3(0.76, 1.10, -0.02), glass_material)

func _add_wheel(node_name: String, position: Vector3, tire_material: Material, hub_material: Material) -> void:
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = 0.38
	tire_mesh.bottom_radius = 0.38
	tire_mesh.height = 0.34
	tire_mesh.radial_segments = 24

	var tire_instance := MeshInstance3D.new()
	tire_instance.name = node_name
	tire_instance.mesh = tire_mesh
	tire_instance.material_override = tire_material
	tire_instance.position = position
	tire_instance.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	add_child(tire_instance)

	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.18
	hub_mesh.bottom_radius = 0.18
	hub_mesh.height = 0.36
	hub_mesh.radial_segments = 18

	var hub_instance := MeshInstance3D.new()
	hub_instance.name = "%sHub" % node_name
	hub_instance.mesh = hub_mesh
	hub_instance.material_override = hub_material
	hub_instance.position = position
	hub_instance.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	add_child(hub_instance)

func _add_box(node_name: String, size: Vector3, position: Vector3, material: Material, rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	mesh_instance.rotation_degrees = rotation_degrees
	add_child(mesh_instance)
	return mesh_instance

func _material(color: Color, roughness: float = 0.78) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.35)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
