extends RefCounted
class_name DamageInfo

## DamageInfo: 伤害数据传递载体
## 封装攻击来源、伤害数值、属性类型、暴击状态与击退冲量

var amount: float = 0.0
var damage_type: String = "physical" # physical, fire, cold, lightning
var is_crit: bool = false
var is_miss: bool = false
var attacker: Node2D = null
var knockback_dir: Vector2 = Vector2.ZERO
var knockback_force: float = 120.0
var hit_position: Vector2 = Vector2.ZERO

static func create(
	p_amount: float,
	p_damage_type: String = "physical",
	p_is_crit: bool = false,
	p_attacker: Node2D = null,
	p_knockback_dir: Vector2 = Vector2.ZERO,
	p_knockback_force: float = 120.0,
	p_hit_position: Vector2 = Vector2.ZERO
) -> DamageInfo:
	var info = DamageInfo.new()
	info.amount = p_amount
	info.damage_type = p_damage_type
	info.is_crit = p_is_crit
	info.attacker = p_attacker
	info.knockback_dir = p_knockback_dir
	info.knockback_force = p_knockback_force
	info.hit_position = p_hit_position
	return info

static func create_miss(p_attacker: Node2D = null, p_hit_position: Vector2 = Vector2.ZERO) -> DamageInfo:
	var info = DamageInfo.new()
	info.is_miss = true
	info.amount = 0.0
	info.attacker = p_attacker
	info.hit_position = p_hit_position
	return info
