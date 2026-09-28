extends PanelContainer

## TalentTreePanel: PoE 风格多分支被动天赋星盘界面

signal closed

@onready var points_label: Label = $VBox/HeaderBox/PointsLabel
@onready var close_btn: Button = $VBox/HeaderBox/CloseBtn
@onready var branch_tab_container: HBoxContainer = $VBox/BranchTabs
@onready var nodes_list_container: VBoxContainer = $VBox/Scroll/NodesList
@onready var reset_btn: Button = $VBox/FooterBox/ResetBtn

var selected_branch: String = "physical"
var _branch_buttons: Dictionary = {}

func _ready() -> void:
	close_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	
	reset_btn.pressed.connect(func():
		TalentManager.reset_talents()
		refresh_ui()
	)
	
	TalentManager.talents_updated.connect(func(_nodes, _unspent): refresh_ui())
	
	_setup_branch_tabs()
	refresh_ui()

func _setup_branch_tabs() -> void:
	for child in branch_tab_container.get_children():
		child.queue_free()
	_branch_buttons.clear()
	
	var tree = DataLoader.get_passive_tree_data()
	for b_key in tree.keys():
		var b_data = tree[b_key]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(76, 26)
		btn.add_theme_font_size_override("font_size", 10)
		btn.text = b_data.get("name_cn", "分支")
		btn.pressed.connect(func():
			selected_branch = b_key
			refresh_ui()
		)
		branch_tab_container.add_child(btn)
		_branch_buttons[b_key] = btn

func refresh_ui() -> void:
	points_label.text = "天赋点数: %d" % TalentManager.unspent_talent_points
	points_label.modulate = Color(0.95, 0.85, 0.3) if TalentManager.unspent_talent_points > 0 else Color(0.7, 0.75, 0.85)
	
	# 更新分支高亮
	for b_key in _branch_buttons.keys():
		var btn = _branch_buttons[b_key] as Button
		btn.modulate = Color(0.95, 0.85, 0.3) if b_key == selected_branch else Color(0.75, 0.75, 0.8)
	
	# 重建当前分支节点列表
	for child in nodes_list_container.get_children():
		child.queue_free()
	
	var tree = DataLoader.get_passive_tree_data()
	var b_data = tree.get(selected_branch, {})
	var nodes = b_data.get("nodes", [])
	
	for n in nodes:
		var nid = n.get("id", "")
		var is_alloc = TalentManager.is_node_allocated(nid)
		var can_alloc = TalentManager.can_allocate_node(nid)
		
		var node_box = PanelContainer.new()
		node_box.custom_minimum_size = Vector2(0, 44)
		
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		
		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 2)
		
		var name_lbl = Label.new()
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.text = "【%s】 %s" % [n.get("name_cn", "天赋"), "[已点亮]" if is_alloc else ("[可激活]" if can_alloc else "[未解锁]")]
		name_lbl.modulate = Color(0.4, 0.85, 0.45) if is_alloc else (Color(0.95, 0.85, 0.3) if can_alloc else Color(0.6, 0.65, 0.7))
		info_vbox.add_child(name_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.add_theme_font_size_override("font_size", 9)
		desc_lbl.text = n.get("desc", "")
		desc_lbl.modulate = Color(0.85, 0.88, 0.92)
		info_vbox.add_child(desc_lbl)
		
		row.add_child(info_vbox)
		
		var act_btn = Button.new()
		act_btn.custom_minimum_size = Vector2(64, 26)
		act_btn.add_theme_font_size_override("font_size", 10)
		
		if is_alloc:
			act_btn.text = "已激活"
			act_btn.disabled = true
			act_btn.modulate = Color(0.4, 0.85, 0.45)
		elif can_alloc:
			act_btn.text = "点亮 (+1)"
			act_btn.disabled = false
			act_btn.modulate = Color(0.95, 0.85, 0.3)
			act_btn.pressed.connect(func(): TalentManager.allocate_node(nid))
		else:
			act_btn.text = "未满足"
			act_btn.disabled = true
			act_btn.modulate = Color(0.5, 0.5, 0.5)
		
		row.add_child(act_btn)
		node_box.add_child(row)
		nodes_list_container.add_child(node_box)
	
	reset_btn.disabled = TalentManager.allocated_nodes.is_empty()
