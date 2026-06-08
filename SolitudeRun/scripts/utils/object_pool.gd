class_name ObjectPool
extends Node
## 通用对象池。后续障碍物、提示特效、道路装饰可复用，避免频繁创建/销毁 Node。

var _scene: PackedScene
var _pool: Array[Node] = []

func configure(scene: PackedScene, initial_size: int = 0) -> void:
	_scene = scene
	for index in range(initial_size):
		var node := _scene.instantiate()
		node.process_mode = Node.PROCESS_MODE_DISABLED
		_pool.append(node)

func acquire() -> Node:
	if _pool.is_empty():
		return _scene.instantiate()
	var node := _pool.pop_back()
	node.process_mode = Node.PROCESS_MODE_INHERIT
	return node

func release(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_pool.append(node)
