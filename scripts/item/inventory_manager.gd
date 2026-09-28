extends Node

## InventoryManager: 装备栏、背包、属性点分配与角色总战斗属性管理器

signal inventory_updated
signal equipment_updated
signal gold_updated(gold: int)
signal exp_updated(cur_exp: int, max_exp: int, lvl: int)
signal level_up_occurred(new_lvl: int)
signal stat_points_updated(unspent: int, str_val: int, dex_val: int, int_val: int)

const MAX_BAG_CAPACITY: int = 30

var equipped_slots: Dictionary = {
	"weapon": null,
	"helmet": null,
	"chest": null,
	"gloves": null,
	"boots": null,
	"amulet": null,
	"ring": null
}

var bag_items: Array[Dictionary] = []
var gold: int = 50
var level: int = 1
var current_exp: int = 0
var max_exp: int = 100

# 自由属性点
var unspent_stat_points: int = 5
var allocated_strength: int = 0
var allocated_dexterity: int = 0
var allocated_intelligence: int = 0

# 基础白板人物属性
var base_player_stats: Dictionary = {
	"max_hp": 180.0,
	"max_mp": 100.0,
	"attack_damage": 22.0,
	"attack_speed": 1.2,
	"crit_rate": 0.05,
	"crit_damage": 1.5,
	"accuracy": 100.0,
	"armor": 8.0,
	"evasion": 10.0,
	"fire_damage": 0.0,
	"cold_damage": 0.0,
	"lightning_damage": 0.0,
	"fire_res": 0.0,
	"cold_res": 0.0,
	"lightning_res": 0.0,
	"all_res": 0.0,
	"move_speed_pct": 0.0,
	"strength": 0.0,
	"dexterity": 0.0,
	"intelligence": 0.0
}

func _ready() -> void:
	print("[InventoryManager] Initializing inventory and starter gear...")
	_give_starter_gear()

func _give_starter_gear() -> void:
	var starter_weapon = ItemGenerator.generate_random_item(1, "normal")
	equip_item(starter_weapon)
	
	var starter_chest = ItemGenerator.generate_random_item(1, "normal")
	equip_item(starter_chest)
	
	add_item_to_bag(ItemGenerator.generate_random_item(1, "magic"))
	add_item_to_bag(ItemGenerator.generate_random_item(1, "magic"))

func equip_item(item_data: Dictionary) -> bool:
	var slot = item_data.get("slot", "")
	if not equipped_slots.has(slot):
		return false
	
	var idx = bag_items.find(item_data)
	if idx != -1:
		bag_items.remove_at(idx)
	
	var old_item = equipped_slots[slot]
	if old_item != null:
		bag_items.append(old_item)
	
	equipped_slots[slot] = item_data
	equipment_updated.emit()
	inventory_updated.emit()
	EventBus.player_stats_changed.emit(get_total_player_stats())
	return true

func unequip_item(slot: String) -> bool:
	if not equipped_slots.has(slot) or equipped_slots[slot] == null:
		return false
	if bag_items.size() >= MAX_BAG_CAPACITY:
		return false
	
	var old_item = equipped_slots[slot]
	equipped_slots[slot] = null
	bag_items.append(old_item)
	
	equipment_updated.emit()
	inventory_updated.emit()
	EventBus.player_stats_changed.emit(get_total_player_stats())
	return true

func add_item_to_bag(item_data: Dictionary) -> bool:
	if bag_items.size() >= MAX_BAG_CAPACITY:
		return false
	bag_items.append(item_data)
	inventory_updated.emit()
	return true

func sell_item_at(index: int) -> void:
	if index < 0 or index >= bag_items.size():
		return
	var item = bag_items[index]
	var price = int(item.get("sell_price", 10))
	bag_items.remove_at(index)
	add_gold(price)
	inventory_updated.emit()

func sell_all_normal() -> int:
	var total_earned = 0
	var new_bag: Array[Dictionary] = []
	for it in bag_items:
		if it.get("rarity") == "normal":
			total_earned += int(it.get("sell_price", 10))
		else:
			new_bag.append(it)
	bag_items = new_bag
	add_gold(total_earned)
	inventory_updated.emit()
	return total_earned

func add_gold(amount: int) -> void:
	gold += amount
	gold_updated.emit(gold)
	EventBus.player_gold_changed.emit(gold)

func add_exp(amount: int) -> void:
	current_exp += amount
	while current_exp >= max_exp:
		current_exp -= max_exp
		level += 1
		max_exp = int(max_exp * 1.35)
		
		# 升级基础成长
		base_player_stats["max_hp"] += 20.0
		base_player_stats["max_mp"] += 8.0
		base_player_stats["attack_damage"] += 3.0
		
		# 升级赋予 3 点自由属性点 与 1 点天赋星盘点
		unspent_stat_points += 3
		stat_points_updated.emit(unspent_stat_points, allocated_strength, allocated_dexterity, allocated_intelligence)
		if is_instance_valid(TalentManager):
			TalentManager.add_talent_point(1)
		
		level_up_occurred.emit(level)
		EventBus.debug_log_emitted.emit("【升级突破!】恭喜升至 Lv.%d! 获得 +3 自由属性点, +1 天赋星盘点!" % level)
	
	exp_updated.emit(current_exp, max_exp, level)
	EventBus.player_exp_changed.emit(current_exp, max_exp, level)
	EventBus.player_stats_changed.emit(get_total_player_stats())

func allocate_stat(stat_type: String) -> bool:
	if unspent_stat_points <= 0:
		return false
	
	match stat_type:
		"strength":
			allocated_strength += 1
		"dexterity":
			allocated_dexterity += 1
		"intelligence":
			allocated_intelligence += 1
		_:
			return false
	
	unspent_stat_points -= 1
	stat_points_updated.emit(unspent_stat_points, allocated_strength, allocated_dexterity, allocated_intelligence)
	EventBus.player_stats_changed.emit(get_total_player_stats())
	return true

func reset_stats() -> void:
	var total_allocated = allocated_strength + allocated_dexterity + allocated_intelligence
	unspent_stat_points += total_allocated
	allocated_strength = 0
	allocated_dexterity = 0
	allocated_intelligence = 0
	stat_points_updated.emit(unspent_stat_points, allocated_strength, allocated_dexterity, allocated_intelligence)
	EventBus.player_stats_changed.emit(get_total_player_stats())

func get_total_player_stats() -> Dictionary:
	var stats = base_player_stats.duplicate(true)
	
	# 统计装备赋予的基础与复合属性
	var eq_str = 0.0
	var eq_dex = 0.0
	var eq_int = 0.0
	var eq_atk_pct = 0.0
	var eq_aspd_pct = 0.0
	
	for slot_name in equipped_slots.keys():
		var eq = equipped_slots[slot_name]
		if eq != null and eq.has("total_stats"):
			for st in eq["total_stats"].keys():
				var val = float(eq["total_stats"][st])
				if st == "strength":
					eq_str += val
				elif st == "dexterity":
					eq_dex += val
				elif st == "intelligence":
					eq_int += val
				elif st == "attack_damage_pct":
					eq_atk_pct += val
				elif st == "attack_speed_pct":
					eq_aspd_pct += val
				else:
					stats[st] = stats.get(st, 0.0) + val
	
	# 总属性点 (分配点数 + 装备提供)
	var total_s = allocated_strength + eq_str
	var total_d = allocated_dexterity + eq_dex
	var total_i = allocated_intelligence + eq_int
	stats["strength"] = total_s
	stats["dexterity"] = total_d
	stats["intelligence"] = total_i
	
	# 力量加成：每点 +5 最大生命, +0.6 基础攻击
	stats["max_hp"] += total_s * 5.0
	stats["attack_damage"] += total_s * 0.6
	
	# 敏捷加成：每点 +1.5 闪避, +0.01 攻速, +0.15% 暴击
	stats["evasion"] += total_d * 1.5
	stats["attack_speed"] += total_d * 0.01
	stats["crit_rate"] += total_d * 0.0015
	
	# 智力加成：每点 +4 最大法力, +0.6 火/冰/雷伤害
	stats["max_mp"] += total_i * 4.0
	stats["fire_damage"] += total_i * 0.6
	stats["cold_damage"] += total_i * 0.6
	stats["lightning_damage"] += total_i * 0.6
	
	# 全元素抗性合并到单一抗性中
	var all_res_val = float(stats.get("all_res", 0.0))
	stats["fire_res"] = float(stats.get("fire_res", 0.0)) + all_res_val
	stats["cold_res"] = float(stats.get("cold_res", 0.0)) + all_res_val
	stats["lightning_res"] = float(stats.get("lightning_res", 0.0)) + all_res_val
	
	# 装备百分比增伤/攻速
	stats["attack_damage"] = stats["attack_damage"] * (1.0 + eq_atk_pct)
	stats["attack_speed"] = stats["attack_speed"] * (1.0 + eq_aspd_pct)
	
	# 天赋星盘复合修正
	if is_instance_valid(TalentManager):
		var t_mods = TalentManager.get_aggregated_modifiers()
		stats["attack_damage"] = stats["attack_damage"] * (1.0 + t_mods.get("attack_damage_pct", 0.0))
		stats["attack_speed"] = stats["attack_speed"] * (1.0 + t_mods.get("attack_speed_pct", 0.0))
		stats["max_hp"] = stats["max_hp"] * (1.0 + t_mods.get("max_hp_pct", 0.0))
		stats["max_mp"] += t_mods.get("max_mp", 0.0)
		stats["armor"] = stats["armor"] * (1.0 + t_mods.get("armor_pct", 0.0))
		stats["evasion"] += t_mods.get("evasion", 0.0)
		stats["accuracy"] += t_mods.get("accuracy", 0.0)
		stats["crit_rate"] += t_mods.get("crit_rate", 0.0)
		stats["crit_damage"] += t_mods.get("crit_damage", 0.0)
		
		var elem_pct = t_mods.get("elemental_damage_pct", 0.0)
		stats["fire_damage"] = (stats["fire_damage"] + t_mods.get("fire_damage", 0.0)) * (1.0 + elem_pct)
		stats["cold_damage"] = (stats["cold_damage"] + t_mods.get("cold_damage", 0.0)) * (1.0 + elem_pct)
		stats["lightning_damage"] = (stats["lightning_damage"] + t_mods.get("lightning_damage", 0.0)) * (1.0 + elem_pct)
		
		# 特殊战斗机制与打宝加成
		stats["life_on_hit"] = t_mods.get("life_on_hit", 0.0)
		stats["ghost_dance_heal"] = t_mods.get("ghost_dance_heal", 0.0)
		stats["bleed_on_hit"] = t_mods.get("bleed_on_hit", 0)
		stats["shock_on_crit"] = t_mods.get("shock_on_crit", 0)
		stats["frenzy_charges"] = t_mods.get("frenzy_charges", 0)
		stats["gold_drop_mult"] = t_mods.get("gold_drop_mult", 0.0)
		stats["gear_drop_mult"] = t_mods.get("gear_drop_mult", 0.0)
		stats["currency_drop_mult"] = t_mods.get("currency_drop_mult", 0.0)
		stats["elite_damage_pct"] = t_mods.get("elite_damage_pct", 0.0)
	
	return stats
