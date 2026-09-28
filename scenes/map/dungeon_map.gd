extends Node2D

## DungeonMap: 地牢地图管理与边界定义

@export var map_size: Vector2 = Vector2(1280, 720)
@onready var spawn_point: Marker2D = $SpawnPoint

func _ready() -> void:
	print("[DungeonMap] Loaded map size: %s, spawn position: %s" % [str(map_size), str(get_spawn_position())])

func get_spawn_position() -> Vector2:
	if spawn_point:
		return spawn_point.global_position
	return map_size / 2.0

func get_map_limits() -> Rect2:
	return Rect2(Vector2.ZERO, map_size)
