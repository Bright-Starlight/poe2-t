extends Node

## CraftingManager: PoE 风格通货打造与装备重铸管理器
## 驱动 7 大核心通货（蜕变、改造、增幅、富豪、混沌、崇高、重铸）的库存与装备 T 级词缀重铸逻辑

signal currencies_updated(currencies: Dictionary)
signal item_crafted(currency_id: String, old_item: Dictionary, new_item: Dictionary, success: bool, message: String)

var currencies: Dictionary = {
	"transmutation": 5,
	"augmentation": 5,
	"alteration": 5,
	"regal": 2,
	"chaos": 2,
	"exalted": 1,
	"scouring": 3
}

func _ready() -> void:
	print("[CraftingManager] Initializing Crafting and Currency System...")

func add_currency(currency_id: String, amount: int = 1) -> void:
	currencies[currency_id] = currencies.get(currency_id, 0) + amount
	currencies_updated.emit(currencies)

func get_currency_count(currency_id: String) -> int:
	return currencies.get(currency_id, 0)

func has_currency(currency_id: String, amount: int = 1) -> bool:
	return get_currency_count(currency_id) >= amount

func can_apply_currency(currency_id: String, item: Dictionary) -> Dictionary:
	if item.is_empty():
		return {"can_craft": false, "reason": "未选择任何目标装备"}
	
	if not has_currency(currency_id, 1):
		var c_data = DataLoader.get_currency_data(currency_id)
		return {"can_craft": false, "reason": "【%s】数量不足！" % c_data.get("name_cn", "通货")}
	
	var r = item.get("rarity", "normal")
	var affixes = item.get("affixes", [])
	
	match currency_id:
		"transmutation":
			if r != "normal":
				return {"can_craft": false, "reason": "蜕变石只能用于【普通白装】"}
		"augmentation":
			if r != "magic":
				return {"can_craft": false, "reason": "增幅石只能用于【魔法蓝装】"}
			if affixes.size() >= 2:
				return {"can_craft": false, "reason": "该蓝装已有 2 条词缀，已达蓝装词缀上限"}
		"alteration":
			if r != "magic":
				return {"can_craft": false, "reason": "改造石只能用于【魔法蓝装】"}
		"regal":
			if r != "magic":
				return {"can_craft": false, "reason": "富豪石只能用于【魔法蓝装】"}
		"chaos":
			if r != "rare":
				return {"can_craft": false, "reason": "混沌石只能用于【稀有黄装】"}
		"exalted":
			if r != "rare":
				return {"can_craft": false, "reason": "崇高石只能用于【稀有黄装】"}
			if affixes.size() >= 6:
				return {"can_craft": false, "reason": "该黄装已有 6 条词缀，已达稀有词缀上限 (3前缀 + 3后缀)"}
		"scouring":
			if r == "normal":
				return {"can_craft": false, "reason": "该装备已经是普通白装，无需重铸"}
			if r == "legendary":
				return {"can_craft": false, "reason": "暗金装备拥有专属力量，无法使用重铸石"}
		_:
			return {"can_craft": false, "reason": "未知通货类型"}
	
	return {"can_craft": true, "reason": ""}

func craft_item(currency_id: String, item: Dictionary) -> Dictionary:
	var check = can_apply_currency(currency_id, item)
	if not check["can_craft"]:
		return {"success": false, "item": item, "message": check["reason"]}
	
	# 扣除通货
	currencies[currency_id] = max(0, currencies[currency_id] - 1)
	currencies_updated.emit(currencies)
	
	var old_item = item.duplicate(true)
	var new_item = item.duplicate(true)
	var slot = new_item.get("slot", "weapon")
	var ilvl = int(new_item.get("item_level", new_item.get("required_level", 1)))
	
	var msg = ""
	
	match currency_id:
		"transmutation":
			# 白 -> 蓝 (1~2 T 级词缀)
			new_item["rarity"] = "magic"
			new_item["rarity_name_cn"] = "魔法"
			new_item["rarity_color"] = "#63b3ed"
			
			var num_p = 1 if randf() < 0.5 else 0
			var num_s = 1 if (num_p == 0 or randf() < 0.5) else 0
			if num_p == 0 and num_s == 0:
				num_p = 1
			
			var rolled: Array[Dictionary] = []
			var used_fams: Array[String] = []
			if num_p > 0:
				var aff = ItemGenerator.roll_single_affix("prefix", slot, ilvl, used_fams, false)
				if not aff.is_empty():
					rolled.append(aff)
					used_fams.append(aff["family"])
			if num_s > 0:
				var aff = ItemGenerator.roll_single_affix("suffix", slot, ilvl, used_fams, false)
				if not aff.is_empty():
					rolled.append(aff)
					used_fams.append(aff["family"])
			
			new_item["affixes"] = rolled
			_rebuild_item_data(new_item)
			msg = "使用【蜕变石】成功！装备升阶为【魔法蓝装】并获得 %d 条 T 级词缀！" % new_item["affixes"].size()
			
		"augmentation":
			# 蓝装加 1 词缀 (至多 1前1后)
			var cur_affs = new_item.get("affixes", [])
			var used_fams: Array[String] = []
			var has_p = false
			var has_s = false
			for a in cur_affs:
				used_fams.append(a.get("family", ""))
				if a.get("type") == "prefix": has_p = true
				if a.get("type") == "suffix": has_s = true
			
			var target_type = ""
			if not has_p and not has_s:
				target_type = "prefix" if randf() < 0.5 else "suffix"
			elif not has_p:
				target_type = "prefix"
			elif not has_s:
				target_type = "suffix"
			
			if target_type != "":
				var aff = ItemGenerator.roll_single_affix(target_type, slot, ilvl, used_fams, false)
				if not aff.is_empty():
					cur_affs.append(aff)
			
			new_item["affixes"] = cur_affs
			_rebuild_item_data(new_item)
			msg = "使用【增幅石】成功！为蓝装增添了第 2 条 T 级词缀！"
			
		"alteration":
			# 重洗蓝装 (1~2 词缀)
			var num_p = 1 if randf() < 0.5 else 0
			var num_s = 1 if (num_p == 0 or randf() < 0.5) else 0
			if num_p == 0 and num_s == 0:
				num_p = 1
			
			var rolled: Array[Dictionary] = []
			var used_fams: Array[String] = []
			if num_p > 0:
				var aff = ItemGenerator.roll_single_affix("prefix", slot, ilvl, used_fams, false)
				if not aff.is_empty():
					rolled.append(aff)
					used_fams.append(aff["family"])
			if num_s > 0:
				var aff = ItemGenerator.roll_single_affix("suffix", slot, ilvl, used_fams, false)
				if not aff.is_empty():
					rolled.append(aff)
					used_fams.append(aff["family"])
			
			new_item["affixes"] = rolled
			_rebuild_item_data(new_item)
			msg = "使用【改造石】成功！重铸生成 %d 条全新蓝装 T 级词缀！" % new_item["affixes"].size()
			
		"regal":
			# 蓝 -> 黄 (保留原有并加 1 词缀，上限扩展为 6 词缀)
			new_item["rarity"] = "rare"
			new_item["rarity_name_cn"] = "稀有"
			new_item["rarity_color"] = "#f6e05e"
			var cur_affs = new_item.get("affixes", []).duplicate(true)
			var used_fams: Array[String] = []
			var p_cnt = 0
			var s_cnt = 0
			for a in cur_affs:
				used_fams.append(a.get("family", ""))
				if a.get("type") == "prefix": p_cnt += 1
				if a.get("type") == "suffix": s_cnt += 1
			
			var target_type = "prefix"
			if p_cnt < 3 and (s_cnt >= 3 or randf() < 0.5):
				target_type = "prefix"
			elif s_cnt < 3:
				target_type = "suffix"
			
			var aff = ItemGenerator.roll_single_affix(target_type, slot, ilvl, used_fams, false)
			if not aff.is_empty():
				cur_affs.append(aff)
			
			new_item["affixes"] = cur_affs
			_rebuild_item_data(new_item)
			msg = "使用【富豪石】成功！装备荣耀升阶为【稀有黄装】并附带全新 T 级词缀！"
			
		"chaos":
			# 重洗黄装 (PoE2 规范: 3~6 词缀，1~3 前缀 + 1~3 后缀)
			var total_affs = randi_range(3, 6)
			var num_p = randi_range(1, 3)
			var num_s = total_affs - num_p
			if num_s < 1:
				num_s = 1
				num_p = min(3, total_affs - 1)
			elif num_s > 3:
				num_s = 3
				num_p = min(3, total_affs - 3)
			
			var rolled: Array[Dictionary] = []
			var used_fams: Array[String] = []
			for i in range(num_p):
				var aff = ItemGenerator.roll_single_affix("prefix", slot, ilvl, used_fams, false)
				if not aff.is_empty():
					rolled.append(aff)
					used_fams.append(aff["family"])
			for i in range(num_s):
				var aff = ItemGenerator.roll_single_affix("suffix", slot, ilvl, used_fams, false)
				if not aff.is_empty():
					rolled.append(aff)
					used_fams.append(aff["family"])
			
			new_item["affixes"] = rolled
			_rebuild_item_data(new_item)
			msg = "使用【混沌石】成功！重铸生成 %d 条全新稀有 T 级词缀！" % new_item["affixes"].size()
			
		"exalted":
			# 黄装加 1 极品 T 阶词缀 (至多 6 词缀，3前缀 + 3后缀)
			var cur_affs = new_item.get("affixes", []).duplicate(true)
			var used_fams: Array[String] = []
			var p_cnt = 0
			var s_cnt = 0
			for a in cur_affs:
				used_fams.append(a.get("family", ""))
				if a.get("type") == "prefix": p_cnt += 1
				if a.get("type") == "suffix": s_cnt += 1
			
			var target_type = "prefix"
			if p_cnt < 3 and (s_cnt >= 3 or randf() < 0.5):
				target_type = "prefix"
			elif s_cnt < 3:
				target_type = "suffix"
			
			var aff = ItemGenerator.roll_single_affix(target_type, slot, ilvl, used_fams, true) # 崇高石高阶优先权重
			if not aff.is_empty():
				cur_affs.append(aff)
			
			new_item["affixes"] = cur_affs
			_rebuild_item_data(new_item)
			msg = "使用【崇高石】成功！为稀有黄装点缀了 1 条高阶极品 T%d 词缀！" % (aff.get("tier", 1) if not aff.is_empty() else 1)
			
		"scouring":
			# 还原为白装
			new_item["rarity"] = "normal"
			new_item["rarity_name_cn"] = "普通"
			new_item["rarity_color"] = "#ffffff"
			new_item["affixes"] = []
			_rebuild_item_data(new_item)
			msg = "使用【重铸石】成功！已清除装备全部词缀，还原为纯净白装。"
	
	item_crafted.emit(currency_id, old_item, new_item, true, msg)
	return {"success": true, "item": new_item, "message": msg}

func _rebuild_item_data(item: Dictionary) -> void:
	var base_id = item.get("base_id", "")
	var base_data = DataLoader.get_item_data(base_id)
	var base_name = item.get("base_name_cn", base_data.get("name_cn", "装备"))
	
	var top_prefix_name = ""
	var top_prefix_tier = 999
	var top_suffix_name = ""
	var top_suffix_tier = 999
	
	for aff in item.get("affixes", []):
		var t = aff.get("tier", 5)
		if aff.get("type") == "prefix":
			if t < top_prefix_tier:
				top_prefix_tier = t
				top_prefix_name = aff.get("name_cn", "")
		elif aff.get("type") == "suffix":
			if t < top_suffix_tier:
				top_suffix_tier = t
				top_suffix_name = aff.get("name_cn", "")
	
	var final_name = base_name
	if top_prefix_name != "":
		final_name = top_prefix_name + " " + final_name
	if top_suffix_name != "":
		final_name = final_name + " " + top_suffix_name
	
	if item.get("rarity") == "legendary":
		final_name = "【暗金】" + final_name
	
	item["name_cn"] = final_name
	
	# 重算总属性
	var total_stats = {}
	for k in item.get("base_stats", {}).keys():
		total_stats[k] = float(item["base_stats"][k])
	
	for aff in item.get("affixes", []):
		var st = aff["stat"]
		var val = float(aff["value"])
		total_stats[st] = total_stats.get(st, 0.0) + val
	
	item["total_stats"] = total_stats
	
	# 重算售价
	var r = item.get("rarity", "normal")
	var target_lvl = int(item.get("item_level", item.get("required_level", 1)))
	var mult = 1.0 if r == "normal" else (2.0 if r == "magic" else (4.0 if r == "rare" else 10.0))
	item["sell_price"] = int(max(1, target_lvl) * 12 * mult)
