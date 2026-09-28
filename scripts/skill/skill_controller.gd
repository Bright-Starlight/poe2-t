extends Node
class_name SkillController

## SkillController: 玩家技能管理器
## 统一处理技能槽位映射、冷却计时、法力校验与技能实体生成

const FireballScene = preload("res://scenes/skill/fireball_projectile.tscn")
const WhirlwindScene = preload("res://scenes/skill/whirlwind_effect.tscn")

signal skill_cooldown_changed(slot_idx: int, remaining: float, total: float)
signal skill_cast_failed(reason: String)

@export var skill_slots: Array[String] = ["fireball", "whirlwind", "dash"]
var cooldown_timers: Dictionary = {}
var max_cooldowns: Dictionary = {}

var player: CharacterBody2D = null

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	_init_skills()

func _init_skills() -> void:
	for skill_id in skill_slots:
		var data = DataLoader.get_skill_data(skill_id)
		var cd = float(data.get("cooldown", 1.0))
		cooldown_timers[skill_id] = 0.0
		max_cooldowns[skill_id] = cd

func _process(delta: float) -> void:
	for i in range(skill_slots.size()):
		var s_id = skill_slots[i]
		if cooldown_timers[s_id] > 0.0:
			cooldown_timers[s_id] = max(0.0, cooldown_timers[s_id] - delta)
			skill_cooldown_changed.emit(i, cooldown_timers[s_id], max_cooldowns[s_id])

func cast_skill(slot_idx: int) -> bool:
	if not player or player.get("is_dead") == true:
		return false
	
	if slot_idx < 0 or slot_idx >= skill_slots.size():
		return false
	
	var skill_id = skill_slots[slot_idx]
	var data = DataLoader.get_skill_data(skill_id)
	if data.is_empty():
		return false
	
	# 1. 检查冷却
	if cooldown_timers[skill_id] > 0.0:
		skill_cast_failed.emit("冷却中 (%.1fs)" % cooldown_timers[skill_id])
		return false
	
	# 2. 检查法力值
	var mana_cost = float(data.get("mana_cost", 10.0))
	var player_mp = float(player.get("current_mp"))
	if player_mp < mana_cost:
		skill_cast_failed.emit("法力值不足 (%d/%d)" % [int(player_mp), int(mana_cost)])
		EventBus.debug_log_emitted.emit("【法力不足】无法释放 %s" % data.get("name_cn", ""))
		return false
	
	# 3. 扣除法力并重置冷却
	player.current_mp -= mana_cost
	EventBus.player_mana_changed.emit(player.current_mp, player.max_mp)
	var cd = float(data.get("cooldown", 1.0))
	cooldown_timers[skill_id] = cd
	max_cooldowns[skill_id] = cd
	skill_cooldown_changed.emit(slot_idx, cd, cd)
	
	# 4. 执行具体技能逻辑
	_execute_skill(skill_id, data)
	EventBus.debug_log_emitted.emit("释放技能：%s" % data.get("name_cn", ""))
	return true

func _execute_skill(skill_id: String, data: Dictionary) -> void:
	var base_atk = float(player.get("attack_damage")) if "attack_damage" in player else 25.0
	var mult = float(data.get("damage_multiplier", 1.0))
	var final_dmg = base_atk * mult
	
	match skill_id:
		"fireball":
			var fb = FireballScene.instantiate()
			player.get_parent().add_child(fb)
			fb.global_position = player.global_position
			var shoot_dir = Vector2.RIGHT * player.facing_direction
			if player.input_direction != Vector2.ZERO:
				shoot_dir = player.input_direction.normalized()
			fb.setup(shoot_dir, final_dmg, player)

		"whirlwind":
			var ww = WhirlwindScene.instantiate()
			player.get_parent().add_child(ww)
			ww.global_position = player.global_position
			ww.setup(final_dmg, player)

		"dash":
			var dash_dist = float(data.get("dash_distance", 100.0))
			var dash_dir = Vector2.RIGHT * player.facing_direction
			if player.input_direction != Vector2.ZERO:
				dash_dir = player.input_direction.normalized()
			
			# 瞬间位移冲刺
			player.velocity = dash_dir * 450.0
			# 开启短暂残影/无敌
			var invul_time = float(data.get("invulnerable_duration", 0.25))
			if player.has_method("set_invulnerable"):
				player.set_invulnerable(invul_time)
