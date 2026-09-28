extends Node2D

## Main: 主场景控制器，负责承载地图关卡、玩家实体及顶层 UI HUD

@onready var map: Node2D = $World/DungeonMap
@onready var player: CharacterBody2D = $World/Player

@onready var fps_label: Label = $CanvasLayer/UI/DebugPanel/VBox/FPSLabel
@onready var version_label: Label = $CanvasLayer/UI/DebugPanel/VBox/VersionLabel
@onready var phase_label: Label = $CanvasLayer/UI/DebugPanel/VBox/PhaseLabel
@onready var time_label: Label = $CanvasLayer/UI/DebugPanel/VBox/TimeLabel
@onready var player_pos_label: Label = $CanvasLayer/UI/DebugPanel/VBox/PlayerPosLabel
@onready var monster_status_label: Label = $CanvasLayer/UI/DebugPanel/VBox/MonsterStatusLabel

@onready var hp_bar: ProgressBar = $CanvasLayer/UI/PlayerStatsPanel/HpBar
@onready var hp_text: Label = $CanvasLayer/UI/PlayerStatsPanel/HpBar/HpText
@onready var mp_bar: ProgressBar = $CanvasLayer/UI/PlayerStatsPanel/MpBar
@onready var mp_text: Label = $CanvasLayer/UI/PlayerStatsPanel/MpBar/MpText

# 技能 UI 槽位引用
@onready var skill_slots_nodes: Array[Panel] = [
	$CanvasLayer/UI/SkillBarPanel/HBox/Slot0,
	$CanvasLayer/UI/SkillBarPanel/HBox/Slot1,
	$CanvasLayer/UI/SkillBarPanel/HBox/Slot2
]

@onready var auto_status_label: Label = $CanvasLayer/UI/StatusPanel/AutoStatusLabel
@onready var log_label: Label = $CanvasLayer/UI/StatusPanel/LogLabel

var _log_messages: Array[String] = []
var _active_monsters: Array[Node2D] = []

func _ready() -> void:
	# 绑定全局事件总线
	EventBus.auto_combat_toggled.connect(_on_auto_combat_toggled)
	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.player_mana_changed.connect(_on_player_mana_changed)
	EventBus.monster_spawned.connect(_on_monster_spawned)
	EventBus.monster_died.connect(_on_monster_died)
	EventBus.combat_damage_dealt.connect(_on_combat_damage_dealt)
	EventBus.debug_log_emitted.connect(_append_log)
	
	version_label.text = "引擎核心：Godot 4.3 | 版本号：%s" % GameManager.GAME_VERSION
	phase_label.text = "当前阶段：Phase 5 (技能系统)"
	_update_auto_status(GameManager.is_auto_combat_enabled)
	
	# 初始化地图与玩家初始位置
	if map and player:
		var spawn_pos = map.get_spawn_position()
		player.global_position = spawn_pos
		player.set_camera_limits(map.get_map_limits())
		_append_log("地牢地图载入成功 (尺寸: 1280x720)")
		_append_log("玩家已在坐标 %s 出生" % str(spawn_pos))
		
		var skill_ctrl = player.get_node_or_null("SkillController")
		if skill_ctrl:
			skill_ctrl.skill_cooldown_changed.connect(_on_skill_cooldown_changed)
	
	_append_log("技能快捷键：[1] 爆裂火球 | [2] 狂风旋斩 | [3] 疾影闪烁")

func _process(_delta: float) -> void:
	fps_label.text = "实时帧率：%d FPS (%.2f ms)" % [Engine.get_frames_per_second(), 1000.0 / max(1, Engine.get_frames_per_second())]
	time_label.text = "运行时间：%s" % GameManager.get_formatted_play_time()
	
	if player:
		player_pos_label.text = "玩家坐标：(%.0f, %.0f) | 速度: %.0f" % [player.global_position.x, player.global_position.y, player.velocity.length()]
	
	_update_monsters_debug()

func _update_monsters_debug() -> void:
	_active_monsters = _active_monsters.filter(func(m): return is_instance_valid(m) and not (m.get("state") == 5))
	var monster_count = _active_monsters.size()
	
	var nearest_dist = 9999.0
	var nearest_name = "无"
	if player and monster_count > 0:
		for m in _active_monsters:
			var d = player.global_position.distance_to(m.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest_name = m.get("monster_name") if "monster_name" in m else m.name
	
	if monster_count > 0:
		monster_status_label.text = "存活怪物：%d 只 | 最近: %s (%.0f px)" % [monster_count, nearest_name, nearest_dist]
	else:
		monster_status_label.text = "存活怪物：0 只 (全部清除!)"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_auto_combat"):
		GameManager.toggle_auto_combat()

func _on_skill_cooldown_changed(slot_idx: int, remaining: float, total: float) -> void:
	if slot_idx < 0 or slot_idx >= skill_slots_nodes.size():
		return
	
	var slot_node = skill_slots_nodes[slot_idx]
	var mask = slot_node.get_node_or_null("CooldownMask") as ColorRect
	var cd_label = slot_node.get_node_or_null("CooldownLabel") as Label
	
	if mask and cd_label:
		if remaining > 0.05:
			mask.visible = true
			var ratio = remaining / max(0.01, total)
			mask.scale.y = ratio
			cd_label.visible = true
			cd_label.text = "%.1f" % remaining
		else:
			mask.visible = false
			cd_label.visible = false

func _on_player_spawned(p: Node2D) -> void:
	_append_log("玩家连接就绪: %s" % p.name)

func _on_player_health_changed(current_hp: float, max_hp: float) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
	if hp_text:
		hp_text.text = "HP: %.0f / %.0f" % [current_hp, max_hp]

func _on_player_mana_changed(current_mp: float, max_mp: float) -> void:
	if mp_bar:
		mp_bar.max_value = max_mp
		mp_bar.value = current_mp
	if mp_text:
		mp_text.text = "MP: %.0f / %.0f" % [current_mp, max_mp]

func _on_monster_spawned(m: Node2D) -> void:
	if not _active_monsters.has(m):
		_active_monsters.append(m)
		var m_name = m.get("monster_name") if "monster_name" in m else m.name
		_append_log("生成怪物: %s" % m_name)

func _on_monster_died(m: Node2D, reward: Dictionary) -> void:
	var m_name = reward.get("monster_name", m.name)
	var exp_val = reward.get("exp", 0)
	var gold_val = reward.get("gold", 0)
	_append_log("击杀 %s! 获得经验 +%d, 金币 +%d" % [m_name, exp_val, gold_val])

func _on_combat_damage_dealt(info: Dictionary) -> void:
	var target = info.get("target", "目标")
	var amount = info.get("amount", 0.0)
	var is_crit = info.get("is_crit", false)
	if is_crit:
		_append_log("【暴击!】命中 %s 造成 %.0f 点伤害" % [target, amount])

func _on_auto_combat_toggled(is_enabled: bool) -> void:
	_update_auto_status(is_enabled)
	_append_log("自动战斗状态切换为：%s" % ("【开启】" if is_enabled else "【关闭】"))

func _update_auto_status(is_enabled: bool) -> void:
	if is_enabled:
		auto_status_label.text = "[ 自动战斗：已开启 ]"
		auto_status_label.modulate = Color(0.3, 0.9, 0.4, 1.0)
	else:
		auto_status_label.text = "[ 自动战斗：已关闭 ]"
		auto_status_label.modulate = Color(0.8, 0.8, 0.8, 1.0)

func _append_log(message: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	_log_messages.push_front("[%s] %s" % [timestamp, message])
	if _log_messages.size() > 5:
		_log_messages.pop_back()
	log_label.text = "\n".join(_log_messages)
