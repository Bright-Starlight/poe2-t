extends Node2D

## SlashEffect: 近战挥砍弧光特效

var lifetime: float = 0.15
var elapsed: float = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	var progress = elapsed / lifetime
	scale = Vector2(1.0 + progress * 0.4, 1.0 + progress * 0.4)
	modulate.a = 1.0 - progress
	if elapsed >= lifetime:
		queue_free()
