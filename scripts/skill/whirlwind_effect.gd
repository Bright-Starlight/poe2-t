extends Node2D

## WhirlwindEffect: 旋风斩 360 度多段打击特效与判定

const CombatCalculatorClass = preload("res://scripts/combat/combat_calculator.gd")

var damage: float = 42.0
var radius: float = 40.0
var attacker: Node2D = null
var duration: float = 0.4
var elapsed: float = 0.0
var pulse_interval: float = 0.13
var pulse_timer: float = 0.0

@onready var spin_node: Node2D = $SpinNode

func setup(p_damage: float, p_attacker: Node2D) -> void:
	damage = p_damage
	attacker = p_attacker

func _ready() -> void:
	_execute_hit_pulse()

func _process(delta: float) -> void:
	elapsed += delta
	pulse_timer += delta
	
	if attacker and is_instance_valid(attacker):
		global_position = attacker.global_position
	
	if spin_node:
		spin_node.rotation += 22.0 * delta # 快速旋转
	
	if pulse_timer >= pulse_interval:
		pulse_timer -= pulse_interval
		_execute_hit_pulse()
	
	if elapsed >= duration:
		queue_free()

func _execute_hit_pulse() -> void:
	var tree = get_tree()
	if not tree:
		return
	
	var monsters = tree.get_nodes_in_group("monsters")
	for monster in monsters:
		if is_instance_valid(monster) and monster.has_method("take_damage"):
			var dist = global_position.distance_to(monster.global_position)
			if dist <= radius:
				var attacker_stats = {
					"attack_damage": damage,
					"crit_rate": 0.20,
					"crit_damage": 1.5,
					"accuracy": 110.0,
					"knockback_force": 90.0
				}
				var defender_stats = monster.get_stats() if monster.has_method("get_stats") else {}
				var dmg_info = CombatCalculatorClass.calculate_damage(attacker_stats, defender_stats, attacker, monster)
				monster.take_damage(dmg_info)
