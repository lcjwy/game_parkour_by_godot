class_name RoadGenerator
extends Node3D
@export var visible_segments: int = 220
@export var segment_length: float = 12.0

const ROAD_COLUMNS: int = 6
const TERRAIN_COLUMNS: int = 26
const TERRAIN_ROW_STEP: int = 4
const TERRAIN_WIDTH: float = 900.0
const SAND_PATCH_INTERVAL: int = 5
const SAND_SHAPE_VARIANTS: int = 100
const RIDGE_INTERVAL: int = 12
const WINDOW_REBUILD_SEGMENTS: int = 16

var _config: MapConfig
var _mesh_instance: MeshInstance3D
var _sand_patch_instance: MeshInstance3D
var _ground_instance: MeshInstance3D
var _ridge_instance: MultiMeshInstance3D
var _road_material: StandardMaterial3D
var _sand_material: StandardMaterial3D
var _terrain_material: StandardMaterial3D
var _ridge_material: StandardMaterial3D
var _last_start_index: int = -999999
var _pending_start_distance: float = 0.0
var _pending_rebuild_step: int = -1

func _ready() -> void:
	set_process(false)

	_ground_instance = MeshInstance3D.new()
	_ground_instance.name = "Ground"
	add_child(_ground_instance)

	_ridge_instance = MultiMeshInstance3D.new()
	_ridge_instance.name = "DesertRidges"
	add_child(_ridge_instance)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "RoadMesh"
	add_child(_mesh_instance)

	_sand_patch_instance = MeshInstance3D.new()
	_sand_patch_instance.name = "RoadSandPatches"
	add_child(_sand_patch_instance)

func configure(config: MapConfig) -> void:
	_config = config
	_build_materials()
	update_window(0.0, true)

func update_window(player_distance: float, force: bool = false) -> void:
	if _config == null:
		return
	var start_index := int(floor(maxf(player_distance - 80.0, 0.0) / segment_length))
	if not force and abs(start_index - _last_start_index) < WINDOW_REBUILD_SEGMENTS:
		return
	_last_start_index = start_index
	var start_distance := float(start_index) * segment_length
	if force:
		_rebuild_all(start_distance)
		return
	_pending_start_distance = start_distance
	_pending_rebuild_step = 0
	set_process(true)

func _process(_delta: float) -> void:
	if _pending_rebuild_step < 0:
		set_process(false)
		return

	match _pending_rebuild_step:
		0:
			_rebuild_terrain(_pending_start_distance)
		1:
			_rebuild_ridges(_pending_start_distance)
		2:
			_rebuild_road_mesh(_pending_start_distance)
		3:
			_rebuild_sand_patches(_pending_start_distance)

	_pending_rebuild_step += 1
	if _pending_rebuild_step > 3:
		_pending_rebuild_step = -1
		set_process(false)

func _rebuild_all(start_distance: float) -> void:
	_rebuild_terrain(start_distance)
	_rebuild_ridges(start_distance)
	_rebuild_road_mesh(start_distance)
	_rebuild_sand_patches(start_distance)

func road_position(distance: float, lateral_offset: float) -> Vector3:
	var position := sample_center(distance) + sample_right(distance) * lateral_offset
	position.y = _road_height(distance, lateral_offset)
	return position

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
	var colors := PackedColorArray()
	var half_width := _config.road_width * 0.5

	for row in range(visible_segments + 1):
		var distance := start_distance + float(row) * segment_length
		var center := sample_center(distance)
		var right := sample_right(distance)
		for column in range(ROAD_COLUMNS + 1):
			var lateral_ratio := float(column) / float(ROAD_COLUMNS)
			var lateral_offset := lerpf(-half_width, half_width, lateral_ratio)
			var position := center + right * lateral_offset
			position.y = _road_height(distance, lateral_offset)
			vertices.append(position)

			var edge_factor := absf(lateral_offset) / half_width
			var grain := sin(distance * 0.11 + lateral_offset * 1.7) * 0.5 + 0.5
			var color := _config.road_color.lightened(0.05 + grain * 0.06).darkened(edge_factor * 0.12)
			colors.append(color)

	var row_width := ROAD_COLUMNS + 1
	for row in range(visible_segments):
		for column in range(ROAD_COLUMNS):
			var base := row * row_width + column
			indices.append_array(PackedInt32Array([base, base + row_width, base + 1, base + 1, base + row_width, base + row_width + 1]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = _road_material

func _rebuild_sand_patches(start_distance: float) -> void:
	if _config.atmosphere != &"desert":
		_sand_patch_instance.mesh = null
		return

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var start_index := int(round(start_distance / segment_length))
	var patch_count := int(visible_segments / SAND_PATCH_INTERVAL)
	var half_width := _config.road_width * 0.5

	for patch in range(patch_count):
		var seed: int = start_index + patch * SAND_PATCH_INTERVAL
		if _hash01(seed, 4) < 0.26:
			continue
		var distance: float = start_distance + float(patch * SAND_PATCH_INTERVAL) * segment_length + lerpf(-4.0, 4.0, _hash01(seed, 5))
		var lateral_offset: float = lerpf(-half_width * 0.62, half_width * 0.62, _hash01(seed, 6))
		var patch_width: float = lerpf(1.2, 4.2, _hash01(seed, 7))
		var patch_length: float = lerpf(5.0, 16.0, _hash01(seed, 8))
		var shape_id: int = int(floor(_hash01(seed, 10) * float(SAND_SHAPE_VARIANTS)))
		_append_irregular_sand_patch(vertices, indices, distance, lateral_offset, patch_width, patch_length, shape_id, seed)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	if vertices.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_sand_patch_instance.mesh = mesh
	_sand_patch_instance.material_override = _sand_material

func _append_irregular_sand_patch(vertices: PackedVector3Array, indices: PackedInt32Array, distance: float, lateral_offset: float, patch_width: float, patch_length: float, shape_id: int, seed: int) -> void:
	var base: int = vertices.size()
	var center_position: Vector3 = sample_center(distance) + sample_right(distance) * lateral_offset
	center_position.y = _road_height(distance, lateral_offset) + 0.038
	vertices.append(center_position)

	var point_count: int = 6 + int(floor(_hash01(shape_id, 1) * 4.0))
	for point_index in range(point_count):
		var angle: float = TAU * float(point_index) / float(point_count)
		var wobble: float = lerpf(0.54, 1.16, _hash01(shape_id, 20 + point_index))
		var drift: float = lerpf(-0.22, 0.22, _hash01(seed, 40 + point_index))
		var local_distance: float = cos(angle) * patch_length * 0.5 * wobble + sin(angle * 2.0) * patch_length * drift
		var local_lateral: float = sin(angle) * patch_width * 0.5 * wobble + cos(angle * 3.0) * patch_width * drift
		var corner_distance: float = distance + local_distance
		var corner_lateral: float = lateral_offset + local_lateral
		var position: Vector3 = sample_center(corner_distance) + sample_right(corner_distance) * corner_lateral
		position.y = _road_height(corner_distance, corner_lateral) + 0.04
		vertices.append(position)

	for point_index in range(point_count):
		var current_index: int = base + 1 + point_index
		var next_index: int = base + 1 + ((point_index + 1) % point_count)
		indices.append_array(PackedInt32Array([base, current_index, next_index]))

func _rebuild_terrain(start_distance: float) -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var row_count := int(visible_segments / TERRAIN_ROW_STEP)
	var column_width := TERRAIN_WIDTH / float(TERRAIN_COLUMNS)

	for row in range(row_count + 1):
		var distance := start_distance + float(row * TERRAIN_ROW_STEP) * segment_length
		var center := sample_center(distance)
		var right := sample_right(distance)
		for column in range(TERRAIN_COLUMNS + 1):
			var lateral_offset := -TERRAIN_WIDTH * 0.5 + float(column) * column_width
			var position := center + right * lateral_offset
			position.y = _terrain_height(distance, lateral_offset)
			vertices.append(position)

	var row_width := TERRAIN_COLUMNS + 1
	for row in range(row_count):
		for column in range(TERRAIN_COLUMNS):
			var base := row * row_width + column
			indices.append_array(PackedInt32Array([base, base + row_width, base + 1, base + 1, base + row_width, base + row_width + 1]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ground_instance.mesh = mesh
	_ground_instance.material_override = _terrain_material

func _rebuild_ridges(start_distance: float) -> void:
	var ridge_mesh := SphereMesh.new()
	ridge_mesh.radius = 1.0
	ridge_mesh.height = 1.0
	ridge_mesh.radial_segments = 12
	ridge_mesh.rings = 6

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = ridge_mesh
	if _config.atmosphere != &"desert":
		multimesh.instance_count = 0
		_ridge_instance.multimesh = multimesh
		return

	var ridge_pairs := int(visible_segments / RIDGE_INTERVAL)
	multimesh.instance_count = ridge_pairs * 2
	var start_index := int(round(start_distance / segment_length))
	for pair in range(ridge_pairs):
		for side_index in range(2):
			var instance_index := pair * 2 + side_index
			var side := -1.0 if side_index == 0 else 1.0
			var seed := start_index + pair * RIDGE_INTERVAL + side_index * 97
			var distance := start_distance + float(pair * RIDGE_INTERVAL) * segment_length + lerpf(-28.0, 28.0, _hash01(seed, 1))
			var lateral_offset := side * lerpf(88.0, 390.0, _hash01(seed, 2))
			var position := sample_center(distance) + sample_right(distance) * lateral_offset
			position.y = _terrain_height(distance, lateral_offset) + lerpf(4.0, 14.0, _hash01(seed, 3))
			var scale := Vector3(
				lerpf(34.0, 96.0, _hash01(seed, 4)),
				lerpf(10.0, 34.0, _hash01(seed, 5)),
				lerpf(30.0, 92.0, _hash01(seed, 6))
			)
			var basis := Basis.IDENTITY.scaled(scale)
			multimesh.set_instance_transform(instance_index, Transform3D(basis, position))
	_ridge_instance.multimesh = multimesh
	_ridge_instance.material_override = _ridge_material

func _build_materials() -> void:
	_road_material = _material(_config.road_color, 0.96)
	_road_material.vertex_color_use_as_albedo = true
	_sand_material = _material(_config.ground_color.lightened(0.03), 0.98)
	_terrain_material = _material(_config.ground_color, 0.94)
	_ridge_material = _material(_config.ground_color.lightened(0.07), 0.96)

func _road_height(distance: float, lateral_offset: float) -> float:
	var half_width := 4.0
	if _config != null:
		half_width = _config.road_width * 0.5
	var edge_ratio := clampf(absf(lateral_offset) / half_width, 0.0, 1.0)
	var crown := (1.0 - edge_ratio * edge_ratio) * 0.16
	var grain := sin(distance * 0.085 + lateral_offset * 1.7) * 0.035 + sin(distance * 0.023) * 0.025
	return crown + grain

func _terrain_height(distance: float, lateral_offset: float) -> float:
	var road_clear := 5.0
	if _config != null:
		road_clear = _config.road_width * 0.72
	var distance_from_road := maxf(absf(lateral_offset) - road_clear, 0.0)
	var blend := clampf(distance_from_road / 140.0, 0.0, 1.0)
	var dune_height := sin(distance * 0.0048 + lateral_offset * 0.020) * 8.8
	dune_height += sin(distance * 0.0016 - lateral_offset * 0.010) * 15.0
	dune_height += sin(distance * 0.010 + lateral_offset * 0.006) * 3.2
	var atmosphere_scale := 1.0 if _config != null and _config.atmosphere == &"desert" else 0.18
	var side_lift := pow(blend, 1.25) * 18.0 * atmosphere_scale
	return -0.18 + (dune_height * blend + side_lift) * atmosphere_scale

func _hash01(seed_a: int, seed_b: int = 0) -> float:
	var value := sin(float(seed_a) * 12.9898 + float(seed_b) * 78.233) * 43758.5453
	return value - floor(value)

func _material(color: Color, roughness: float = 0.92) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
