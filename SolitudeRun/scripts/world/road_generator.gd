class_name RoadGenerator
extends Node3D
## 用单个 ArrayMesh 绘制可见道路，用 MultiMesh 批量绘制边缘标记，避免海量 Node。

@export var visible_segments: int = 220
@export var segment_length: float = 12.0

var _config: MapConfig
var _mesh_instance: MeshInstance3D
var _ground_instance: MeshInstance3D
var _marker_instance: MultiMeshInstance3D
var _last_start_index: int = -999999

func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "RoadMesh"
	add_child(_mesh_instance)

	_ground_instance = MeshInstance3D.new()
	_ground_instance.name = "Ground"
	add_child(_ground_instance)

	_marker_instance = MultiMeshInstance3D.new()
	_marker_instance.name = "RoadMarkers"
	add_child(_marker_instance)

func configure(config: MapConfig) -> void:
	_config = config
	_build_ground()
	update_window(0.0, true)

func update_window(player_distance: float, force: bool = false) -> void:
	if _config == null:
		return
	var start_index := int(floor(maxf(player_distance - 80.0, 0.0) / segment_length))
	if not force and abs(start_index - _last_start_index) < 3:
		return
	_last_start_index = start_index
	var start_distance := float(start_index) * segment_length
	_rebuild_road_mesh(start_distance)
	_rebuild_markers(start_distance)
	_update_ground(start_distance)

func road_position(distance: float, lateral_offset: float) -> Vector3:
	return sample_center(distance) + sample_right(distance) * lateral_offset

func sample_center(distance: float) -> Vector3:
	var strength := 24.0
	if _config != null:
		strength = _config.curve_strength
	var x := sin(distance * 0.008) * strength + sin(distance * 0.0022) * strength * 1.25
	return Vector3(x, 0.0, -distance)

func sample_tangent(distance: float) -> Vector3:
	var from := sample_center(distance)
	var to := sample_center(distance + 2.0)
	return (to - from).normalized()

func sample_right(distance: float) -> Vector3:
	return sample_tangent(distance).cross(Vector3.UP).normalized()

func _rebuild_road_mesh(start_distance: float) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var half_width := _config.road_width * 0.5

	for index in range(visible_segments + 1):
		var distance := start_distance + float(index) * segment_length
		var center := sample_center(distance)
		var right := sample_right(distance)
		vertices.append(center - right * half_width)
		vertices.append(center + right * half_width)

	for index in range(visible_segments):
		var base := index * 2
		indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = _material(_config.road_color)

func _rebuild_markers(start_distance: float) -> void:
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.25, 0.18, 1.6)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = marker_mesh
	var marker_pairs := int(visible_segments / 5)
	multimesh.instance_count = marker_pairs * 2

	var half_width := _config.road_width * 0.5 + 0.42
	for index in range(marker_pairs):
		var distance := start_distance + float(index * 5) * segment_length
		var center := sample_center(distance)
		var right := sample_right(distance)
		var tangent := sample_tangent(distance)
		var basis := Basis.looking_at(tangent, Vector3.UP)
		multimesh.set_instance_transform(index * 2, Transform3D(basis, center - right * half_width + Vector3.UP * 0.1))
		multimesh.set_instance_transform(index * 2 + 1, Transform3D(basis, center + right * half_width + Vector3.UP * 0.1))

	_marker_instance.multimesh = multimesh
	_marker_instance.material_override = _material(_config.marker_color)

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(560.0, 4200.0)
	_ground_instance.mesh = plane
	_ground_instance.material_override = _material(_config.ground_color)

func _update_ground(start_distance: float) -> void:
	var center_distance := start_distance + float(visible_segments) * segment_length * 0.5
	var center := sample_center(center_distance)
	_ground_instance.position = Vector3(center.x, -0.04, center.z)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material
