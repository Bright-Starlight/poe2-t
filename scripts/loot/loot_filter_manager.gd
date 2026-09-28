extends Node

## LootFilterManager: 装备掉落过滤系统管理器
## 支持多档预设模板（全部拾取、过滤白装、过滤白蓝装、严格过滤、自定义）、细粒度品质/部位/词缀门槛过滤、自动折算金币/丢弃处理及持久化存档

signal filter_config_updated(config: Dictionary)

enum FilterPreset {
	ALL,                 # 全部拾取
	HIDE_NORMAL,         # 过滤白装
	HIDE_NORMAL_MAGIC,   # 过滤白蓝装 (推荐)
	STRICT,              # 严格过滤 (仅暗金及多词缀稀有)
	CUSTOM               # 自定义配置
}

enum FilterAction {
	AUTO_SELL,           # 自动出售为金币
	DISCARD              # 直接舍弃
}

var is_enabled: bool = true
var current_preset: String = "hide_normal_magic"

# 拾取品质白名单 (true 表示保留拾取，false 表示过滤)
var rarity_rules: Dictionary = {
	"normal": false,
	"magic": false,
	"rare": true,
	"legendary": true
}

# 拾取装备部位白名单
var slot_rules: Dictionary = {
	"weapon": true,
	"helmet": true,
	"chest": true,
	"gloves": true,
	"boots": true,
	"amulet": true,
	"ring": true
}

# 稀有度过滤之上的附加条件
var min_affixes_count: int = 0       # 词缀数量门槛 (0: 不限, 1, 2, 3...)
var min_required_level: int = 1      # 最低需求等级门槛
var filter_action: String = "auto_sell" # "auto_sell" 或 "discard"
var show_filtered_log: bool = true   # 是否在战斗日志中输出过滤提示

func _ready() -> void:
	print("[LootFilterManager] Initializing Loot Filter System...")
	# 默认应用推荐预设
	apply_preset(current_preset)

func apply_preset(preset_name: String) -> void:
	current_preset = preset_name
	match preset_name:
		"all":
			rarity_rules = {
				"normal": true,
				"magic": true,
				"rare": true,
				"legendary": true
			}
			_set_all_slots(true)
			min_affixes_count = 0
			min_required_level = 1
		"hide_normal":
			rarity_rules = {
				"normal": false,
				"magic": true,
				"rare": true,
				"legendary": true
			}
			_set_all_slots(true)
			min_affixes_count = 0
			min_required_level = 1
		"hide_normal_magic":
			rarity_rules = {
				"normal": false,
				"magic": false,
				"rare": true,
				"legendary": true
			}
			_set_all_slots(true)
			min_affixes_count = 0
			min_required_level = 1
		"strict":
			rarity_rules = {
				"normal": false,
				"magic": false,
				"rare": true,
				"legendary": true
			}
			_set_all_slots(true)
			min_affixes_count = 2 # 稀有装备至少需拥有 2 条词缀
			min_required_level = 1
		"custom":
			# 保持当前自定义参数
			pass
		_:
			current_preset = "hide_normal_magic"
			apply_preset("hide_normal_magic")
			return
	
	filter_config_updated.emit(get_config())

func _set_all_slots(enabled: bool) -> void:
	for k in slot_rules.keys():
		slot_rules[k] = enabled

func set_rarity_rule(rarity: String, enabled: bool) -> void:
	if rarity_rules.has(rarity):
		rarity_rules[rarity] = enabled
		_check_custom_preset()
		filter_config_updated.emit(get_config())

func set_slot_rule(slot: String, enabled: bool) -> void:
	if slot_rules.has(slot):
		slot_rules[slot] = enabled
		_check_custom_preset()
		filter_config_updated.emit(get_config())

func set_all_slots_rule(enabled: bool) -> void:
	_set_all_slots(enabled)
	_check_custom_preset()
	filter_config_updated.emit(get_config())

func set_min_affixes_count(count: int) -> void:
	min_affixes_count = count
	_check_custom_preset()
	filter_config_updated.emit(get_config())

func set_filter_action(action: String) -> void:
	if action in ["auto_sell", "discard"]:
		filter_action = action
		filter_config_updated.emit(get_config())

func set_show_filtered_log(show: bool) -> void:
	show_filtered_log = show
	filter_config_updated.emit(get_config())

func set_enabled(enabled: bool) -> void:
	is_enabled = enabled
	filter_config_updated.emit(get_config())

func _check_custom_preset() -> void:
	# 检查当前配置是否匹配已有预设，如果不匹配则标记为 custom
	if min_affixes_count == 0 and _all_slots_enabled():
		if rarity_rules["normal"] and rarity_rules["magic"] and rarity_rules["rare"] and rarity_rules["legendary"]:
			current_preset = "all"
			return
		if not rarity_rules["normal"] and rarity_rules["magic"] and rarity_rules["rare"] and rarity_rules["legendary"]:
			current_preset = "hide_normal"
			return
		if not rarity_rules["normal"] and not rarity_rules["magic"] and rarity_rules["rare"] and rarity_rules["legendary"]:
			current_preset = "hide_normal_magic"
			return
	elif min_affixes_count == 2 and _all_slots_enabled() and not rarity_rules["normal"] and not rarity_rules["magic"] and rarity_rules["rare"] and rarity_rules["legendary"]:
		current_preset = "strict"
		return
	
	current_preset = "custom"

func _all_slots_enabled() -> bool:
	for k in slot_rules.keys():
		if not slot_rules[k]:
			return false
	return true

## 核心装备过滤评估函数
## 返回判定结果字典:
## {
##   "passed": bool,        # true 表示符合拾取规则入包，false 表示被过滤拦截
##   "action": String,      # "auto_sell" 或 "discard"
##   "reason": String,      # 拦截原因说明
##   "gold_earned": int     # 若 action == "auto_sell"，折算金币价值
## }
func evaluate_item(item: Dictionary) -> Dictionary:
	var price = int(item.get("sell_price", 10))
	var result = {
		"passed": true,
		"action": filter_action,
		"reason": "",
		"gold_earned": price
	}
	
	# 如果过滤系统未启用，全部放行
	if not is_enabled:
		return result
	
	var rarity = item.get("rarity", "normal")
	var slot = item.get("slot", "weapon")
	var affixes = item.get("affixes", [])
	var req_lvl = int(item.get("required_level", 1))
	
	# 1. 部位过滤检查
	if slot_rules.has(slot) and not slot_rules[slot]:
		result["passed"] = false
		result["reason"] = "部位已过滤 (%s)" % _get_slot_name_cn(slot)
		return result
	
	# 2. 等级需求检查
	if req_lvl < min_required_level:
		result["passed"] = false
		result["reason"] = "等级不足 (Lv.%d < Lv.%d)" % [req_lvl, min_required_level]
		return result
	
	# 3. 品质过滤检查 (暗金橙装在默认非严格自定义下优先放行，除非显式关闭)
	if rarity_rules.has(rarity) and not rarity_rules[rarity]:
		result["passed"] = false
		result["reason"] = "品质已过滤 (%s)" % item.get("rarity_name_cn", "普通")
		return result
	
	# 4. 词缀数量门槛检查 (对稀有/魔法装备起效，暗金不限)
	if min_affixes_count > 0 and rarity != "legendary":
		if affixes.size() < min_affixes_count:
			result["passed"] = false
			result["reason"] = "词缀数不足 (%d < %d条)" % [affixes.size(), min_affixes_count]
			return result
	
	return result

func get_config() -> Dictionary:
	return {
		"is_enabled": is_enabled,
		"preset": current_preset,
		"rarity_rules": rarity_rules.duplicate(true),
		"slot_rules": slot_rules.duplicate(true),
		"min_affixes_count": min_affixes_count,
		"min_required_level": min_required_level,
		"filter_action": filter_action,
		"show_filtered_log": show_filtered_log
	}

func get_save_data() -> Dictionary:
	return get_config()

func load_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	
	is_enabled = bool(data.get("is_enabled", true))
	current_preset = str(data.get("preset", "hide_normal_magic"))
	
	if data.has("rarity_rules") and data["rarity_rules"] is Dictionary:
		for k in data["rarity_rules"].keys():
			rarity_rules[k] = bool(data["rarity_rules"][k])
	
	if data.has("slot_rules") and data["slot_rules"] is Dictionary:
		for k in data["slot_rules"].keys():
			slot_rules[k] = bool(data["slot_rules"][k])
	
	min_affixes_count = int(data.get("min_affixes_count", 0))
	min_required_level = int(data.get("min_required_level", 1))
	filter_action = str(data.get("filter_action", "auto_sell"))
	show_filtered_log = bool(data.get("show_filtered_log", true))
	
	print("[LootFilterManager] Loaded filter config: preset=%s, action=%s, enabled=%s" % [
		current_preset, filter_action, str(is_enabled)
	])
	filter_config_updated.emit(get_config())

func reset_to_default() -> void:
	is_enabled = true
	filter_action = "auto_sell"
	show_filtered_log = true
	apply_preset("hide_normal_magic")

func get_preset_name_cn(preset_name: String) -> String:
	match preset_name:
		"all": return "全部拾取"
		"hide_normal": return "过滤普通白装"
		"hide_normal_magic": return "过滤白装与蓝装"
		"strict": return "严格过滤 (暗金/极品)"
		"custom": return "自定义配置"
	return "自定义"

func get_summary_text() -> String:
	if not is_enabled:
		return "掉落过滤: [已关闭]"
	var act_str = "自动出售" if filter_action == "auto_sell" else "直接丢弃"
	return "过滤: %s [%s]" % [get_preset_name_cn(current_preset), act_str]

func _get_slot_name_cn(slot: String) -> String:
	match slot:
		"weapon": return "武器"
		"helmet": return "头盔"
		"chest": return "胸甲"
		"gloves": return "手套"
		"boots": return "鞋子"
		"amulet": return "项链"
		"ring": return "戒指"
	return slot
