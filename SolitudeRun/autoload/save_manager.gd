extends Node
## 预留存档服务：当前只记录最佳坚持时间，未来可扩展成成就/统计。

const SAVE_PATH: String = "user://run_stats.cfg"

var best_elapsed_seconds: float = 0.0

func _ready() -> void:
	load_stats()

func record_run(elapsed_seconds: float) -> void:
	best_elapsed_seconds = maxf(best_elapsed_seconds, elapsed_seconds)
	save_stats()

func save_stats() -> void:
	var config := ConfigFile.new()
	config.set_value("stats", "best_elapsed_seconds", best_elapsed_seconds)
	config.save(SAVE_PATH)

func load_stats() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	best_elapsed_seconds = float(config.get_value("stats", "best_elapsed_seconds", 0.0))

