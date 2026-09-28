extends Area2D

## FireballProjectile: 火球术远程投射物
## 飞行并在击中障碍物或怪物时触发范围火系爆炸

const CombatCalculatorClass = preload("res://scripts/combat/combat_calculator.gd")

var direction: Vector2 = Vector2.RIGHT
var speed: float = 260.0
var damage: float = 54.0
var aoe_radius: float = 34.0
var attacker: Node2D = null
var lifetime: float = 1.8
var elapsed: float = 0.0

@onready var visuals: Node2D = $Visuals

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()

func setup(p_direction: Vector2, p_damage: float, p_attacker: Node2D) -> void:
	direction = p_direction.normalized()
	damage = p_damage
	attacker = p_attacker
	if is_inside_tree():
		rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	elapsed += delta
	if elapsed >= lifetime:
		explode()

func _on_body_entered(body: Node2D) -> void:
	if body == attacker:
		return
	explode()

func explode() -> void:
	set_physics_process(false)
	# 范围爆炸判定
	var tree = get_tree()
	if tree:
		var monsters = tree.get_nodes_in_group("monsters")
		for monster in monsters:
			if is_instance_valid(monster) and monster.has_method("take_damage"):
				var dist = global_position.distance_to(monster.global_position)
				if dist <= aoe_radius:
					var attacker_stats = {
						"attack_damage": damage,
						"crit_rate": 0.25,
						"crit_damage": 1.75,
						"accuracy": 120.0,
						"knockback_force": 160.0
					}
					var defender_stats = monster.get_stats() if monster.has_method("get_stats") else {}
					var dmg_info = CombatCalculatorClass.calculate_damage(attacker_stats, defender_stats, attacker, monster)
					dmg_info.damage_type = "fire"
					monster.take_damage(dmg_info)
	
	# 播放爆炸缩放动画后销毁
	var tween = create_tween()
	tween.tween_property(visuals, "scale", Vector2(2.5, 2.5), 0.15)
	tween.parallel().tween_property(visuals, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
