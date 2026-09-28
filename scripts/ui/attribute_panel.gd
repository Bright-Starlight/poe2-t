extends PanelContainer

## AttributePanel: 角色自由属性加点与洗点界面

signal closed

@onready var unspent_label: Label = $VBox/HeaderBox/UnspentLabel
@onready var str_val_label: Label = $VBox/Grid/StrValLabel
@onready var dex_val_label: Label = $VBox/Grid/DexValLabel
@onready var int_val_label: Label = $VBox/Grid/IntValLabel

@onready var add_str_btn: Button = $VBox/Grid/AddStrBtn
@onready var add_dex_btn: Button = $VBox/Grid/AddDexBtn
@onready var add_int_btn: Button = $VBox/Grid/AddIntBtn

@onready var reset_btn: Button = $VBox/FooterBox/ResetBtn
@onready var close_btn: Button = $VBox/HeaderBox/CloseBtn

func _ready() -> void:
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	
	add_str_btn.pressed.connect(func(): InventoryManager.allocate_stat("strength"))
	add_dex_btn.pressed.connect(func(): InventoryManager.allocate_stat("dexterity"))
	add_int_btn.pressed.connect(func(): InventoryManager.allocate_stat("intelligence"))
	reset_btn.pressed.connect(func(): InventoryManager.reset_stats())
	
	InventoryManager.stat_points_updated.connect(_on_stat_points_updated)
	refresh_ui()

func refresh_ui() -> void:
	_on_stat_points_updated(
		InventoryManager.unspent_stat_points,
		InventoryManager.allocated_strength,
		InventoryManager.allocated_dexterity,
		InventoryManager.allocated_intelligence
	)

func _on_stat_points_updated(unspent: int, s: int, d: int, i: int) -> void:
	unspent_label.text = "可分配点数: %d" % unspent
	unspent_label.modulate = Color(0.95, 0.85, 0.3) if unspent > 0 else Color(0.7, 0.75, 0.8)
	
	str_val_label.text = "力量: %d" % s
	dex_val_label.text = "敏捷: %d" % d
	int_val_label.text = "智力: %d" % i
	
	add_str_btn.disabled = unspent <= 0
	add_dex_btn.disabled = unspent <= 0
	add_int_btn.disabled = unspent <= 0
	
	var total_allocated = s + d + i
	reset_btn.disabled = total_allocated <= 0
