extends PanelContainer

## CraftingPanel: PoE 风格通货打造重铸工坊界面

signal closed
signal item_crafted_refresh

@onready var close_btn: Button = $VBox/HeaderBox/CloseBtn

# 目标装备展示区
@onready var item_icon_rect: TextureRect = $VBox/ItemInfoBox/ItemHeaderRow/ItemIconRect
@onready var item_name_label: Label = $VBox/ItemInfoBox/ItemHeaderRow/ItemNameLabel
@onready var item_type_label: Label = $VBox/ItemInfoBox/ItemTypeLabel
@onready var item_affixes_label: Label = $VBox/ItemInfoBox/ItemAffixesLabel

# 通货按钮与说明
@onready var currency_grid: GridContainer = $VBox/CurrencyGrid
@onready var currency_desc_label: Label = $VBox/DescBox/CurrencyDescLabel
@onready var craft_status_label: Label = $VBox/ActionBox/StatusLabel
@onready var execute_craft_btn: Button = $VBox/ActionBox/ExecuteCraftBtn

var current_item: Dictionary = {}
var is_equipped: bool = false
var bag_index: int = -1
var selected_currency_id: String = "transmutation"

var _currency_buttons: Dictionary = {}

func _ready() -> void:
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	
	execute_craft_btn.pressed.connect(_on_execute_craft_pressed)
	CraftingManager.currencies_updated.connect(_on_currencies_updated)
	
	_setup_currency_buttons()

func _setup_currency_buttons() -> void:
	for child in currency_grid.get_children():
		child.queue_free()
	_currency_buttons.clear()
	
	var all_curr = DataLoader.get_all_currencies()
	for cid in all_curr.keys():
		var c_data = all_curr[cid]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 26)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 10)
		btn.text = "%s (%d)" % [c_data.get("name_cn", "通货"), CraftingManager.get_currency_count(cid)]
		btn.modulate = Color(c_data.get("rarity_color", "#ffffff"))
		btn.pressed.connect(func(): _select_currency(cid))
		currency_grid.add_child(btn)
		_currency_buttons[cid] = btn

func open_for_item(item: Dictionary, p_is_equipped: bool = false, p_bag_idx: int = -1) -> void:
	current_item = item
	is_equipped = p_is_equipped
	bag_index = p_bag_idx
	visible = true
	
	# 自动根据装备品质推荐选中的通货
	var r = item.get("rarity", "normal")
	if r == "normal":
		selected_currency_id = "transmutation"
	elif r == "magic":
		selected_currency_id = "alteration"
	elif r == "rare":
		selected_currency_id = "chaos"
	else:
		selected_currency_id = "transmutation"
	
	_refresh_all()

func _select_currency(cid: String) -> void:
	selected_currency_id = cid
	_refresh_all()

func _on_currencies_updated(_currencies: Dictionary) -> void:
	_refresh_currency_buttons()
	_check_craft_validity()

func _refresh_all() -> void:
	_refresh_item_display()
	_refresh_currency_buttons()
	_refresh_currency_desc()
	_check_craft_validity()

func _refresh_item_display() -> void:
	if current_item.is_empty():
		item_name_label.text = "【未选择装备】"
		item_type_label.text = "请从背包中选择一件装备进行打造"
		item_affixes_label.text = ""
		if item_icon_rect:
			item_icon_rect.visible = false
		return
	
	var r_color = current_item.get("rarity_color", "#ffffff")
	item_name_label.text = current_item.get("name_cn", "装备")
	item_name_label.modulate = Color(r_color)
	
	var slot = current_item.get("slot", "")
	var slot_icon = DataLoader.get_slot_icon(slot)
	if item_icon_rect:
		item_icon_rect.texture = slot_icon
		item_icon_rect.visible = (slot_icon != null)
		item_icon_rect.modulate = Color(r_color)
	
	var slot_cn = _get_slot_name_cn(slot)
	var r_cn = current_item.get("rarity_name_cn", "普通")
	var ilvl = int(current_item.get("item_level", current_item.get("required_level", 1)))
	
	var p_cnt = 0
	var s_cnt = 0
	var aff_lines = []
	for aff in current_item.get("affixes", []):
		var type_str = "前缀" if aff.get("type") == "prefix" else "后缀"
		if aff.get("type") == "prefix": p_cnt += 1
		else: s_cnt += 1
		
		var tier = int(aff.get("tier", 5))
		var name_cn = aff.get("name_cn", "")
		var desc = aff.get("desc", "")
		var is_pct = aff.get("is_percentage", false)
		var min_v = aff.get("min_value")
		var max_v = aff.get("max_value")
		var range_str = ""
		if min_v != null and max_v != null:
			range_str = "[%.0f%%~%.0f%%]" % [float(min_v) * 100.0, float(max_v) * 100.0] if is_pct else "[%d~%d]" % [int(min_v), int(max_v)]
		
		var line_str = "• [%s T%d] %s: %s %s" % [type_str, tier, name_cn, desc, range_str] if name_cn != "" else "• [%s T%d] %s %s" % [type_str, tier, desc, range_str]
		aff_lines.append(line_str)
	
	var max_p = 1 if current_item.get("rarity") == "magic" else (3 if current_item.get("rarity") == "rare" else 0)
	var max_s = 1 if current_item.get("rarity") == "magic" else (3 if current_item.get("rarity") == "rare" else 0)
	var slot_info = " (前缀: %d/%d | 后缀: %d/%d)" % [p_cnt, max_p, s_cnt, max_s] if max_p > 0 else ""
	item_type_label.text = "【%s】 iLvl.%d  品质: [%s]%s" % [slot_cn, ilvl, r_cn, slot_info]
	
	if aff_lines.is_empty():
		item_affixes_label.text = "（当前无附加词缀）"
		item_affixes_label.modulate = Color(0.6, 0.6, 0.6)
	else:
		item_affixes_label.text = "\n".join(aff_lines)
		item_affixes_label.modulate = Color(0.4, 0.7, 1.0) if current_item.get("rarity") == "magic" else Color(0.95, 0.85, 0.3)

func _refresh_currency_buttons() -> void:
	var all_curr = DataLoader.get_all_currencies()
	for cid in _currency_buttons.keys():
		var btn = _currency_buttons[cid] as Button
		var c_data = all_curr.get(cid, {})
		var count = CraftingManager.get_currency_count(cid)
		btn.text = "%s%s (%d)" % [
			"> " if cid == selected_currency_id else "",
			c_data.get("name_cn", "通货"),
			count
		]

func _refresh_currency_desc() -> void:
	var c_data = DataLoader.get_currency_data(selected_currency_id)
	if c_data.is_empty():
		currency_desc_label.text = ""
		return
	
	currency_desc_label.text = "【%s】: %s" % [
		c_data.get("name_cn", "通货"),
		c_data.get("description", "")
	]
	currency_desc_label.modulate = Color(c_data.get("rarity_color", "#ffffff"))

func _check_craft_validity() -> void:
	var check = CraftingManager.can_apply_currency(selected_currency_id, current_item)
	if check["can_craft"]:
		craft_status_label.text = "准备就绪，点击下方按钮开始打造！"
		craft_status_label.modulate = Color(0.4, 0.85, 0.45)
		execute_craft_btn.disabled = false
	else:
		craft_status_label.text = "不可用: %s" % check["reason"]
		craft_status_label.modulate = Color(0.95, 0.45, 0.45)
		execute_craft_btn.disabled = true

func _on_execute_craft_pressed() -> void:
	if current_item.is_empty():
		return
	
	var res = CraftingManager.craft_item(selected_currency_id, current_item)
	if res["success"]:
		current_item = res["item"]
		
		# 同步写回装备系统
		if is_equipped:
			var slot = current_item.get("slot", "")
			InventoryManager.equipped_slots[slot] = current_item
			InventoryManager.equipment_updated.emit()
			EventBus.player_stats_changed.emit(InventoryManager.get_total_player_stats())
		else:
			if bag_index >= 0 and bag_index < InventoryManager.bag_items.size():
				InventoryManager.bag_items[bag_index] = current_item
				InventoryManager.inventory_updated.emit()
		
		_refresh_all()
		item_crafted_refresh.emit()

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
