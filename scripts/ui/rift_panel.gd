extends PanelContainer

## RiftPanel: 异界大秘境挑战与首领征伐界面

signal closed
signal rift_selected(rift_id: String)

@onready var close_btn: Button = $VBox/HeaderBox/CloseBtn
@onready var rifts_container: VBoxContainer = $VBox/Scroll/RiftsList

func _ready() -> void:
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	_setup_rifts_list()

func _setup_rifts_list() -> void:
	for child in rifts_container.get_children():
		child.queue_free()
	
	var all_rifts = DataLoader.get_all_rifts()
	for r_id in all_rifts.keys():
		var r_data = all_rifts[r_id]
		
		var box = PanelContainer.new()
		box.custom_minimum_size = Vector2(0, 48)
		
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		
		var title_lbl = Label.new()
		title_lbl.add_theme_font_size_override("font_size", 11)
		title_lbl.text = "【%s】 (%s)" % [r_data.get("name_cn", "秘境"), r_data.get("recommended_level", "")]
		title_lbl.modulate = Color(0.95, 0.85, 0.3)
		info_vbox.add_child(title_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.text = r_data.get("affix_desc", "")
		desc_lbl.modulate = Color(0.85, 0.88, 0.92)
		info_vbox.add_child(desc_lbl)
		
		row.add_child(info_vbox)
		
		var enter_btn = Button.new()
		enter_btn.custom_minimum_size = Vector2(80, 26)
		enter_btn.add_theme_font_size_override("font_size", 10)
		enter_btn.text = "[ 开启挑战 ]"
		enter_btn.modulate = Color(0.4, 0.85, 0.45)
		enter_btn.pressed.connect(func():
			visible = false
			rift_selected.emit(r_id)
		)
		row.add_child(enter_btn)
		
		box.add_child(row)
		rifts_container.add_child(box)
