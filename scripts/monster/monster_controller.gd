extends CharacterBody2D
class_name MonsterController

## MonsterController: 怪物核心实体与 AI 状态机驱动
## 支持数据驱动、索敌追击、受击扣血闪红、伤害飘字、攻击玩家与死亡结算

const DamageInfoClass = preload("res://scripts/combat/damage_info.gd")
const CombatCalculatorClass = preload("res://scripts/combat/combat_calculator.gd")
const FloatingDamageNumberScene = preload("res://scenes/combat/floating_damage_number.tscn")

enum State {
	IDLE,
	WANDER,
	CHASE,
	IN_RANGE,
	RETURN,
	DEAD
}

@export var monster_id: String = "slime_green"

var state: State = State.IDLE
var spawn_position: Vector2 = Vector2.ZERO
var target_player: Node2D = null

# 从 JSON 数据中加载的属性
var monster_name: String = "怪物"
var max_hp: float = 100.0
var current_hp: float = 100.0
var move_speed: float = 80.0
var attack_damage: float = 10.0
var attack_range: float = 24.0
var attack_speed: float = 1.0 # 攻击间隔 ~1秒
var detection_range: float = 180.0
var leash_range: float = 300.0
var armor: float = 5.0
var evasion: float = 5.0
var exp_reward: int = 10
var gold_min: int = 1
var gold_max: int = 5

# AI 计时器
var state_timer: float = 0.0
var wander_target: Vector2 = Vector2.ZERO
var attack_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var visuals: Node2D = $Visuals
@onready var body_rect: ColorRect = $Visuals/Body
@onready var eye_rect: ColorRect = $Visuals/Eye
@onready var name_label: Label = $UI/NameLabel
@onready var health_bar: ProgressBar = $UI/HealthBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	spawn_position = global_position
	_load_config()
	_find_player()
	EventBus.monster_spawned.emit(self)

func init_with_id(new_monster_id: String) -> void:
	monster_id = new_monster_id
	if is_inside_tree():
		_load_config()

func _load_config() -> void:
	var data = DataLoader.get_monster_data(monster_id)
	if data.is_empty():
		return
	
	monster_name = data.get("name_cn", "未知怪物")
	max_hp = float(data.get("max_hp", 100))
	current_hp = max_hp
	move_speed = float(data.get("move_speed", 80))
	attack_damage = float(data.get("attack_damage", 10))
	attack_range = float(data.get("attack_range", 24))
	detection_range = float(data.get("detection_range", 180))
	leash_range = float(data.get("leash_range", 300))
	armor = float(data.get("armor", 5))
	evasion = float(data.get("evasion", 5))
	exp_reward = int(data.get("exp_reward", 10))
	gold_min = int(data.get("gold_reward_min", 1))
	gold_max = int(data.get("gold_reward_max", 5))
	
	# 应用视觉配置
	if data.has("visual"):
		var v = data["visual"]
		if body_rect and v.has("color_body"):
			body_rect.color = Color(v["color_body"])
		if eye_rect and v.has("color_eye"):
			eye_rect.color = Color(v["color_eye"])
		if v.has("width") and v.has("height"):
			var w = float(v["width"])
			var h = float(v["height"])
			if body_rect:
				body_rect.size = Vector2(w, h)
				body_rect.position = Vector2(-w / 2.0, -h)
	
	_update_ui()

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	
	if not target_player or not is_instance_valid(target_player):
		_find_player()
	
	state_timer += delta
	if attack_timer > 0.0:
		attack_timer -= delta
	
	_update_ai(delta)
	
	# 叠加受击击退冲量并阻尼衰减
	if knockback_velocity != Vector2.ZERO:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	
	move_and_slide()
	_update_ui()

func _update_ai(delta: float) -> void:
	var dist_to_player = 9999.0
	if target_player:
		dist_to_player = global_position.distance_to(target_player.global_position)
	
	match state:
		State.IDLE:
			velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
			if dist_to_player <= detection_range:
				_change_state(State.CHASE)
			elif state_timer >= 2.0:
				_start_wander()

		State.WANDER:
			var to_target = wander_target - global_position
			if to_target.length() <= 8.0 or state_timer >= 3.0:
				_change_state(State.IDLE)
			else:
				velocity = velocity.move_toward(to_target.normalized() * (move_speed * 0.5), 600.0 * delta)
				_update_facing(velocity.x)
			
			if dist_to_player <= detection_range:
				_change_state(State.CHASE)

		State.CHASE:
			if dist_to_player > leash_range:
				_change_state(State.RETURN)
			elif dist_to_player <= attack_range:
				_change_state(State.IN_RANGE)
			else:
				var dir = (target_player.global_position - global_position).normalized()
				velocity = velocity.move_toward(dir * move_speed, 800.0 * delta)
				_update_facing(dir.x)

		State.IN_RANGE:
			velocity = velocity.move_toward(Vector2.ZERO, 800.0 * delta)
			if target_player:
				_update_facing(target_player.global_position.x - global_position.x)
				# 怪物攻击判定
				if attack_timer <= 0.0 and dist_to_player <= attack_range * 1.1:
					_attack_player()
			
			if dist_to_player > attack_range * 1.3:
				_change_state(State.CHASE)

		State.RETURN:
			var to_spawn = spawn_position - global_position
			if to_spawn.length() <= 8.0 or state_timer >= 5.0:
				_change_state(State.IDLE)
			else:
				velocity = velocity.move_toward(to_spawn.normalized() * (move_speed * 0.8), 600.0 * delta)
				_update_facing(velocity.x)
			
			if dist_to_player <= detection_range * 0.8:
				_change_state(State.CHASE)

func _attack_player() -> void:
	if not target_player or not target_player.has_method("take_damage"):
		return
	
	attack_timer = 1.0 / max(0.2, attack_speed)
	
	# 小幅度冲刺动画反馈
	var dir = (target_player.global_position - global_position).normalized()
	velocity = dir * 100.0
	
	var defender_stats = target_player.get_stats() if target_player.has_method("get_stats") else {}
	var dmg_info = CombatCalculatorClass.calculate_damage(get_stats(), defender_stats, self, target_player)
	target_player.take_damage(dmg_info)

func take_damage(damage_info: RefCounted) -> void:
	if state == State.DEAD:
		return
	
	_spawn_damage_number(damage_info)
	
	var is_miss = damage_info.get("is_miss") if "is_miss" in damage_info else false
	if is_miss:
		return
	
	var amount = float(damage_info.get("amount")) if "amount" in damage_info else 0.0
	var kb_dir = damage_info.get("knockback_dir") if "knockback_dir" in damage_info else Vector2.ZERO
	var kb_force = float(damage_info.get("knockback_force")) if "knockback_force" in damage_info else 100.0
	
	current_hp = max(0.0, current_hp - amount)
	
	# 击退与闪红
	knockback_velocity = kb_dir * kb_force
	_flash_hit()
	
	# 若受击时处于待机或游荡，立即转入追击
	if state == State.IDLE or state == State.WANDER or state == State.RETURN:
		_change_state(State.CHASE)
	
	if current_hp <= 0:
		die()

func _flash_hit() -> void:
	visuals.modulate = Color(1.0, 0.3, 0.3, 1.0)
	var tween = create_tween()
	tween.tween_property(visuals, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

func _spawn_damage_number(damage_info: RefCounted) -> void:
	var float_num = FloatingDamageNumberScene.instantiate()
	get_parent().add_child(float_num)
	float_num.global_position = global_position + Vector2(0, -18)
	float_num.setup(damage_info)

func die() -> void:
	_change_state(State.DEAD)
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	var reward = {
		"exp": exp_reward,
		"gold": randi_range(gold_min, gold_max),
		"monster_id": monster_id,
		"monster_name": monster_name,
		"position": global_position
	}
	EventBus.monster_died.emit(self, reward)
	
	# 播放死亡缩小淡出动画后释放
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.25).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(queue_free)

func _start_wander() -> void:
	var random_offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
	wander_target = spawn_position + random_offset
	_change_state(State.WANDER)

func _change_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_timer = 0.0

func _update_facing(dir_x: float) -> void:
	if dir_x > 0.1:
		visuals.scale.x = 1.0
	elif dir_x < -0.1:
		visuals.scale.x = -1.0

func _update_ui() -> void:
	if name_label:
		var state_str = ""
		match state:
			State.IDLE: state_str = "待机"
			State.WANDER: state_str = "巡视"
			State.CHASE: state_str = "追击"
			State.IN_RANGE: state_str = "攻击"
			State.RETURN: state_str = "返回"
			State.DEAD: state_str = "已阵亡"
		name_label.text = "%s [%s]" % [monster_name, state_str]
	
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

func get_stats() -> Dictionary:
	return {
		"attack_damage": attack_damage,
		"crit_rate": 0.05,
		"crit_damage": 1.5,
		"accuracy": 85.0,
		"armor": armor,
		"evasion": evasion,
		"knockback_force": 100.0
	}
