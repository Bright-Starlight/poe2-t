extends RefCounted
class_name ItemGenerator

## ItemGenerator: PoE2 风格装备与 T 级 (T1~T5) 阶梯词缀生成器
## 支持 7 大部位底模匹配、物品等级(ilvl)门槛筛选、词缀族群(Family)互斥、3前3后词缀上限与数值 Roll 点

enum Rarity {
	NORMAL,
	MAGIC,
	RARE,
	LEGENDARY
}

const RARITY_COLORS = {
	"normal": "#ffffff",
	"magic": "#63b3ed",
	"rare": "#f6e05e",
	"legendary": "#ed8936"
}

const RARITY_NAMES_CN = {
	"normal": "普通",
	"magic": "魔法",
	"rare": "稀有",
	"legendary": "暗金"
}

const TIER_COLORS = {
	1: "#f6ad55", # T1 极品 (橙金色)
	2: "#f6e05e", # T2 高阶 (亮黄色)
	3: "#63b3ed", # T3 中阶 (冰蓝色)
	4: "#a0aec0", # T4 进阶 (银灰色)
	5: "#718096"  # T5 基础 (暗灰色)
}

static func generate_random_item(target_level: int = 1, force_rarity: String = "") -> Dictionary:
	var base_items = DataLoader.get_all_base_items()
	if base_items.is_empty():
		return {}
	
	# 1. 过滤适合当前等级的底模
	var suitable_keys = []
	for k in base_items.keys():
		var req_lvl = int(base_items[k].get("required_level", 1))
		if req_lvl <= target_level + 2:
			suitable_keys.append(k)
	
	if suitable_keys.is_empty():
		suitable_keys = base_items.keys()
	
	var base_id = suitable_keys[randi() % suitable_keys.size()]
	var base_item = base_items[base_id].duplicate(true)
	var slot = base_item.get("slot", "weapon")
	
	# 2. 决定稀有度
	var rarity_str = "normal"
	if force_rarity != "":
		rarity_str = force_rarity
	else:
		var roll = randf()
		if roll < 0.02:
			rarity_str = "legendary"
		elif roll < 0.18:
			rarity_str = "rare"
		elif roll < 0.50:
			rarity_str = "magic"
		else:
			rarity_str = "normal"
	
	# 3. 决定前缀和后缀数量 (PoE2 规范: 魔法1~2, 稀有3~6, 暗金4~6)
	var num_prefixes = 0
	var num_suffixes = 0
	match rarity_str:
		"normal":
			num_prefixes = 0
			num_suffixes = 0
		"magic":
			if randf() < 0.5:
				num_prefixes = 1
				num_suffixes = 1 if randf() < 0.5 else 0
			else:
				num_prefixes = 0
				num_suffixes = 1
		"rare":
			# PoE2 风格: 稀有装备可拥有 3~6 条词缀 (至多 3前缀 + 3后缀)
			var total_affixes = randi_range(3, 6)
			num_prefixes = randi_range(1, 3)
			num_suffixes = total_affixes - num_prefixes
			if num_suffixes < 1:
				num_suffixes = 1
				num_prefixes = min(3, total_affixes - 1)
			elif num_suffixes > 3:
				num_suffixes = 3
				num_prefixes = min(3, total_affixes - 3)
		"legendary":
			num_prefixes = randi_range(2, 3)
			num_suffixes = randi_range(2, 3)
	
	# 4. 抽取词缀
	var rolled_affixes: Array[Dictionary] = []
	var used_families: Array[String] = []
	
	# 抽取前缀
	for i in range(num_prefixes):
		var aff = roll_single_affix("prefix", slot, target_level, used_families, rarity_str == "legendary")
		if not aff.is_empty():
			rolled_affixes.append(aff)
			used_families.append(aff["family"])
	
	# 抽取后缀
	for i in range(num_suffixes):
		var aff = roll_single_affix("suffix", slot, target_level, used_families, rarity_str == "legendary")
		if not aff.is_empty():
			rolled_affixes.append(aff)
			used_families.append(aff["family"])
	
	# 5. 组装全称 (以最高 T 阶的前缀与后缀冠名)
	var top_prefix_name = ""
	var top_prefix_tier = 999
	var top_suffix_name = ""
	var top_suffix_tier = 999
	
	for a in rolled_affixes:
		var t = a.get("tier", 5)
		if a.get("type") == "prefix":
			if t < top_prefix_tier:
				top_prefix_tier = t
				top_prefix_name = a.get("name_cn", "")
		elif a.get("type") == "suffix":
			if t < top_suffix_tier:
				top_suffix_tier = t
				top_suffix_name = a.get("name_cn", "")
	
	var final_name = base_item.get("name_cn", "装备")
	if top_prefix_name != "":
		final_name = top_prefix_name + " " + final_name
	if top_suffix_name != "":
		final_name = final_name + " " + top_suffix_name
	
	if rarity_str == "legendary":
		final_name = "【暗金】" + final_name
	
	# 6. 合并总属性
	var total_stats = {}
	for k in base_item.get("base_stats", {}).keys():
		total_stats[k] = float(base_item["base_stats"][k])
	
	for aff in rolled_affixes:
		var st = aff["stat"]
		var val = float(aff["value"])
		total_stats[st] = total_stats.get(st, 0.0) + val
	
	var price_mult = 1.0 if rarity_str == "normal" else (2.0 if rarity_str == "magic" else (4.0 if rarity_str == "rare" else 10.0))
	var price = int(max(1, target_level) * 12 * price_mult)
	
	return {
		"uid": "%s_%d_%d" % [base_id, Time.get_ticks_msec(), randi() % 1000],
		"base_id": base_id,
		"name_cn": final_name,
		"base_name_cn": base_item.get("name_cn", "装备"),
		"slot": slot,
		"required_level": base_item.get("required_level", 1),
		"item_level": target_level,
		"rarity": rarity_str,
		"rarity_name_cn": RARITY_NAMES_CN.get(rarity_str, "普通"),
		"rarity_color": RARITY_COLORS.get(rarity_str, "#ffffff"),
		"base_stats": base_item.get("base_stats", {}),
		"affixes": rolled_affixes,
		"total_stats": total_stats,
		"sell_price": price
	}

## 核心单条词缀抽取算法 (支持 ilvl 门槛、部位限制、族群互斥与崇高石权重加成)
static func roll_single_affix(
	affix_type: String,
	slot: String,
	ilvl: int,
	used_families: Array,
	is_exalted_or_legendary: bool = false
) -> Dictionary:
	var affixes_data = DataLoader.get_affixes_data()
	var pool_key = "prefixes" if affix_type == "prefix" else "suffixes"
	var families = affixes_data.get(pool_key, [])
	
	# 1. 过滤符合部位要求且未被使用的词缀族
	var eligible_families = []
	for fam in families:
		var fam_id = fam.get("family", "")
		if fam_id in used_families:
			continue
		
		var valid_slots = fam.get("slots", [])
		if not valid_slots.has(slot):
			continue
		
		# 检查该族是否有符合 ilvl 的 T 阶
		var valid_tiers = []
		for t in fam.get("tiers", []):
			if int(t.get("required_level", 1)) <= max(1, ilvl):
				valid_tiers.append(t)
		
		if not valid_tiers.is_empty():
			eligible_families.append({"family_data": fam, "valid_tiers": valid_tiers})
	
	if eligible_families.is_empty():
		return {}
	
	# 2. 随机选取一个词缀族
	var chosen = eligible_families[randi() % eligible_families.size()]
	var fam_data = chosen["family_data"]
	var valid_tiers: Array = chosen["valid_tiers"]
	
	# 3. 在可用 T 阶中根据权重选取 (如果为崇高石/暗金，大幅偏向高阶 T1/T2)
	var chosen_tier = _select_tier_by_weight(valid_tiers, is_exalted_or_legendary)
	if chosen_tier.is_empty():
		chosen_tier = valid_tiers[0]
	
	# 4. 在该 T 阶的区间内 Roll 点
	var min_v = float(chosen_tier.get("min_value", 1.0))
	var max_v = float(chosen_tier.get("max_value", 5.0))
	var rolled_val = randf_range(min_v, max_v)
	
	var is_pct = fam_data.get("is_percentage", false)
	var final_val: float = 0.0
	var desc_str = ""
	
	if is_pct:
		final_val = snappedf(rolled_val, 0.01)
		desc_str = "+%.1f%% %s" % [final_val * 100.0, fam_data.get("stat_name_cn", "属性")]
	else:
		final_val = round(rolled_val)
		desc_str = "+%d %s" % [int(final_val), fam_data.get("stat_name_cn", "属性")]
	
	var tier_num = int(chosen_tier.get("tier", 5))
	
	return {
		"id": chosen_tier.get("id", fam_data.get("family", "")),
		"family": fam_data.get("family", ""),
		"tier": tier_num,
		"type": affix_type,
		"stat": fam_data.get("stat", ""),
		"name_cn": chosen_tier.get("name_cn", ""),
		"stat_name_cn": fam_data.get("stat_name_cn", ""),
		"value": final_val,
		"min_value": min_v,
		"max_value": max_v,
		"is_percentage": is_pct,
		"desc": desc_str
	}

static func _select_tier_by_weight(tiers: Array, is_exalted: bool) -> Dictionary:
	if tiers.is_empty():
		return {}
	
	var total_w = 0
	var weights = []
	for t in tiers:
		var w = int(t.get("weight", 100))
		var tier_num = int(t.get("tier", 5))
		if is_exalted:
			# 崇高石大幅放大高阶 (T1/T2) 的抽取权重
			if tier_num == 1:
				w *= 6
			elif tier_num == 2:
				w *= 3
		weights.append(w)
		total_w += w
	
	var roll = randi() % max(1, total_w)
	var accum = 0
	for i in range(tiers.size()):
		accum += weights[i]
		if roll < accum:
			return tiers[i]
	
	return tiers[0]

static func get_tier_color(tier: int) -> String:
	return TIER_COLORS.get(tier, "#ffffff")
