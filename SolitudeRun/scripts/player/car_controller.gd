class_name CarController
extends Node3D
## 第三视角小汽车控制器。只负责车辆运动和外观，不处理游戏胜负。

signal control_input_received

@export var speed_mps: float = 24.0
@export var lateral_speed: float = 7.5
@export var max_lateral_offset: float = 3.0

var distance_traveled: float = 0.0
var lateral_offset: float = 0.0

var _throttle: float = 0.0

func _ready() -> void:
	_build_vehicle_mesh()

func physics_step(delta: float, road: RoadGenerator) -> bool:
	var accelerate := Input.get_action_strength("accelerate")
	var brake := Input.get_action_strength("brake")
	var steer := Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
	var has_input := accelerate > 0.05 or brake > 0.05 or absf(steer) > 0.05
	if has_input:
		control_input_received.emit()

	_throttle = move_toward(_throttle, accelerate - brake * 0.75, delta * 1.8)
	var forward_factor := clampf(0.55 + maxf(_throttle, 0.0) * 0.55 - brake * 0.25, 0.25, 1.15)
	distance_traveled += speed_mps * forward_factor * delta
	lateral_offset = clampf(lateral_offset + steer * lateral_speed * delta, -max_lateral_offset, max_lateral_offset)

	var target_position := road.road_position(distance_traveled, lateral_offset)
	var tangent := road.sample_tangent(distance_traveled)
	global_position = target_position + Vector3.UP * 0.42
	look_at(global_position + tangent, Vector3.UP)
	return has_input

func _build_vehicle_mesh() -> void:
	var body_material := _material(Color(0.86, 0.12, 0.09))
	var cabin_material := _material(Color(0.08, 0.12, 0.16))
	var wheel_material := _material(Color(0.02, 0.02, 0.02))

	_add_box("Body", Vector3(2.1, 0.55, 3.6), Vector3(0.0, 0.35, 0.0), body_material)
	_add_box("Cabin", Vector3(1.45, 0.55, 1.4), Vector3(0.0, 0.82, -0.25), cabin_material)
	_add_box("FrontLeftWheel", Vector3(0.32, 0.45, 0.72), Vector3(-1.15, 0.18, -1.05), wheel_material)
	_add_box("FrontRightWheel", Vector3(0.32, 0.45, 0.72), Vector3(1.15, 0.18, -1.05), wheel_material)
	_add_box("RearLeftWheel", Vector3(0.32, 0.45, 0.72), Vector3(-1.15, 0.18, 1.05), wheel_material)
	_add_box("RearRightWheel", Vector3(0.32, 0.45, 0.72), Vector3(1.15, 0.18, 1.05), wheel_material)

func _add_box(node_name: String, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = position
	add_child(mesh_instance)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	return material

