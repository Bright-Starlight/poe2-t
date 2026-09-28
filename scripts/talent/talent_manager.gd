extends Node

## TalentManager: PoE 风格被动天赋星盘管理器
## 驱动多分支被动天赋树加点、依赖拓扑校验、加成聚合与洗点重置

signal talents_updated(allocated_nodes: Array, unspent_points: int)

var unspent_talent_points: int = 2
var allocated_nodes: Array[String] = []

func _ready() -> void:
	print("[TalentManager] Initializing Passive Skill Tree System...")

func is_node_allocated(node_id: String) -> bool:
	return allocated_nodes.has(node_id)

func can_allocate_node(node_id: String) -> bool:
	if unspent_talent_points <= 0:
		return false
	if is_node_allocated(node_id):
		return false
	
	var node_info = _find_node_info(node_id)
	if node_info.is_empty():
		return false
	
	var reqs = node_info.get("req", [])
	for r in reqs:
		if not is_node_allocated(r):
			return false
	
	return true

func allocate_node(node_id: String) -> bool:
	if not can_allocate_node(node_id):
		return false
	
	allocated_nodes.append(node_id)
	unspent_talent_points -= 1
	
	talents_updated.emit(allocated_nodes, unspent_talent_points)
	EventBus.player_stats_changed.emit(InventoryManager.get_total_player_stats())
	return true

func reset_talents() -> void:
	unspent_talent_points += allocated_nodes.size()
	allocated_nodes.clear()
	
	talents_updated.emit(allocated_nodes, unspent_talent_points)
	EventBus.player_stats_changed.emit(InventoryManager.get_total_player_stats())

func add_talent_point(amount: int = 1) -> void:
	unspent_talent_points += amount
	talents_updated.emit(allocated_nodes, unspent_talent_points)

func _find_node_info(node_id: String) -> Dictionary:
	var tree = DataLoader.get_passive_tree_data()
	for branch_key in tree.keys():
		var nodes = tree[branch_key].get("nodes", [])
		for n in nodes:
			if n.get("id") == node_id:
				return n
	return {}

func get_aggregated_modifiers() -> Dictionary:
	var total_mods: Dictionary = {
		"attack_damage_pct": 0.0,
		"attack_speed_pct": 0.0,
		"max_hp_pct": 0.0,
		"max_mp": 0.0,
		"armor_pct": 0.0,
		"evasion": 0.0,
		"accuracy": 0.0,
		"crit_rate": 0.0,
		"crit_damage": 0.0,
		"fire_damage": 0.0,
		"cold_damage": 0.0,
		"lightning_damage": 0.0,
		"elemental_damage_pct": 0.0,
		"life_on_hit": 0.0,
		"ghost_dance_heal": 0.0,
		"bleed_on_hit": 0,
		"shock_on_crit": 0,
		"frenzy_charges": 0,
		"gold_drop_mult": 0.0,
		"gear_drop_mult": 0.0,
		"currency_drop_mult": 0.0,
		"elite_damage_pct": 0.0
	}
	
	var tree = DataLoader.get_passive_tree_data()
	for nid in allocated_nodes:
		var n_data = _find_node_info(nid)
		var mods = n_data.get("modifiers", {})
		for k in mods.keys():
			if total_mods.has(k):
				total_mods[k] += float(mods[k])
			else:
				total_mods[k] = float(mods[k])
	
	return total_mods
