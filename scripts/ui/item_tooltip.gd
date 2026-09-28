extends PanelContainer

## ItemTooltip: 暗黑/PoE2 风格装备词缀与属性详情浮窗 (含 T 级与 Roll 点区间展示)

@onready var icon_rect: TextureRect = $VBox/HeaderRow/IconRect
@onready var name_label: Label = $VBox/HeaderRow/NameLabel
@onready var type_label: Label = $VBox/TypeLabel
@onready var base_stats_label: Label = $VBox/BaseStatsLabel
@onready var affixes_label: Label = $VBox/AffixesLabel
@onready var price_label: Label = $VBox/PriceLabel

var current_item: Dictionary = {}
var is_equipped: bool = false
var bag_index: int = -1

func display_item(item_data: Dictionary, p_is_equipped: bool = false, p_bag_index: int = -1) -> void:
	current_item = item_data
	is_equipped = p_is_equipped
	bag_index = p_bag_index
	
	if item_data.is_empty():
		visible = false
		return
	
	visible = true
	
	# 标题与稀有度颜色及部位图标
	var r_color = item_data.get("rarity_color", "#ffffff")
	name_label.text = item_data.get("name_cn", "未知装备")
	name_label.modulate = Color(r_color)
	
	var slot = item_data.get("slot", "")
	var slot_icon = DataLoader.get_slot_icon(slot)
	if icon_rect:
		icon_rect.texture = slot_icon
		icon_rect.visible = (slot_icon != null)
		icon_rect.modulate = Color(r_color)
	
	# 类型与需求及物品等级 (ilvl)
	var slot_cn = _get_slot_name_cn(slot)
	var req_lvl = item_data.get("required_level", 1)
	var ilvl = item_data.get("item_level", req_lvl)
	type_label.text = "【%s】 需求等级: Lv.%d (iLvl.%d)  品质: [%s]" % [
		slot_cn, req_lvl, ilvl, item_data.get("rarity_name_cn", "普通")
	]
	
	# 基础属性 (白字)
	var base_lines = []
	var base_dict = item_data.get("base_stats", {})
	for k in base_dict.keys():
		var val = base_dict[k]
		var stat_cn = _get_stat_name_cn(k)
		if k == "attack_speed":
			base_lines.append("• %s: %.1f 次/秒" % [stat_cn, val])
		else:
			base_lines.append("• %s: +%d" % [stat_cn, int(val)])
	base_stats_label.text = "\n".join(base_lines) if not base_lines.is_empty() else "• 无基础属性"
	
	# 随机词缀 (含 PoE2 T 级与区间显示)
	var aff_lines = []
	var aff_list = item_data.get("affixes", [])
	for aff in aff_list:
		var type_str = "前缀" if aff.get("type") == "prefix" else "后缀"
		var tier = int(aff.get("tier", 5))
		var name_cn = aff.get("name_cn", "")
		var desc = aff.get("desc", "")
		var is_pct = aff.get("is_percentage", false)
		var min_v = aff.get("min_value")
		var max_v = aff.get("max_value")
		
		var range_str = ""
		if min_v != null and max_v != null:
			if is_pct:
				range_str = "[%.0f%%~%.0f%%]" % [float(min_v) * 100.0, float(max_v) * 100.0]
			else:
				range_str = "[%d~%d]" % [int(min_v), int(max_v)]
		
		var line_str = ""
		if name_cn != "":
			line_str = "• [%s T%d] %s: %s %s" % [type_str, tier, name_cn, desc, range_str]
		else:
			line_str = "• [%s T%d] %s %s" % [type_str, tier, desc, range_str]
		aff_lines.append(line_str)
	
	if aff_lines.is_empty():
		affixes_label.text = "（无附加随机词缀）"
		affixes_label.modulate = Color(0.6, 0.6, 0.6)
	else:
		affixes_label.text = "\n".join(aff_lines)
		affixes_label.modulate = Color(0.4, 0.7, 1.0) if item_data.get("rarity") == "magic" else Color(0.95, 0.85, 0.3)
	
	# 售价
	var price = item_data.get("sell_price", 10)
	price_label.text = "回收售价: %d 金币  (点击快捷操作)" % price

func _get_slot_name_cn(slot: String) -> String:
	match slot:
		"weapon": return "主手武器"
		"helmet": return "头部防具"
		"chest": return "胸部铠甲"
		"gloves": return "手部护甲"
		"boots": return "足部胫甲"
		"amulet": return "项链护符"
		"ring": return "戒指指环"
	return "装备"

func _get_stat_name_cn(stat: String) -> String:
	match stat:
		"attack_damage": return "基础攻击"
		"attack_damage_pct": return "物理攻击加成"
		"attack_speed": return "攻击速度"
		"attack_speed_pct": return "攻击速度加成"
		"max_hp": return "最大生命"
		"max_mp": return "最大法力"
		"armor": return "护甲值"
		"evasion": return "闪避值"
		"crit_rate": return "暴击率"
		"crit_damage": return "暴击伤害"
		"fire_damage": return "火焰伤害"
		"cold_damage": return "冰霜伤害"
		"lightning_damage": return "闪电伤害"
		"fire_res": return "火焰抗性"
		"cold_res": return "冰霜抗性"
		"lightning_res": return "闪电抗性"
		"all_res": return "全元素抗性"
		"move_speed_pct": return "移动速度"
		"strength": return "力量"
		"dexterity": return "敏捷"
		"intelligence": return "智力"
	return stat
