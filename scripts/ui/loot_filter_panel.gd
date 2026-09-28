extends PanelContainer

## LootFilterPanel: 装备掉落过滤设置界面控制器
## 提供预设模板切换、品质/部位开关、词缀门槛、自动出售/舍弃动作配置及实时响应

signal closed

@onready var close_btn: Button = $VBox/HeaderBox/CloseBtn
@onready var preset_option: OptionButton = $VBox/PresetRow/PresetOption

# 品质复选框
@onready var normal_check: CheckBox = $VBox/RarityBox/NormalCheck
@onready var magic_check: CheckBox = $VBox/RarityBox/MagicCheck
@onready var rare_check: CheckBox = $VBox/RarityBox/RareCheck
@onready var legendary_check: CheckBox = $VBox/RarityBox/LegendaryCheck

# 部位复选框
@onready var weapon_check: CheckBox = $VBox/SlotsGrid/WeaponCheck
@onready var helmet_check: CheckBox = $VBox/SlotsGrid/HelmetCheck
@onready var chest_check: CheckBox = $VBox/SlotsGrid/ChestCheck
@onready var gloves_check: CheckBox = $VBox/SlotsGrid/GlovesCheck
@onready var boots_check: CheckBox = $VBox/SlotsGrid/BootsCheck
@onready var amulet_check: CheckBox = $VBox/SlotsGrid/AmuletCheck
@onready var ring_check: CheckBox = $VBox/SlotsGrid/RingCheck
@onready var select_all_slots_btn: Button = $VBox/SlotsHeader/SlotsActionBox/SelectAllBtn
@onready var select_none_slots_btn: Button = $VBox/SlotsHeader/SlotsActionBox/SelectNoneBtn

# 进阶与动作
@onready var min_affix_option: OptionButton = $VBox/AdvanceRow/MinAffixOption
@onready var action_option: OptionButton = $VBox/AdvanceRow/ActionOption
@onready var log_check: CheckBox = $VBox/LogCheck

# 底部按键
@onready var reset_btn: Button = $VBox/FooterBox/ResetBtn
@onready var apply_btn: Button = $VBox/FooterBox/ApplyBtn

var _is_updating_ui: bool = false

const PRESET_MAP = [
	"all",
	"hide_normal",
	"hide_normal_magic",
	"strict",
	"custom"
]

func _ready() -> void:
	_setup_options()
	_bind_events()
	
	if is_instance_valid(LootFilterManager):
		LootFilterManager.filter_config_updated.connect(_on_filter_config_updated)
	
	refresh_ui()

func _setup_options() -> void:
	preset_option.clear()
	preset_option.add_item("全部拾取 (不过滤)", 0)
	preset_option.add_item("过滤普通白装", 1)
	preset_option.add_item("过滤白装与蓝装 (推荐)", 2)
	preset_option.add_item("严格过滤 (暗金/高词缀稀有)", 3)
	preset_option.add_item("自定义配置", 4)
	
	min_affix_option.clear()
	min_affix_option.add_item("不限词缀", 0)
	min_affix_option.add_item("至少 1 条词缀", 1)
	min_affix_option.add_item("至少 2 条词缀", 2)
	min_affix_option.add_item("至少 3 条词缀", 3)
	
	action_option.clear()
	action_option.add_item("自动出售折算金币 (推荐)", 0)
	action_option.add_item("直接丢弃/舍弃", 1)
	
	# 设置部位勾选框小图标
	weapon_check.icon = DataLoader.get_slot_icon("weapon")
	weapon_check.expand_icon = true
	helmet_check.icon = DataLoader.get_slot_icon("helmet")
	helmet_check.expand_icon = true
	chest_check.icon = DataLoader.get_slot_icon("chest")
	chest_check.expand_icon = true
	gloves_check.icon = DataLoader.get_slot_icon("gloves")
	gloves_check.expand_icon = true
	boots_check.icon = DataLoader.get_slot_icon("boots")
	boots_check.expand_icon = true
	amulet_check.icon = DataLoader.get_slot_icon("amulet")
	amulet_check.expand_icon = true
	ring_check.icon = DataLoader.get_slot_icon("ring")
	ring_check.expand_icon = true

func _bind_events() -> void:
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	
	apply_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	
	reset_btn.pressed.connect(func():
		if is_instance_valid(LootFilterManager):
			LootFilterManager.reset_to_default()
	)
	
	preset_option.item_selected.connect(_on_preset_selected)
	min_affix_option.item_selected.connect(_on_min_affix_selected)
	action_option.item_selected.connect(_on_action_selected)
	
	normal_check.toggled.connect(func(t): _on_rarity_toggled("normal", t))
	magic_check.toggled.connect(func(t): _on_rarity_toggled("magic", t))
	rare_check.toggled.connect(func(t): _on_rarity_toggled("rare", t))
	legendary_check.toggled.connect(func(t): _on_rarity_toggled("legendary", t))
	
	weapon_check.toggled.connect(func(t): _on_slot_toggled("weapon", t))
	helmet_check.toggled.connect(func(t): _on_slot_toggled("helmet", t))
	chest_check.toggled.connect(func(t): _on_slot_toggled("chest", t))
	gloves_check.toggled.connect(func(t): _on_slot_toggled("gloves", t))
	boots_check.toggled.connect(func(t): _on_slot_toggled("boots", t))
	amulet_check.toggled.connect(func(t): _on_slot_toggled("amulet", t))
	ring_check.toggled.connect(func(t): _on_slot_toggled("ring", t))
	
	select_all_slots_btn.pressed.connect(func():
		if is_instance_valid(LootFilterManager):
			LootFilterManager.set_all_slots_rule(true)
	)
	select_none_slots_btn.pressed.connect(func():
		if is_instance_valid(LootFilterManager):
			LootFilterManager.set_all_slots_rule(false)
	)
	
	log_check.toggled.connect(func(t):
		if not _is_updating_ui and is_instance_valid(LootFilterManager):
			LootFilterManager.set_show_filtered_log(t)
	)

func refresh_ui() -> void:
	if not is_instance_valid(LootFilterManager):
		return
	_is_updating_ui = true
	
	var conf = LootFilterManager.get_config()
	var cur_p = conf.get("preset", "hide_normal_magic")
	var idx = PRESET_MAP.find(cur_p)
	if idx != -1:
		preset_option.selected = idx
	else:
		preset_option.selected = 4 # custom
	
	var rarities = conf.get("rarity_rules", {})
	normal_check.set_pressed_no_signal(rarities.get("normal", false))
	magic_check.set_pressed_no_signal(rarities.get("magic", false))
	rare_check.set_pressed_no_signal(rarities.get("rare", true))
	legendary_check.set_pressed_no_signal(rarities.get("legendary", true))
	
	var slots = conf.get("slot_rules", {})
	weapon_check.set_pressed_no_signal(slots.get("weapon", true))
	helmet_check.set_pressed_no_signal(slots.get("helmet", true))
	chest_check.set_pressed_no_signal(slots.get("chest", true))
	gloves_check.set_pressed_no_signal(slots.get("gloves", true))
	boots_check.set_pressed_no_signal(slots.get("boots", true))
	amulet_check.set_pressed_no_signal(slots.get("amulet", true))
	ring_check.set_pressed_no_signal(slots.get("ring", true))
	
	var aff_cnt = int(conf.get("min_affixes_count", 0))
	min_affix_option.selected = mini(3, aff_cnt)
	
	var act = conf.get("filter_action", "auto_sell")
	action_option.selected = 0 if act == "auto_sell" else 1
	
	log_check.set_pressed_no_signal(conf.get("show_filtered_log", true))
	
	_is_updating_ui = false

func _on_preset_selected(idx: int) -> void:
	if _is_updating_ui: return
	if idx >= 0 and idx < PRESET_MAP.size():
		var p_name = PRESET_MAP[idx]
		if is_instance_valid(LootFilterManager):
			LootFilterManager.apply_preset(p_name)

func _on_rarity_toggled(rarity: String, val: bool) -> void:
	if _is_updating_ui: return
	if is_instance_valid(LootFilterManager):
		LootFilterManager.set_rarity_rule(rarity, val)

func _on_slot_toggled(slot: String, val: bool) -> void:
	if _is_updating_ui: return
	if is_instance_valid(LootFilterManager):
		LootFilterManager.set_slot_rule(slot, val)

func _on_min_affix_selected(idx: int) -> void:
	if _is_updating_ui: return
	if is_instance_valid(LootFilterManager):
		LootFilterManager.set_min_affixes_count(idx)

func _on_action_selected(idx: int) -> void:
	if _is_updating_ui: return
	if is_instance_valid(LootFilterManager):
		var act = "auto_sell" if idx == 0 else "discard"
		LootFilterManager.set_filter_action(act)

func _on_filter_config_updated(_conf: Dictionary) -> void:
	refresh_ui()
