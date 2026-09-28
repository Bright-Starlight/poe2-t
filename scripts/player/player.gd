extends CharacterBody2D
class_name Player

## Player: 玩家核心角色控制器
## 包含移动、攻击判定、属性管理、技能系统与受击反馈

const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const CombatCalculatorClass = preload("res://scripts/combat/combat_calculator.gd")
const FloatingDamageNumberScene = preload("res://scenes/combat/floating_damage_number.tscn")
const SlashEffectScene = preload("res://scenes/combat/slash_effect.tscn")

# 基础属性
@export var max_hp: float = 200.0
var current_hp: float = 200.0
@export var max_mp: float = 100.0
var current_mp: float = 100.0

@export var move_speed: float = 150.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0

@export var attack_damage: float = 30.0
@export var attack_speed: float = 2.5 # 每秒攻击次数
@export var crit_rate: float = 0.20
@export var crit_damage: float = 1.6
@export var accuracy: float = 100.0
@export var armor: float = 12.0
@export var evasion: float = 15.0

var facing_direction: int = 1 # 1: 右, -1: 左
var input_direction: Vector2 = Vector2.ZERO
var attack_cooldown_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var invulnerable_timer: float = 0.0
var is_dead: bool = false

@onready var visuals: Node2D = $Visuals
@onready var camera: Camera2D = $Camera2D
@onready var attack_pivot: Node2D = $AttackPivot
@onready var hitbox_area: Area2D = $AttackPivot/HitboxArea
@onready var skill_controller: Node = $SkillController

func _ready() -> void:
	current_hp = max_hp
	current_mp = max_mp
	print("[Player] Player character spawned at: %s" % str(global_position))
	EventBus.player_spawned.emit(self)
	EventBus.player_health_changed.emit(current_hp, max_hp)
	EventBus.player_mana_changed.emit(current_mp, max_mp)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
	
	# 自然法力回复 (每秒 +5 MP)
	if current_mp < max_mp:
		current_mp = min(max_mp, current_mp + 5.0 * delta)
		EventBus.player_mana_changed.emit(current_mp, max_mp)
	
	_handle_movement(delta)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	
	if event.is_action_pressed("attack"):
		try_attack()
	elif event.is_action_pressed("skill_1") and skill_controller:
		skill_controller.cast_skill(0)
	elif event.is_action_pressed("skill_2") and skill_controller:
		skill_controller.cast_skill(1)
	elif event.is_action_pressed("skill_3") and skill_controller:
		skill_controller.cast_skill(2)

func _handle_movement(delta: float) -> void:
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_direction != Vector2.ZERO:
		velocity = velocity.move_toward(input_direction * move_speed, acceleration * delta)
		_update_facing(input_direction.x)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	# 叠加受击击退冲量并阻尼衰减
	if knockback_velocity != Vector2.ZERO:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 800.0 * delta)
	
	move_and_slide()

func _update_facing(dir_x: float) -> void:
	if dir_x > 0.05:
		facing_direction = 1
		visuals.scale.x = 1.0
		attack_pivot.scale.x = 1.0
	elif dir_x < -0.05:
		facing_direction = -1
		visuals.scale.x = -1.0
		attack_pivot.scale.x = -1.0

func try_attack() -> void:
	if attack_cooldown_timer > 0.0:
		return
	
	attack_cooldown_timer = 1.0 / max(0.1, attack_speed)
	
	# 播放挥砍特效
	var slash = SlashEffectScene.instantiate()
	attack_pivot.add_child(slash)
	slash.position = Vector2(16, 0)
	
	# 判定范围内的怪物
	var overlapping_bodies = hitbox_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("monsters") and body.has_method("take_damage"):
			var defender_stats = body.get_stats() if body.has_method("get_stats") else {}
			var dmg_info = CombatCalculatorClass.calculate_damage(get_stats(), defender_stats, self, body)
			body.take_damage(dmg_info)
			EventBus.combat_damage_dealt.emit({
				"attacker": "player",
				"target": body.get("monster_name") if "monster_name" in body else body.name,
				"amount": dmg_info.amount,
				"is_crit": dmg_info.is_crit
			})

func set_invulnerable(duration: float) -> void:
	invulnerable_timer = duration
	visuals.modulate.a = 0.5
	var tween = create_tween()
	tween.tween_property(visuals, "modulate:a", 1.0, duration)

func take_damage(damage_info: RefCounted) -> void:
	if is_dead or invulnerable_timer > 0.0:
		return
	
	_spawn_damage_number(damage_info)
	
	var is_miss = damage_info.get("is_miss") if "is_miss" in damage_info else false
	if is_miss:
		return
	
	var amount = float(damage_info.get("amount")) if "amount" in damage_info else 0.0
	var kb_dir = damage_info.get("knockback_dir") if "knockback_dir" in damage_info else Vector2.ZERO
	var kb_force = float(damage_info.get("knockback_force")) if "knockback_force" in damage_info else 120.0
	
	current_hp = max(0.0, current_hp - amount)
	EventBus.player_health_changed.emit(current_hp, max_hp)
	
	# 击退与闪红
	knockback_velocity = kb_dir * (kb_force * 0.7)
	_flash_hit()
	
	if current_hp <= 0:
		die()

func _flash_hit() -> void:
	visuals.modulate = Color(1.0, 0.4, 0.4, 1.0)
	var tween = create_tween()
	tween.tween_property(visuals, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)

func _spawn_damage_number(damage_info: RefCounted) -> void:
	var float_num = FloatingDamageNumberScene.instantiate()
	get_parent().add_child(float_num)
	float_num.global_position = global_position + Vector2(0, -20)
	float_num.setup(damage_info)

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	print("[Player] Player died!")
	EventBus.player_died.emit()
	visuals.modulate = Color(0.4, 0.4, 0.4, 0.8)

func get_stats() -> Dictionary:
	return {
		"attack_damage": attack_damage,
		"crit_rate": crit_rate,
		"crit_damage": crit_damage,
		"accuracy": accuracy,
		"armor": armor,
		"evasion": evasion,
		"knockback_force": 140.0
	}

func set_camera_limits(limits: Rect2) -> void:
	if camera:
		camera.limit_left = int(limits.position.x)
		camera.limit_top = int(limits.position.y)
		camera.limit_right = int(limits.position.x + limits.size.x)
		camera.limit_bottom = int(limits.position.y + limits.size.y)
