extends PanelContainer

## WaystonePanel: PoE2 异界引路石与地图8词缀工坊控制器
## 支持T1~T5引路石选择、基底固有词缀展示、最多8显式词缀展示、通货洗练打造与地图激活开图

signal closed
signal waystone_activated(waystone: Dictionary)

@onready var close_btn: Button = $VBox/HeaderBox/CloseBtn
@onready var tier_option: OptionButton = $VBox/TierRow/TierOption
@onready var roll_new_btn: Button = $VBox/TierRow/RollNewBtn

# 引路石信息展示区
@onready var waystone_name_label: Label = $VBox/InfoBox/NameRow/NameLabel
@onready var waystone_level_label: Label = $VBox/InfoBox/NameRow/LevelLabel
@onready var implicits_label: Label = $VBox/InfoBox/ImplicitsLabel
@onready var affixes_label: Label = $VBox/InfoBox/Scroll/AffixesLabel
@onready var summary_label: RichTextLabel = $VBox/InfoBox/SummaryLabel

# 通货打造按键栏
@onready var craft_msg_label: Label = $VBox/CraftBox/CraftHeader/CraftMsgLabel
@onready var currency_grid: GridContainer = $VBox/CraftBox/CurrencyGrid

# 底部激活按键
@onready var activate_btn: Button = $VBox/FooterBox/ActivateBtn

var current_waystone: Dictionary = {}
var _currency_buttons: Dictionary = {}

const WAYSTONE_IDS = [
	"t1_waystone",
	"t2_waystone",
	"t3_waystone",
	"t4_waystone",
	"t5_waystone"
]

func _ready() -> void:
	_setup_tier_selector()
	_setup_currency_buttons()
	_bind_events()
	
	if is_instance_valid(WaystoneManager):
		WaystoneManager.waystone_crafted.connect(_on_waystone_crafted)
	if is_instance_valid(CraftingManager):
		CraftingManager.currencies_updated.connect(func(_c): _refresh_currency_counts())
	
	# 默认生成 T1 引路石
	select_waystone_tier(0)

func _setup_tier_selector() -> void:
	tier_option.clear()
	var all_w = DataLoader.get_all_waystones()
	var idx = 0
	for wid in WAYSTONE_IDS:
		if all_w.has(wid):
			var w_data = all_w[wid]
			var t_name = "T%d: %s (%s)" % [w_data.get("tier", 1), w_data.get("name_cn", "引路石"), w_data.get("recommended_level", "")]
			tier_option.add_item(t_name, idx)
		idx += 1

func _setup_currency_buttons() -> void:
	for child in currency_grid.get_children():
		child.queue_free()
	_currency_buttons.clear()
	
	var craft_currencies = [
		{"id": "transmutation", "name": "蜕变"},
		{"id": "augmentation", "name": "增幅"},
		{"id": "alteration", "name": "改造"},
		{"id": "regal", "name": "富豪"},
		{"id": "chaos", "name": "混沌"},
		{"id": "exalted", "name": "崇高"},
		{"id": "scouring", "name": "重铸"},
		{"id": "vaal", "name": "瓦尔腐化"}
	]
	
	for c in craft_currencies:
		var cid = c["id"]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(82, 24)
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 9)
		btn.text = "%s (%d)" % [c["name"], CraftingManager.get_currency_count(cid)]
		btn.pressed.connect(func(): _on_craft_currency_clicked(cid))
		currency_grid.add_child(btn)
		_currency_buttons[cid] = btn

func _bind_events() -> void:
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	
	tier_option.item_selected.connect(_on_tier_selected)
	
	roll_new_btn.pressed.connect(func():
		var idx = tier_option.selected
		select_waystone_tier(idx, "rare")
	)
	
	activate_btn.pressed.connect(func():
		if not current_waystone.is_empty():
			visible = false
			waystone_activated.emit(current_waystone)
	)

func select_waystone_tier(tier_idx: int, rarity: String = "magic") -> void:
	if tier_idx >= 0 and tier_idx < WAYSTONE_IDS.size():
		var wid = WAYSTONE_IDS[tier_idx]
		if is_instance_valid(WaystoneManager):
			current_waystone = WaystoneManager.generate_waystone(wid, rarity)
		refresh_ui()

func _on_tier_selected(idx: int) -> void:
	select_waystone_tier(idx, "magic")

func _on_craft_currency_clicked(currency_id: String) -> void:
	if current_waystone.is_empty() or not is_instance_valid(WaystoneManager):
		return
	
	var res = WaystoneManager.craft_waystone(current_waystone, currency_id)
	if res["success"]:
		current_waystone = res["waystone"]
		craft_msg_label.text = res["reason"]
		craft_msg_label.modulate = Color(0.4, 0.9, 0.45)
	else:
		craft_msg_label.text = res["reason"]
		craft_msg_label.modulate = Color(0.95, 0.45, 0.45)
	
	refresh_ui()

func _on_waystone_crafted(_cid: String, _old: Dictionary, new_ws: Dictionary, _s: bool, _msg: String) -> void:
	current_waystone = new_ws
	refresh_ui()

func refresh_ui() -> void:
	if current_waystone.is_empty():
		return
	
	var r_color = current_waystone.get("rarity_color", "#ffffff")
	waystone_name_label.text = current_waystone.get("display_name", "引路石")
	waystone_name_label.modulate = Color(r_color)
	
	waystone_level_label.text = "【%s】 (基础怪数: %d)" % [
		current_waystone.get("recommended_level", ""),
		current_waystone.get("base_monsters_count", 20)
	]
	
	# 基底固有词缀
	var imp_lines = []
	for imp in current_waystone.get("base_implicits", []):
		imp_lines.append("• %s" % imp.get("desc", ""))
	implicits_label.text = "\n".join(imp_lines) if not imp_lines.is_empty() else "（无基底词缀）"
	
	# 显式词缀列表 (最多8条)
	var aff_lines = []
	for aff in current_waystone.get("affixes", []):
		var tag = "[前缀]" if aff.get("type") == "prefix" else "[后缀]"
		aff_lines.append("%s %s" % [tag, aff.get("desc", "")])
	
	if aff_lines.is_empty():
		affixes_label.text = "（普通白板引路石，可使用通货添加最多 8 条词缀）"
		affixes_label.modulate = Color(0.65, 0.65, 0.65)
	else:
		affixes_label.text = "\n".join(aff_lines)
		affixes_label.modulate = Color(r_color)
	
	# 综合总增幅
	var mods = current_waystone.get("modifiers_summary", {})
	var total_m = int(current_waystone.get("total_monsters_count", 25))
	var pack_cap = int(current_waystone.get("max_active_monsters", 3))
	
	summary_label.text = "【地图综合加成】 怪物总数: [b]%d[/b] 只 (同屏怪群: [b]%d[/b] 只) | 掉落数量: [color=#48bb78]+%.0f%%[/color] | 稀有度: [color=#f6e05e]+%.0f%%[/color] | 通货: [color=#ed8936]+%.0f%%[/color]" % [
		total_m, pack_cap,
		mods.get("item_quant_pct", 0.0) * 100.0,
		mods.get("item_rarity_pct", 0.0) * 100.0,
		mods.get("currency_mult_pct", 0.0) * 100.0
	]
	
	_refresh_currency_counts()

func _refresh_currency_counts() -> void:
	for cid in _currency_buttons.keys():
		var btn = _currency_buttons[cid] as Button
		var count = CraftingManager.get_currency_count(cid)
		var c_data = DataLoader.get_currency_data(cid)
		var c_name = c_data.get("name_cn", "通货")
		btn.text = "%s (%d)" % [c_name.substr(0, 2), count]
		btn.disabled = (count <= 0)
