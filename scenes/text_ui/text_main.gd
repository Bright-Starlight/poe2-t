extends Control

## TextMain: 文字版打宝挂机 ARPG 主场景控制器
## 驱动三栏暗黑 MUD 界面、文字战斗流、7大部位装备栏、背包交互、属性加点、通货打造工坊、被动星盘与异界大秘境

@onready var battle_engine: Node = $TextBattleEngine
@onready var item_tooltip: PanelContainer = $ItemTooltip
@onready var attr_panel: PanelContainer = $AttributePanel
@onready var craft_panel: PanelContainer = $CraftingPanel
@onready var talent_panel: PanelContainer = $TalentTreePanel
@onready var rift_panel: PanelContainer = $RiftPanel
@onready var filter_panel: PanelContainer = $LootFilterPanel
@onready var waystone_panel: PanelContainer = $WaystonePanel

# 左栏引用
@onready var lvl_label: Label = $HBox/LeftPanel/VBox/PlayerHeader/LvlLabel
@onready var gold_label: Label = $HBox/LeftPanel/VBox/PlayerHeader/GoldLabel
@onready var attr_open_btn: Button = $HBox/LeftPanel/VBox/BuildButtons/AttrOpenBtn
@onready var talent_open_btn: Button = $HBox/LeftPanel/VBox/BuildButtons/TalentOpenBtn
@onready var exp_bar: ProgressBar = $HBox/LeftPanel/VBox/ExpBar
@onready var exp_text: Label = $HBox/LeftPanel/VBox/ExpBar/ExpText
@onready var hp_bar: ProgressBar = $HBox/LeftPanel/VBox/HpBar
@onready var hp_text: Label = $HBox/LeftPanel/VBox/HpBar/HpText
@onready var mp_bar: ProgressBar = $HBox/LeftPanel/VBox/MpBar
@onready var mp_text: Label = $HBox/LeftPanel/VBox/MpBar/MpText
@onready var equip_grid: GridContainer = $HBox/LeftPanel/VBox/EquipGrid
@onready var stats_summary_label: Label = $HBox/LeftPanel/VBox/StatsSummaryLabel

# 中栏引用
@onready var map_progress_box: PanelContainer = $HBox/CenterPanel/VBox/MapProgressBox
@onready var map_bar: ProgressBar = $HBox/CenterPanel/VBox/MapProgressBox/MapBar
@onready var map_text: Label = $HBox/CenterPanel/VBox/MapProgressBox/MapBar/MapText

@onready var squad_box: PanelContainer = $HBox/CenterPanel/VBox/SquadMonsterBox
@onready var squad_container: HBoxContainer = $HBox/CenterPanel/VBox/SquadMonsterBox/SquadList
@onready var log_display: RichTextLabel = $HBox/CenterPanel/VBox/LogDisplay
@onready var manual_attack_btn: Button = $HBox/CenterPanel/VBox/SkillActions/AttackBtn
@onready var skill_btn_1: Button = $HBox/CenterPanel/VBox/SkillActions/Skill1Btn
@onready var skill_btn_2: Button = $HBox/CenterPanel/VBox/SkillActions/Skill2Btn
@onready var skill_btn_3: Button = $HBox/CenterPanel/VBox/SkillActions/Skill3Btn

# 右栏引用
@onready var map_option: OptionButton = $HBox/RightPanel/VBox/MapOption
@onready var start_battle_btn: Button = $HBox/RightPanel/VBox/StartBattleBtn
@onready var auto_toggle_btn: Button = $HBox/RightPanel/VBox/AutoToggleBtn
@onready var idle_simulate_btn: Button = $HBox/RightPanel/VBox/ActionRow/IdleSimulateBtn
@onready var rift_open_btn: Button = $HBox/RightPanel/VBox/ActionRow/RiftOpenBtn
@onready var craft_open_btn: Button = $HBox/RightPanel/VBox/ActionRow2/CraftOpenBtn
@onready var filter_open_btn: Button = $HBox/RightPanel/VBox/ActionRow2/FilterOpenBtn
@onready var filter_status_label: Label = $HBox/RightPanel/VBox/FilterStatusLabel
@onready var sell_normal_btn: Button = $HBox/RightPanel/VBox/SellNormalBtn
@onready var bag_capacity_label: Label = $HBox/RightPanel/VBox/BagHeader/CapacityLabel
@onready var bag_container: VBoxContainer = $HBox/RightPanel/VBox/Scroll/BagList

var _equip_slot_buttons: Dictionary = {}
var _all_maps_list: Array[String] = []

func _ready() -> void:
	print("[TextMain] Initializing Text-Based ARPG UI...")
	
	# 绑定引擎信号
	battle_engine.battle_log_emitted.connect(_on_battle_log_emitted)
	battle_engine.monsters_squad_updated.connect(_on_monsters_squad_updated)
	battle_engine.map_progress_updated.connect(_on_map_progress_updated)
	battle_engine.player_state_updated.connect(_on_player_state_updated)
	battle_engine.skill_cooldowns_updated.connect(_on_skill_cooldowns_updated)
	battle_engine.exploration_state_changed.connect(_on_exploration_state_changed)
	
	# 绑定背包、属性与天赋信号
	InventoryManager.equipment_updated.connect(_refresh_equipment_ui)
	InventoryManager.inventory_updated.connect(_refresh_inventory_ui)
	InventoryManager.gold_updated.connect(_refresh_gold_ui)
	InventoryManager.exp_updated.connect(_refresh_exp_ui)
	InventoryManager.stat_points_updated.connect(_on_stat_points_updated)
	TalentManager.talents_updated.connect(_on_talents_updated)
	
	# 绑定工坊与引路石信号
	CraftingManager.item_crafted.connect(_on_item_crafted)
	craft_panel.item_crafted_refresh.connect(_refresh_all_ui)
	
	rift_open_btn.pressed.connect(func():
		waystone_panel.visible = !waystone_panel.visible
		if waystone_panel.visible: waystone_panel.refresh_ui()
	)
	
	waystone_panel.waystone_activated.connect(func(ws):
		battle_engine.start_waystone(ws)
	)
	
	# 绑定交互按键
	manual_attack_btn.pressed.connect(func(): battle_engine._execute_player_attack())
	skill_btn_1.pressed.connect(func(): battle_engine.cast_skill("fireball"))
	skill_btn_2.pressed.connect(func(): battle_engine.cast_skill("whirlwind"))
	skill_btn_3.pressed.connect(func(): battle_engine.cast_skill("dash"))
	
	start_battle_btn.pressed.connect(_on_start_battle_pressed)
	auto_toggle_btn.pressed.connect(_on_auto_toggle_pressed)
	idle_simulate_btn.pressed.connect(_on_idle_simulate_pressed)
	sell_normal_btn.pressed.connect(_on_sell_normal_pressed)
	map_option.item_selected.connect(_on_map_selected)
	
	attr_open_btn.pressed.connect(func():
		attr_panel.visible = !attr_panel.visible
		if attr_panel.visible: attr_panel.refresh_ui()
	)
	
	talent_open_btn.pressed.connect(func():
		talent_panel.visible = !talent_panel.visible
		if talent_panel.visible: talent_panel.refresh_ui()
	)
	
	filter_open_btn.pressed.connect(func():
		filter_panel.visible = !filter_panel.visible
		if filter_panel.visible: filter_panel.refresh_ui()
	)
	
	craft_open_btn.pressed.connect(_open_default_crafting)
	
	if is_instance_valid(LootFilterManager):
		LootFilterManager.filter_config_updated.connect(func(_cfg): _refresh_filter_status())
	
	_setup_map_selector()
	_setup_equipment_slots()
	_refresh_all_ui()
	
	_check_offline_report()
	
	# 默认开启探索
	battle_engine.start_exploration(_all_maps_list[0] if not _all_maps_list.is_empty() else "forest_1")

func _check_offline_report() -> void:
	if not GameManager.offline_report_pending.is_empty():
		var sec = float(GameManager.offline_report_pending.get("elapsed_seconds", 0))
		var real_sec = int(GameManager.offline_report_pending.get("real_seconds", 0))
		var res = battle_engine.simulate_idle(sec)
		
		battle_engine.emit_log("[color=#f6ad55]====== 欢迎归来！离线打宝收益报告 ======[/color]")
		battle_engine.emit_log("• 离线时长: [b]%d[/b] 秒 (挂机结算: %.0f 秒)" % [real_sec, sec])
		battle_engine.emit_log("• 斩杀怪物: [b]%d[/b] 只 (含精英怪)" % res["kills"])
		battle_engine.emit_log("• 累计获得经验: [color=#63b3ed]+%d[/color]" % res["exp"])
		battle_engine.emit_log("• 累计获得金币: [color=#f6e05e]+%d[/color]" % res["gold"])
		battle_engine.emit_log("• 拾取入包装备: [color=#48bb78]+%d[/color] 件" % res["items_count"])
		if int(res.get("filtered_count", 0)) > 0:
			battle_engine.emit_log("• 掉落过滤回收: [color=#f6ad55]%d[/color] 件装备 (自动折算金币 [color=#f6e05e]+%d[/color])" % [
				res["filtered_count"], res.get("filtered_gold", 0)
			])
		
		var curr_lines = []
		for cid in res["currencies"].keys():
			var c_data = DataLoader.get_currency_data(cid)
			curr_lines.append("%s x%d" % [c_data.get("name_cn", "通货"), res["currencies"][cid]])
		if not curr_lines.is_empty():
			battle_engine.emit_log("• 斩获打造通货: [color=#ed8936]%s[/color]" % ", ".join(curr_lines))
		battle_engine.emit_log("[color=#f6ad55]========================================[/color]")
		
		GameManager.offline_report_pending.clear()

func _open_default_crafting() -> void:
	if not InventoryManager.bag_items.is_empty():
		craft_panel.open_for_item(InventoryManager.bag_items[0], false, 0)
	elif InventoryManager.equipped_slots.get("weapon") != null:
		craft_panel.open_for_item(InventoryManager.equipped_slots["weapon"], true, -1)
	else:
		craft_panel.open_for_item({}, false, -1)

func _setup_map_selector() -> void:
	map_option.clear()
	var maps = DataLoader.get_all_maps()
	_all_maps_list.clear()
	var idx = 0
	for m_id in maps.keys():
		_all_maps_list.append(m_id)
		var m_data = maps[m_id]
		var title = "%s (%s)" % [m_data.get("name_cn", "地图"), m_data.get("recommended_level", "")]
		map_option.add_item(title, idx)
		idx += 1

func _setup_equipment_slots() -> void:
	var slots = ["weapon", "helmet", "chest", "gloves", "boots", "amulet", "ring"]
	for s in slots:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 26)
		btn.clip_text = true
		btn.icon = DataLoader.get_slot_icon(s)
		btn.expand_icon = true
		btn.text = "%s: [空]" % _get_slot_name_cn(s)
		btn.mouse_entered.connect(func(): _show_slot_tooltip(s))
		btn.mouse_exited.connect(func(): item_tooltip.visible = false)
		btn.pressed.connect(func(): _on_equip_slot_clicked(s))
		equip_grid.add_child(btn)
		_equip_slot_buttons[s] = btn

func _refresh_all_ui() -> void:
	_refresh_equipment_ui()
	_refresh_inventory_ui()
	_refresh_gold_ui(InventoryManager.gold)
	_refresh_exp_ui(InventoryManager.current_exp, InventoryManager.max_exp, InventoryManager.level)
	_on_stat_points_updated(
		InventoryManager.unspent_stat_points,
		InventoryManager.allocated_strength,
		InventoryManager.allocated_dexterity,
		InventoryManager.allocated_intelligence
	)
	_on_talents_updated(TalentManager.allocated_nodes, TalentManager.unspent_talent_points)
	_refresh_stats_summary()
	_refresh_filter_status()

func _refresh_filter_status() -> void:
	if is_instance_valid(LootFilterManager) and filter_status_label:
		filter_status_label.text = LootFilterManager.get_summary_text()

func _refresh_equipment_ui() -> void:
	for s in _equip_slot_buttons.keys():
		var btn = _equip_slot_buttons[s] as Button
		var item = InventoryManager.equipped_slots.get(s)
		btn.icon = DataLoader.get_slot_icon(s)
		btn.expand_icon = true
		if item != null and not item.is_empty():
			btn.text = "%s" % item.get("name_cn", "装备")
			btn.modulate = Color(item.get("rarity_color", "#ffffff"))
		else:
			btn.text = "%s: [空]" % _get_slot_name_cn(s)
			btn.modulate = Color(0.65, 0.65, 0.65)
	_refresh_stats_summary()

func _refresh_inventory_ui() -> void:
	for child in bag_container.get_children():
		child.queue_free()
	
	var items = InventoryManager.bag_items
	bag_capacity_label.text = "%d / %d" % [items.size(), InventoryManager.MAX_BAG_CAPACITY]
	
	for i in range(items.size()):
		var it = items[i]
		var slot = it.get("slot", "")
		var row = HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 24)
		row.add_theme_constant_override("separation", 2)
		
		# 装备穿戴按键 (附带部位小图标)
		var it_btn = Button.new()
		it_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		it_btn.clip_text = true
		it_btn.icon = DataLoader.get_slot_icon(slot)
		it_btn.expand_icon = true
		it_btn.text = "[%s] %s" % [it.get("rarity_name_cn", "普通"), it.get("name_cn", "装备")]
		it_btn.modulate = Color(it.get("rarity_color", "#ffffff"))
		it_btn.mouse_entered.connect(func(): _show_tooltip_at_mouse(it, false, i))
		it_btn.mouse_exited.connect(func(): item_tooltip.visible = false)
		it_btn.pressed.connect(func(): InventoryManager.equip_item(it))
		row.add_child(it_btn)
		
		# 打造工坊按键
		var craft_btn = Button.new()
		craft_btn.text = "造"
		craft_btn.modulate = Color(0.95, 0.85, 0.3)
		craft_btn.custom_minimum_size = Vector2(24, 0)
		craft_btn.pressed.connect(func(): craft_panel.open_for_item(it, false, i))
		row.add_child(craft_btn)
		
		# 出售按键
		var sell_btn = Button.new()
		sell_btn.text = "售"
		sell_btn.custom_minimum_size = Vector2(24, 0)
		sell_btn.pressed.connect(func(): InventoryManager.sell_item_at(i))
		row.add_child(sell_btn)
		
		bag_container.add_child(row)

func _refresh_stats_summary() -> void:
	var stats = InventoryManager.get_total_player_stats()
	var atk = stats.get("attack_damage", 0.0)
	var aspd = stats.get("attack_speed", 1.2)
	var crit_r = stats.get("crit_rate", 0.05) * 100.0
	var crit_d = stats.get("crit_damage", 1.5) * 100.0
	var arm = stats.get("armor", 0.0)
	var eva = stats.get("evasion", 0.0)
	var f_dmg = stats.get("fire_damage", 0.0)
	var c_dmg = stats.get("cold_damage", 0.0)
	var l_dmg = stats.get("lightning_damage", 0.0)
	var f_res = clampf(float(stats.get("fire_res", 0.0)) * 100.0, -60.0, 75.0)
	var c_res = clampf(float(stats.get("cold_res", 0.0)) * 100.0, -60.0, 75.0)
	var l_res = clampf(float(stats.get("lightning_res", 0.0)) * 100.0, -60.0, 75.0)
	var mv_spd = float(stats.get("move_speed_pct", 0.0)) * 100.0
	
	var dps = (atk + f_dmg + c_dmg + l_dmg) * aspd * (1.0 + (crit_r / 100.0) * (crit_d / 100.0 - 1.0))
	
	var mv_str = " (移速+%.0f%%)" % mv_spd if mv_spd > 0 else ""
	stats_summary_label.text = "【综合DPS】: %.0f\n• 基础攻击: %.0f (攻速: %.1f/s)%s\n• 暴击几率: %.1f%% (倍率: %.0f%%)\n• 物理护甲: %.0f | 敏捷闪避: %.0f\n• 元素附加: 火+%.0f 冰+%.0f 雷+%.0f\n• 元素抗性: 火%.0f%% | 冰%.0f%% | 雷%.0f%%" % [
		dps, atk, aspd, mv_str, crit_r, crit_d, arm, eva, f_dmg, c_dmg, l_dmg, f_res, c_res, l_res
	]

func _show_slot_tooltip(slot_name: String) -> void:
	var it = InventoryManager.equipped_slots.get(slot_name)
	if it != null and not it.is_empty():
		_show_tooltip_at_mouse(it, true, -1)

func _show_tooltip_at_mouse(item_data: Dictionary, is_equipped: bool, bag_idx: int) -> void:
	item_tooltip.display_item(item_data, is_equipped, bag_idx)
	var m_pos = get_viewport().get_mouse_position()
	var tt_size = item_tooltip.get_combined_minimum_size()
	var target_x = m_pos.x + 12.0
	var target_y = m_pos.y + 12.0
	
	var vp_size = get_viewport_rect().size
	if target_x + tt_size.x > vp_size.x:
		target_x = max(6.0, m_pos.x - tt_size.x - 12.0)
	if target_y + tt_size.y > vp_size.y:
		target_y = max(6.0, vp_size.y - tt_size.y - 12.0)
	
	item_tooltip.global_position = Vector2(target_x, target_y)
	item_tooltip.visible = true

func _on_equip_slot_clicked(slot_name: String) -> void:
	var it = InventoryManager.equipped_slots.get(slot_name)
	if it != null and not it.is_empty():
		craft_panel.open_for_item(it, true, -1)

func _refresh_gold_ui(gold: int) -> void:
	gold_label.text = "金币: %d" % gold

func _refresh_exp_ui(cur_exp: int, max_exp: int, lvl: int) -> void:
	lvl_label.text = "狂战士 Lv.%d" % lvl
	exp_bar.max_value = max_exp
	exp_bar.value = cur_exp
	exp_text.text = "EXP: %d / %d (%.0f%%)" % [cur_exp, max_exp, (float(cur_exp) / max(1, max_exp)) * 100.0]

func _on_stat_points_updated(unspent: int, _s: int, _d: int, _i: int) -> void:
	if unspent > 0:
		attr_open_btn.text = "[ 属性 (+%d) ]" % unspent
		attr_open_btn.modulate = Color(0.95, 0.85, 0.3)
	else:
		attr_open_btn.text = "[ 属性加点 ]"
		attr_open_btn.modulate = Color(0.85, 0.88, 0.95)
	
	_refresh_stats_summary()

func _on_talents_updated(_alloc_nodes: Array, unspent: int) -> void:
	if unspent > 0:
		talent_open_btn.text = "[ 天赋 (+%d) ]" % unspent
		talent_open_btn.modulate = Color(0.95, 0.85, 0.3)
	else:
		talent_open_btn.text = "[ 天赋星盘 ]"
		talent_open_btn.modulate = Color(0.85, 0.88, 0.95)
	
	_refresh_stats_summary()

func _on_map_progress_updated(killed: int, total: int, remaining: int, is_active: bool, map_title: String, is_boss: bool) -> void:
	map_progress_box.visible = is_active
	if is_active:
		map_bar.max_value = total
		map_bar.value = killed
		if is_boss:
			map_text.text = "【%s】 ⚠️ 史诗首领已降临战场！全力诛杀！" % map_title
		else:
			map_text.text = "【%s】 清图进度: %d / %d (剩余怪群: %d 只)" % [map_title, killed, total, remaining]

func _on_monsters_squad_updated(squad: Array, focused_idx: int) -> void:
	for child in squad_container.get_children():
		child.queue_free()
	
	if squad.is_empty():
		squad_box.visible = false
		return
	
	squad_box.visible = true
	
	for i in range(squad.size()):
		var m = squad[i]
		var is_focused = (i == focused_idx)
		
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 42)
		
		var card_vbox = VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 2)
		
		var name_btn = Button.new()
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_btn.clip_text = true
		name_btn.add_theme_font_size_override("font_size", 10)
		
		var focus_tag = "[🎯锁定] " if is_focused else ""
		var status_tag = ""
		if float(m.get("shock_timer", 0.0)) > 0.0: status_tag += "⚡"
		if float(m.get("bleed_timer", 0.0)) > 0.0: status_tag += "🩸"
		
		var r_badge = ""
		var m_rarity = m.get("rarity", "normal")
		if m_rarity == "unique" or m.get("is_boss", false):
			r_badge = "[👑首领] "
		elif m_rarity == "rare":
			r_badge = "[⭐稀有] "
		elif m_rarity == "magic":
			r_badge = "[✨魔法] "
		
		name_btn.text = "%s%s%s%s" % [focus_tag, r_badge, status_tag, m.get("name_cn", "怪物")]
		
		if is_focused:
			name_btn.modulate = Color(1.0, 1.0, 0.35)
		else:
			name_btn.modulate = Color(m.get("rarity_color", "#e2e8f0"))
		
		var target_idx = i
		name_btn.pressed.connect(func():
			battle_engine.set_focused_target(target_idx)
		)
		card_vbox.add_child(name_btn)
		
		var hp_bar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(0, 10)
		hp_bar.show_percentage = false
		var cur_hp = float(m.get("current_hp", 0))
		var max_hp = float(m.get("max_hp", 100))
		hp_bar.max_value = max_hp
		hp_bar.value = cur_hp
		
		var hp_lbl = Label.new()
		hp_lbl.anchors_preset = Control.PRESET_FULL_RECT
		hp_lbl.anchor_right = 1.0
		hp_lbl.anchor_bottom = 1.0
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_lbl.add_theme_font_size_override("font_size", 8)
		hp_lbl.text = "%.0f / %.0f" % [cur_hp, max_hp]
		hp_bar.add_child(hp_lbl)
		
		card_vbox.add_child(hp_bar)
		card.add_child(card_vbox)
		squad_container.add_child(card)

func _on_item_crafted(cid: String, _old_it: Dictionary, new_it: Dictionary, _success: bool, msg: String) -> void:
	var c_data = DataLoader.get_currency_data(cid)
	battle_engine.emit_log("[color=%s]【工坊打造】消耗【%s】: %s -> [%s] %s[/color]" % [
		c_data.get("rarity_color", "#63b3ed"),
		c_data.get("name_cn", "通货"),
		msg,
		new_it.get("rarity_name_cn", "品质"),
		new_it.get("name_cn", "装备")
	])

func _on_player_state_updated(hp: float, max_hp: float, mp: float, max_mp: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_text.text = "HP: %.0f / %.0f" % [hp, max_hp]
	
	mp_bar.max_value = max_mp
	mp_bar.value = mp
	mp_text.text = "MP: %.0f / %.0f" % [mp, max_mp]

func _on_skill_cooldowns_updated(cds: Dictionary) -> void:
	var cd1 = cds.get("fireball", 0.0)
	var cd2 = cds.get("whirlwind", 0.0)
	var cd3 = cds.get("dash", 0.0)
	
	skill_btn_1.text = "[1] 爆裂火球 (%.1fs)" % cd1 if cd1 > 0.05 else "[1] 爆裂火球 (15MP)"
	skill_btn_1.disabled = cd1 > 0.05
	
	skill_btn_2.text = "[2] 狂风旋斩 (%.1fs)" % cd2 if cd2 > 0.05 else "[2] 狂风旋斩 (22MP)"
	skill_btn_2.disabled = cd2 > 0.05
	
	skill_btn_3.text = "[3] 疾影闪烁 (%.1fs)" % cd3 if cd3 > 0.05 else "[3] 疾影闪烁 (10MP)"
	skill_btn_3.disabled = cd3 > 0.05

func _on_battle_log_emitted(bbcode_text: String) -> void:
	log_display.append_text(bbcode_text + "\n")

func _on_start_battle_pressed() -> void:
	if battle_engine.is_active:
		battle_engine.stop_exploration()
	else:
		battle_engine.start_exploration()

func _on_exploration_state_changed(is_active: bool) -> void:
	start_battle_btn.text = "[ 停止探索 ]" if is_active else "[ 开始探索打宝 ]"

func _on_auto_toggle_pressed() -> void:
	battle_engine.toggle_auto_combat()
	auto_toggle_btn.text = "自动战斗: ON" if battle_engine.is_auto_combat else "自动战斗: OFF"

func _on_map_selected(idx: int) -> void:
	if idx >= 0 and idx < _all_maps_list.size():
		var map_id = _all_maps_list[idx]
		battle_engine.start_exploration(map_id)

func _on_sell_normal_pressed() -> void:
	var earned = InventoryManager.sell_all_normal()
	battle_engine.emit_log("[color=#f6e05e]【一键回收】出售所有普通白装，获得金币 +%d！[/color]" % earned)

func _on_idle_simulate_pressed() -> void:
	var res = battle_engine.simulate_idle(60.0)
	battle_engine.emit_log("[color=#f6ad55]====== 离线挂机模拟报告 (60秒) ======[/color]")
	battle_engine.emit_log("• 模拟击杀怪物: [b]%d[/b] 只 (含精英怪)" % res["kills"])
	battle_engine.emit_log("• 累计获得经验: [color=#63b3ed]+%d[/color]" % res["exp"])
	battle_engine.emit_log("• 累计获得金币: [color=#f6e05e]+%d[/color]" % res["gold"])
	battle_engine.emit_log("• 掉落入包装备: [color=#48bb78]+%d[/color] 件" % res["items_count"])
	if int(res.get("filtered_count", 0)) > 0:
		battle_engine.emit_log("• 掉落过滤回收: [color=#f6ad55]%d[/color] 件垃圾装备 (自动折算金币 [color=#f6e05e]+%d[/color])" % [
			res["filtered_count"], res.get("filtered_gold", 0)
		])
	
	var curr_lines = []
	for cid in res["currencies"].keys():
		var c_data = DataLoader.get_currency_data(cid)
		curr_lines.append("%s x%d" % [c_data.get("name_cn", "通货"), res["currencies"][cid]])
	if not curr_lines.is_empty():
		battle_engine.emit_log("• 掉落打造通货: [color=#ed8936]%s[/color]" % ", ".join(curr_lines))
	battle_engine.emit_log("[color=#f6ad55]==================================[/color]")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_auto_combat"):
		_on_auto_toggle_pressed()
	elif event.is_action_pressed("attack"):
		battle_engine._execute_player_attack()
	elif event.is_action_pressed("skill_1"):
		battle_engine.cast_skill("fireball")
	elif event.is_action_pressed("skill_2"):
		battle_engine.cast_skill("whirlwind")
	elif event.is_action_pressed("skill_3"):
		battle_engine.cast_skill("dash")

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
