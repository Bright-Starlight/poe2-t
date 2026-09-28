extends Node

## WaystoneManager: PoE2 风格异界引路石与地图8词缀重铸管理器
## 驱动引路石阶级基底词缀、最多8显式词缀生成、通货制图洗练(蜕变/改造/增幅/富豪/混沌/崇高/瓦尔8词缀)与怪群属性聚合

signal waystone_crafted(currency_id: String, old_waystone: Dictionary, new_waystone: Dictionary, success: bool, message: String)

const RARITY_COLORS = {
	"normal": "#ffffff",
	"magic": "#63b3ed",
	"rare": "#f6e05e",
	"corrupted_8mod": "#e53e3e"
}

const RARITY_NAMES_CN = {
	"normal": "普通",
	"magic": "魔法",
	"rare": "稀有",
	"corrupted_8mod": "8词缀腐化极品"
}

func _ready() -> void:
	print("[WaystoneManager] Initializing PoE2 Waystone & Map Affixes System...")

## 生成指定基底与品质的引路石
func generate_waystone(base_id: String, rarity_str: String = "normal", force_affixes_count: int = 0) -> Dictionary:
	var base_data = DataLoader.get_waystone_data(base_id)
	if base_data.is_empty():
		var all_w = DataLoader.get_all_waystones()
		if not all_w.is_empty():
			base_id = all_w.keys()[0]
			base_data = all_w[base_id]
		else:
			return {}
	
	var waystone = {
		"uid": "ws_%s_%d_%d" % [base_id, Time.get_ticks_msec(), randi() % 10000],
		"base_id": base_id,
		"tier": base_data.get("tier", 1),
		"name_cn": base_data.get("name_cn", "引路石"),
		"recommended_level": base_data.get("recommended_level", "Lv.1"),
		"level_scale": float(base_data.get("level_scale", 1.0)),
		"base_monsters_count": int(base_data.get("base_monsters_count", 20)),
		"base_pack_size": int(base_data.get("base_pack_size", 2)),
		"monster_pool": base_data.get("monster_pool", ["slime_green"]).duplicate(),
		"boss_id": base_data.get("boss_id", "boss_skeleton_king"),
		"rarity": rarity_str,
		"is_corrupted": (rarity_str == "corrupted_8mod"),
		"base_implicits": base_data.get("base_implicits", []).duplicate(true),
		"affixes": []
	}
	
	if force_affixes_count == 8 or rarity_str == "corrupted_8mod":
		waystone["rarity"] = "corrupted_8mod"
		waystone["is_corrupted"] = true
		_roll_affixes_for_waystone(waystone, 4, 4)
	elif rarity_str == "rare":
		var num_pre = randi_range(2, 3)
		var num_suf = randi_range(2, 3)
		_roll_affixes_for_waystone(waystone, num_pre, num_suf)
	elif rarity_str == "magic":
		var num_pre = 1 if randf() < 0.6 else 0
		var num_suf = 1 if (num_pre == 0 or randf() < 0.6) else 0
		_roll_affixes_for_waystone(waystone, num_pre, num_suf)
	else:
		# normal 0 affixes
		waystone["affixes"] = []
	
	_recalculate_waystone_totals(waystone)
	return waystone

## 内部随机抽取词缀 (最多支持4前缀+4后缀=8词缀)
func _roll_affixes_for_waystone(waystone: Dictionary, num_prefixes: int, num_suffixes: int) -> void:
	var aff_data = DataLoader.get_map_affixes_data()
	var pre_pool = aff_data.get("prefixes", []).duplicate(true)
	var suf_pool = aff_data.get("suffixes", []).duplicate(true)
	
	pre_pool.shuffle()
	suf_pool.shuffle()
	
	var rolled: Array[Dictionary] = []
	
	for i in range(mini(num_prefixes, pre_pool.size())):
		var aff = pre_pool[i]
		var val = _roll_affix_value(aff)
		var desc_str = _format_affix_desc(aff, val)
		rolled.append({
			"id": aff["id"],
			"type": "prefix",
			"name_cn": aff["name_cn"],
			"stat": aff["stat"],
			"stat_name_cn": aff["stat_name_cn"],
			"value": val,
			"is_percentage": aff.get("is_percentage", false),
			"quant_bonus": float(aff.get("quant_bonus", 0.15)),
			"rarity_bonus": float(aff.get("rarity_bonus", 0.20)),
			"pack_size_bonus": float(aff.get("pack_size_bonus", 0.10)),
			"exp_bonus": float(aff.get("exp_bonus", 0.15)),
			"desc": desc_str
		})
	
	for i in range(mini(num_suffixes, suf_pool.size())):
		var aff = suf_pool[i]
		var val = _roll_affix_value(aff)
		var desc_str = _format_affix_desc(aff, val)
		rolled.append({
			"id": aff["id"],
			"type": "suffix",
			"name_cn": aff["name_cn"],
			"stat": aff["stat"],
			"stat_name_cn": aff["stat_name_cn"],
			"value": val,
			"is_percentage": aff.get("is_percentage", false),
			"quant_bonus": float(aff.get("quant_bonus", 0.15)),
			"rarity_bonus": float(aff.get("rarity_bonus", 0.20)),
			"pack_size_bonus": float(aff.get("pack_size_bonus", 0.10)),
			"exp_bonus": float(aff.get("exp_bonus", 0.15)),
			"desc": desc_str
		})
	
	waystone["affixes"] = rolled

func _format_affix_desc(aff: Dictionary, val: float) -> String:
	var desc_template = aff.get("desc", "")
	var is_pct = aff.get("is_percentage", false)
	var formatted_val = val * 100.0 if is_pct else val
	var str_val = "%.0f" % formatted_val if is_pct else str(int(formatted_val))
	
	if "%.0f" in desc_template:
		desc_template = desc_template.replace("%.0f", str_val)
	elif "%d" in desc_template:
		desc_template = desc_template.replace("%d", str(int(formatted_val)))
	elif "%s" in desc_template:
		desc_template = desc_template.replace("%s", str_val)
	
	desc_template = desc_template.replace("%%", "%")
	return desc_template

func _roll_affix_value(affix: Dictionary) -> float:
	var min_v = float(affix.get("min_value", 0.1))
	var max_v = float(affix.get("max_value", 0.3))
	var val = randf_range(min_v, max_v)
	if affix.get("is_percentage", false):
		return snappedf(val, 0.01)
	return round(val)

## 重新核算引路石总增幅与怪物怪群规模
func _recalculate_waystone_totals(waystone: Dictionary) -> void:
	var totals = {
		"pack_size_pct": 0.0,
		"item_quant_pct": 0.0,
		"item_rarity_pct": 0.0,
		"currency_mult_pct": 0.0,
		"unique_drop_mult_pct": 0.0,
		"exp_bonus_pct": 0.0,
		"monster_life_pct": 0.0,
		"monster_phys_damage_pct": 0.0,
		"extra_fire_damage_pct": 0.0,
		"extra_cold_damage_pct": 0.0,
		"extra_lightning_damage_pct": 0.0,
		"monster_speed_pct": 0.0,
		"monster_defense_pct": 0.0,
		"monster_crit_chance_pct": 0.0,
		"monster_life_steal_pct": 0.0,
		"monster_shock_on_hit": 0,
		"monster_bleed_on_hit": 0,
		"player_defense_reduction_pct": 0.0,
		"skill_cooldown_increase_pct": 0.0,
		"recovery_reduction_pct": 0.0
	}
	
	# 1. 计入基底固有词缀
	for imp in waystone.get("base_implicits", []):
		var st = imp.get("stat", "")
		var v = float(imp.get("value", 0.0))
		if totals.has(st):
			totals[st] += v
	
	# 2. 计入显式词缀 (最多8条)
	for aff in waystone.get("affixes", []):
		var st = aff.get("stat", "")
		var v = float(aff.get("value", 0.0))
		if totals.has(st):
			totals[st] += v
		
		totals["item_quant_pct"] += float(aff.get("quant_bonus", 0.0))
		totals["item_rarity_pct"] += float(aff.get("rarity_bonus", 0.0))
		totals["pack_size_pct"] += float(aff.get("pack_size_bonus", 0.0))
		totals["exp_bonus_pct"] += float(aff.get("exp_bonus", 0.0))
	
	# 3. 计算怪群总数与同屏怪容量
	var base_cnt = int(waystone.get("base_monsters_count", 20))
	var base_pack = int(waystone.get("base_pack_size", 2))
	
	var total_monsters = int(round(base_cnt * (1.0 + totals["pack_size_pct"])))
	var max_active = mini(5, maxi(2, int(round(base_pack * (1.0 + totals["pack_size_pct"] * 0.6)))))
	
	waystone["total_monsters_count"] = total_monsters
	waystone["max_active_monsters"] = max_active
	waystone["modifiers_summary"] = totals
	
	# 全称组装
	var r = waystone.get("rarity", "normal")
	var aff_cnt = waystone.get("affixes", []).size()
	waystone["rarity_name_cn"] = RARITY_NAMES_CN.get(r, "普通")
	waystone["rarity_color"] = RARITY_COLORS.get(r, "#ffffff")
	
	var base_name = DataLoader.get_waystone_data(waystone.get("base_id", "")).get("name_cn", "引路石")
	if r == "corrupted_8mod":
		waystone["display_name"] = "【8词缀腐化】" + base_name
	elif r == "rare":
		waystone["display_name"] = "【%d词缀稀有】" % aff_cnt + base_name
	elif r == "magic":
		waystone["display_name"] = "【%d词缀魔法】" % aff_cnt + base_name
	else:
		waystone["display_name"] = base_name

## 制图工坊：使用通货打造重铸引路石
func craft_waystone(waystone: Dictionary, currency_id: String) -> Dictionary:
	var count = CraftingManager.get_currency_count(currency_id)
	if count <= 0:
		return {"success": false, "reason": "【%s】库存不足！" % currency_id, "waystone": waystone}
	
	var r = waystone.get("rarity", "normal")
	var is_corr = waystone.get("is_corrupted", false)
	
	if is_corr:
		return {"success": false, "reason": "该引路石已被腐化，无法再次重铸！", "waystone": waystone}
	
	var new_ws = waystone.duplicate(true)
	var success = false
	var msg = ""
	
	match currency_id:
		"transmutation":
			if r != "normal":
				return {"success": false, "reason": "蜕变石仅能对普通白图使用！", "waystone": waystone}
			new_ws["rarity"] = "magic"
			_roll_affixes_for_waystone(new_ws, 1 if randf() < 0.6 else 0, 1)
			success = true
			msg = "引路石蜕变为魔法品质 (获得 %d 条词缀)" % new_ws["affixes"].size()
			
		"augmentation":
			if r != "magic":
				return {"success": false, "reason": "增幅石仅能对魔法蓝图使用！", "waystone": waystone}
			if new_ws["affixes"].size() >= 2:
				return {"success": false, "reason": "该魔法引路石已拥有最大 2 条词缀！", "waystone": waystone}
			_add_one_affix(new_ws)
			success = true
			msg = "为魔法引路石增幅了第 2 条词缀"
			
		"alteration":
			if r != "magic":
				return {"success": false, "reason": "改造石仅能对魔法蓝图使用！", "waystone": waystone}
			_roll_affixes_for_waystone(new_ws, 1 if randf() < 0.6 else 0, 1)
			success = true
			msg = "重随了魔法引路石的随机词缀"
			
		"regal":
			if r != "magic":
				return {"success": false, "reason": "富豪石仅能对魔法蓝图使用！", "waystone": waystone}
			new_ws["rarity"] = "rare"
			_add_one_affix(new_ws)
			success = true
			msg = "引路石晋升为稀有黄金品质 (共 %d 条词缀)" % new_ws["affixes"].size()
			
		"chaos":
			if r != "rare":
				return {"success": false, "reason": "混沌石仅能对稀有黄图使用！", "waystone": waystone}
			var num_pre = randi_range(2, 3)
			var num_suf = randi_range(2, 3)
			_roll_affixes_for_waystone(new_ws, num_pre, num_suf)
			success = true
			msg = "混沌重铸了稀有引路石全部词缀 (共 %d 条词缀)" % new_ws["affixes"].size()
			
		"exalted":
			if r != "rare":
				return {"success": false, "reason": "崇高石仅能对稀有黄图使用！", "waystone": waystone}
			if new_ws["affixes"].size() >= 6:
				return {"success": false, "reason": "该稀有引路石已达到常规 6 词缀上限！", "waystone": waystone}
			_add_one_affix(new_ws)
			success = true
			msg = "崇高附魔了一道强力显式词缀 (共 %d 条词缀)" % new_ws["affixes"].size()
			
		"scouring":
			if r == "normal":
				return {"success": false, "reason": "该引路石已是白板品质！", "waystone": waystone}
			new_ws["rarity"] = "normal"
			new_ws["affixes"] = []
			success = true
			msg = "重铸石清除了引路石的所有随机词缀，回归白板"
			
		"vaal", "chaos_orb":
			# 瓦尔腐化石机制
			new_ws["is_corrupted"] = true
			var roll = randf()
			if roll < 0.35:
				# 腐化为 8-Mod 超级极品图！
				new_ws["rarity"] = "corrupted_8mod"
				_roll_affixes_for_waystone(new_ws, 4, 4)
				success = true
				msg = "【神迹降临!】瓦尔之力暴涌！引路石发生终极变异，觉醒为【8词缀腐化极品地图】！"
			elif roll < 0.65 and new_ws["affixes"].size() < 6:
				_add_one_affix(new_ws)
				new_ws["rarity"] = "rare"
				success = true
				msg = "瓦尔腐化成功添加了一条额外词缀 (已被腐化)"
			else:
				success = true
				msg = "引路石被瓦尔之力侵蚀锁定 (属性未变，无法再次重铸)"
			
		_:
			return {"success": false, "reason": "未知通货类型", "waystone": waystone}
	
	if success:
		CraftingManager.currencies[currency_id] -= 1
		CraftingManager.currencies_updated.emit(CraftingManager.currencies)
		_recalculate_waystone_totals(new_ws)
		waystone_crafted.emit(currency_id, waystone, new_ws, true, msg)
		return {"success": true, "reason": msg, "waystone": new_ws}
	
	return {"success": false, "reason": "重铸失败", "waystone": waystone}

func _add_one_affix(waystone: Dictionary) -> void:
	var aff_data = DataLoader.get_map_affixes_data()
	var pre_pool = aff_data.get("prefixes", []).duplicate(true)
	var suf_pool = aff_data.get("suffixes", []).duplicate(true)
	
	var existing_ids = []
	var pre_count = 0
	var suf_count = 0
	for a in waystone.get("affixes", []):
		existing_ids.append(a["id"])
		if a["type"] == "prefix": pre_count += 1
		else: suf_count += 1
	
	var candidate_pool = []
	if pre_count <= suf_count and pre_count < 4:
		for p in pre_pool:
			if not p["id"] in existing_ids: candidate_pool.append(p)
	
	if candidate_pool.is_empty() and suf_count < 4:
		for s in suf_pool:
			if not s["id"] in existing_ids: candidate_pool.append(s)
	
	if candidate_pool.is_empty():
		return
	
	candidate_pool.shuffle()
	var aff = candidate_pool[0]
	var val = _roll_affix_value(aff)
	var desc_str = _format_affix_desc(aff, val)
	waystone["affixes"].append({
		"id": aff["id"],
		"type": "prefix" if pre_count <= suf_count else "suffix",
		"name_cn": aff["name_cn"],
		"stat": aff["stat"],
		"stat_name_cn": aff["stat_name_cn"],
		"value": val,
		"is_percentage": aff.get("is_percentage", false),
		"quant_bonus": float(aff.get("quant_bonus", 0.15)),
		"rarity_bonus": float(aff.get("rarity_bonus", 0.20)),
		"pack_size_bonus": float(aff.get("pack_size_bonus", 0.10)),
		"exp_bonus": float(aff.get("exp_bonus", 0.15)),
		"desc": desc_str
	})
