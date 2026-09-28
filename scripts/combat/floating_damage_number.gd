extends Node2D

## FloatingDamageNumber: 像素风受击伤害跳字组件

const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")

@onready var label: Label = $Label

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 0.6
var elapsed: float = 0.0

func _ready() -> void:
	# 初始随机散布方向
	velocity = Vector2(randf_range(-20, 20), randf_range(-50, -70))

func setup(damage_info: RefCounted) -> void:
	if not label:
		label = $Label
	
	var is_miss = damage_info.get("is_miss") if "is_miss" in damage_info else false
	var is_crit = damage_info.get("is_crit") if "is_crit" in damage_info else false
	var amount = float(damage_info.get("amount")) if "amount" in damage_info else 0.0
	
	if is_miss:
		label.text = "闪避"
		label.modulate = Color(0.75, 0.75, 0.75, 1.0)
		scale = Vector2(0.85, 0.85)
	elif is_crit:
		label.text = "%d!" % round(amount)
		label.modulate = Color(1.0, 0.85, 0.15, 1.0)
		scale = Vector2(1.25, 1.25)
	else:
		label.text = "%d" % round(amount)
		label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		scale = Vector2(1.0, 1.0)

func _process(delta: float) -> void:
	elapsed += delta
	position += velocity * delta
	velocity.y += 80.0 * delta # 轻微重力阻尼
	
	# 渐变透明度
	var alpha = clamp(1.0 - (elapsed / lifetime), 0.0, 1.0)
	modulate.a = alpha
	
	if elapsed >= lifetime:
		queue_free()
