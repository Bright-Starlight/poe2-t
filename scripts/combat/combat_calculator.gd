extends RefCounted
class_name CombatCalculator

## CombatCalculator: 纯数值战斗与伤害计算核心引擎
## 与场景解耦，保证算法纯净可测

static func calculate_damage(
	attacker_stats: Dictionary,
	defender_stats: Dictionary,
	attacker_node: Node2D = null,
	defender_node: Node2D = null
) -> DamageInfo:
	var hit_pos = defender_node.global_position if defender_node else Vector2.ZERO
	
	# 1. 闪避与命中判定 (Accuracy vs Evasion)
	var evasion = float(defender_stats.get("evasion", 0.0))
	var accuracy = float(attacker_stats.get("accuracy", 100.0))
	var hit_chance = clamp(accuracy / max(1.0, accuracy + evasion * 0.25), 0.2, 1.0)
	if randf() > hit_chance:
		return DamageInfo.create_miss(attacker_node, hit_pos)
	
	# 2. 基础伤害浮动 (90% ~ 110%)
	var base_dmg = float(attacker_stats.get("attack_damage", 10.0))
	var damage = base_dmg * randf_range(0.9, 1.1)
	
	# 3. 暴击判定 (Crit Rate & Multiplier)
	var crit_rate = float(attacker_stats.get("crit_rate", 0.05))
	var crit_multiplier = float(attacker_stats.get("crit_damage", 1.5))
	var is_crit = randf() <= crit_rate
	if is_crit:
		damage *= crit_multiplier
	
	# 4. 护甲减伤计算 (Diminishing Armor Reduction)
	var armor = float(defender_stats.get("armor", 0.0))
	var armor_reduction = armor / max(1.0, armor + damage * 5.0)
	armor_reduction = clamp(armor_reduction, 0.0, 0.8) # 护甲减伤上限 80%
	var final_damage = max(1.0, damage * (1.0 - armor_reduction))
	
	# 5. 计算击退冲量方向
	var kb_dir = Vector2.RIGHT
	var kb_force = float(attacker_stats.get("knockback_force", 120.0))
	if attacker_node and defender_node:
		var diff = defender_node.global_position - attacker_node.global_position
		if diff != Vector2.ZERO:
			kb_dir = diff.normalized()
	
	return DamageInfo.create(
		final_damage,
		"physical",
		is_crit,
		attacker_node,
		kb_dir,
		kb_force,
		hit_pos
	)
