class_name MapConfig
extends Resource
## 跑酷地图配置。地图表现通过数据驱动，便于后续扩展新地图。

@export var id: StringName = &"desert"
@export var display_key: String = "map.desert"
@export var description_key: String = "map.desert.desc"
@export var atmosphere: StringName = &"desert"
@export var target_duration_seconds: float = 10800.0
@export var road_width: float = 8.0
@export var road_color: Color = Color(0.22, 0.2, 0.18)
@export var ground_color: Color = Color(0.78, 0.56, 0.28)
@export var sky_color: Color = Color(0.95, 0.48, 0.22)
@export var fog_color: Color = Color(0.95, 0.68, 0.38)
@export var curve_strength: float = 34.0
@export var weather_enabled: bool = false
@export var marker_color: Color = Color(0.95, 0.86, 0.64)

