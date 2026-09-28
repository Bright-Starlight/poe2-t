extends Node

## TextBattleEngine: 纯逻辑文字战斗与PoE2多目标怪群/8词缀引路石/清图循环引擎
## 驱动多怪同屏作战 (1vN)、怪群受地图8词缀强化、范围AoE技能(旋风斩/火球溅射)、怪池逐级推进与首领降临

const CombatCalculatorClass = preload("res://scripts/combat/combat_calculator.gd")

signal battle_log_emitted(bbcode_text: String)
signal monster_state_updated(monster_info: Dictionary) # 兼容单体主目标展示
signal monsters_squad_updated(squad: Array, focused_index: int) # 多目标怪群同步
signal map_progress_updated(killed: int, total: int, remaining: int, is_active: bool, map_title: String, is_boss: bool)
signal player_state_updated(hp: float, max_hp: float, mp: float, max_mp: float)
signal skill_cooldowns_updated(cooldowns: Dictionary)
signal exploration_state_changed(is_active: bool)
signal rift_progress_updated(current: float, max_val: float, is_in_rift: bool)

var current_map_id: String = "forest_1"
var is_active: bool = false
var is_auto_combat: bool = true

# 引路石与地图状态
var is_in_waystone: bool = false
var current_waystone: Dictionary = {}
var total_map_monsters: int = 25
var killed_map_monsters: int = 0
var remaining_pool_monsters: int = 25
var max_active_capacity: int = 3
var map_boss_spawned: bool = false
var map_completed: bool = false
var map_display_title: String = "幽暗密林"

# 兼容旧版大秘境
var is_in_rift: bool = false
var current_rift_id: String = ""
var rift_progress: float = 0.0

# 战斗怪群列表与选定主目标
var active_monsters: Array[Dictionary] = []
var focused_target_index: int = 0

# 玩家即时状态
var player_hp: float = 200.0
var player_max_hp: float = 200.0
var player_mp: float = 100.0
var player_max_mp: float = 100.0

# 玩家战斗状态效果
var player_frenzy_stacks: int = 0
var player_frenzy_timer: float = 0.0
var player_shock_timer: float = 0.0
var player_bleed_timer: float = 0.0
var player_bleed_dps: float = 0.0

var player_attack_timer: float = 0.0
var encounter_timer: float = 0.0

var skill_cooldowns: Dictionary = {
	"fireball": 0.0,
	"whirlwind": 0.0,
	"dash": 0.0
}

const ELITE_AFFIXES_POOL = [
	{"id": "resilient", "name_cn": "坚韧", "desc": "生命翻倍"},
	{"id": "frenzy", "name_cn": "狂暴", "desc": "攻速+50%"},
	{"id": "vampiric", "name_cn": "吸血", "desc": "攻击吸血35%"},
	{"id": "ignited", "name_cn": "灼热", "desc": "附加烈焰额外伤害"}
]

func _ready() -> void:
	EventBus.player_stats_changed.connect(_on_player_stats_changed)
	_sync_player_stats()

func _sync_player_stats() -> void:
	var stats = InventoryManager.get_total_player_stats()
	player_max_hp = stats.get("max_hp", 200.0)
	player_max_mp = stats.get("max_mp", 100.0)
	player_hp = player_max_hp
	player_mp = player_max_mp
	player_state_updated.emit(player_hp, player_max_hp, player_mp, player_max_mp)

func _on_player_stats_changed(new_stats: Dictionary) -> void:
	player_max_hp = new_stats.get("max_hp", 200.0)
	player_max_mp = new_stats.get("max_mp", 100.0)
	player_hp = min(player_hp, player_max_hp)
	player_mp = min(player_mp, player_max_mp)
	player_state_updated.emit(player_hp, player_max_hp, player_mp, player_max_mp)

## 开启常规基础地图探索
func start_exploration(map_id: String = "") -> void:
	is_in_waystone = false
	is_in_rift = false
	current_waystone.clear()
	current_rift_id = ""
	
	if map_id != "":
		current_map_id = map_id
	
	var map_data = DataLoader.get_map_data(current_map_id)
	map_display_title = map_data.get("name_cn", "未知区域")
	
	total_map_monsters = 20
	killed_map_monsters = 0
	remaining_pool_monsters = total_map_monsters
	max_active_capacity = 2
	map_boss_spawned = false
	map_completed = false
	
	is_active = true
	exploration_state_changed.emit(true)
	emit_log("[color=#f6e05e]【进入区域】进入【%s】，开始探索打宝 (全图怪物: %d 只)...[/color]" % [map_display_title, total_map_monsters])
	
	_clear_all_monsters()
	_replenish_monsters_squad()
	_sync_map_progress_ui()

## 开启 PoE2 异界引路石挑战 (含基底与最多8词缀强化)
func start_waystone(waystone: Dictionary) -> void:
	is_in_waystone = true
	is_in_rift = true
	current_waystone = waystone
	
	map_display_title = waystone.get("display_name", "异界引路石")
	total_map_monsters = int(waystone.get("total_monsters_count", 25))
	killed_map_monsters = 0
	remaining_pool_monsters = total_map_monsters
	max_active_capacity = int(waystone.get("max_active_monsters", 3))
	map_boss_spawned = false
	map_completed = false
	
	is_active = true
	exploration_state_changed.emit(true)
	
	var aff_cnt = waystone.get("affixes", []).size()
	var mods = waystone.get("modifiers_summary", {})
	var r_color = waystone.get("rarity_color", "#f6e05e")
	
	emit_log("[color=%s]════════════════════════════════════════════[/color]" % r_color)
	emit_log("[color=%s]【开启引路石】激活【%s】(共 %d 条词缀)！[/color]" % [r_color, map_display_title, aff_cnt])
	emit_log("• 地图强化: 怪物总数 [b]%d[/b] 只 (同屏怪群 [b]%d[/b] 只) | 掉落数量 +%.0f%% | 稀有度 +%.0f%% | 通货 +%.0f%%" % [
		total_map_monsters, max_active_capacity,
		mods.get("item_quant_pct", 0.0) * 100.0,
		mods.get("item_rarity_pct", 0.0) * 100.0,
		mods.get("currency_mult_pct", 0.0) * 100.0
	])
	emit_log("[color=%s]════════════════════════════════════════════[/color]" % r_color)
	
	_clear_all_monsters()
	_replenish_monsters_squad()
	_sync_map_progress_ui()

## 兼容原大秘境接口
func start_rift(rift_id: String) -> void:
	# 自动寻找对应 tier 的 waystone 或生成
	var all_w = DataLoader.get_all_waystones()
	if all_w.has(rift_id):
		var ws = WaystoneManager.generate_waystone(rift_id, "rare", 4)
		start_waystone(ws)
	else:
		var ws = WaystoneManager.generate_waystone("t1_waystone", "magic", 2)
		start_waystone(ws)

func stop_exploration() -> void:
	is_active = false
	_clear_all_monsters()
	exploration_state_changed.emit(false)
	_sync_map_progress_ui()
	emit_log("[color=#a0aec0]【休整】已停止探索，原地休整中。[/color]")

func toggle_auto_combat() -> void:
	is_auto_combat = !is_auto_combat
	emit_log("[color=#63b3ed]【自动战斗】自动战斗已%s[/color]" % ("【开启】" if is_auto_combat else "【关闭】"))

func set_focused_target(index: int) -> void:
	if index >= 0 and index < active_monsters.size():
		focused_target_index = index
		_emit_squad_update()

func _clear_all_monsters() -> void:
	active_monsters.clear()
	focused_target_index = 0
	_emit_squad_update()

func _process(delta: float) -> void:
	# 技能冷却递减
	var cd_changed = false
	for k in skill_cooldowns.keys():
		if skill_cooldowns[k] > 0.0:
			skill_cooldowns[k] = max(0.0, skill_cooldowns[k] - delta)
			cd_changed = true
	if cd_changed:
		skill_cooldowns_updated.emit(skill_cooldowns)
	
	# 玩家状态效果心跳 (狂怒、流血、感电)
	if player_frenzy_timer > 0.0:
		player_frenzy_timer -= delta
		if player_frenzy_timer <= 0.0:
			player_frenzy_stacks = 0
	
	if player_shock_timer > 0.0:
		player_shock_timer = max(0.0, player_shock_timer - delta)
	
	if player_bleed_timer > 0.0:
		player_bleed_timer -= delta
		var b_dmg = player_bleed_dps * delta
		player_hp = max(0.0, player_hp - b_dmg)
		player_state_updated.emit(player_hp, player_max_hp, player_mp, player_max_mp)
		if player_hp <= 0.0:
			_on_player_defeated()
			return
	
	# 怪群异常状态结算 (遍历各怪物流血与感电)
	var any_monster_died = false
	for i in range(active_monsters.size() - 1, -1, -1):
		var m = active_monsters[i]
		if m.get("bleed_timer", 0.0) > 0.0:
			m["bleed_timer"] -= delta
			var m_bdmg = float(m.get("bleed_dps", 0.0)) * delta
			m["current_hp"] = max(0.0, m["current_hp"] - m_bdmg)
			if m["current_hp"] <= 0.0:
				_on_single_monster_killed(i)
				any_monster_died = true
				continue
		
		if m.get("shock_timer", 0.0) > 0.0:
			m["shock_timer"] = max(0.0, m["shock_timer"] - delta)
	
	if any_monster_died:
		_emit_squad_update()
		return
	
	# 自然回蓝 (+6 MP/s) 与 脱战回血 (+15 HP/s)
	if player_mp < player_max_mp:
		player_mp = min(player_max_mp, player_mp + 6.0 * delta)
	if player_hp < player_max_hp and active_monsters.is_empty():
		player_hp = min(player_max_hp, player_hp + 15.0 * delta)
	player_state_updated.emit(player_hp, player_max_hp, player_mp, player_max_mp)
	
	if not is_active:
		return
	
	# 检查怪群是否需要补充
	if active_monsters.is_empty():
		if remaining_pool_monsters > 0:
			encounter_timer -= delta
			if encounter_timer <= 0.0:
				_replenish_monsters_squad()
		elif not map_boss_spawned:
			encounter_timer -= delta
			if encounter_timer <= 0.0:
				_spawn_map_boss()
		return
	
	# 玩家攻击计时与自动战斗
	player_attack_timer -= delta
	if is_auto_combat:
		if skill_cooldowns["whirlwind"] <= 0.0 and player_mp >= 22.0 and active_monsters.size() >= 2:
			cast_skill("whirlwind")
		elif skill_cooldowns["fireball"] <= 0.0 and player_mp >= 15.0:
			cast_skill("fireball")
		elif skill_cooldowns["whirlwind"] <= 0.0 and player_mp >= 22.0:
			cast_skill("whirlwind")
		
		if player_attack_timer <= 0.0:
			_execute_player_attack()
	
	# 怪群中每只活怪独立计时反击玩家
	for i in range(active_monsters.size()):
		if i >= active_monsters.size(): break
		var m = active_monsters[i]
		m["attack_timer"] = float(m.get("attack_timer", 1.0)) - delta
		if m["attack_timer"] <= 0.0:
			_execute_monster_counterattack(i)
			if player_hp <= 0.0:
				return

## 补充怪群直到达到当前容量上限
func _replenish_monsters_squad() -> void:
	while active_monsters.size() < max_active_capacity and remaining_pool_monsters > 0:
		var new_m = _generate_map_monster()
		active_monsters.append(new_m)
		remaining_pool_monsters -= 1
	
	if focused_target_index >= active_monsters.size():
		focused_target_index = maxi(0, active_monsters.size() - 1)
	
	_emit_squad_update()
	_sync_map_progress_ui()

const MONSTER_RARITY_COLORS = {
	"normal": "#e2e8f0",
	"magic": "#63b3ed",
	"rare": "#f6e05e",
	"unique": "#ed8936"
}

const MONSTER_RARITY_NAMES_CN = {
	"normal": "普通",
	"magic": "魔法",
	"rare": "稀有",
	"unique": "首领"
}

## 根据当前地图/引路石与8词缀生成单只受稀有度与词缀影响的怪物
func _generate_map_monster() -> Dictionary:
	var pool = ["slime_green"]
	var scale = 1.0
	var map_mods = {}
	
	if is_in_waystone:
		pool = current_waystone.get("monster_pool", ["skeleton_warrior"])
		scale = float(current_waystone.get("level_scale", 1.5))
		map_mods = current_waystone.get("modifiers_summary", {})
	else:
		var map_data = DataLoader.get_map_data(current_map_id)
		pool = map_data.get("monster_pool", ["slime_green"])
		scale = float(map_data.get("level_scale", 1.0))
	
	var m_id = pool[randi() % pool.size()]
	var base_data = DataLoader.get_monster_data(m_id).duplicate(true)
	
	# 1. 抽取怪物稀有度 (普通 / 魔法 / 稀有)
	var tier = current_waystone.get("tier", 1) if is_in_waystone else 1
	var bonus_rarity = float(map_mods.get("item_rarity_pct", 0.0))
	
	var rare_chance = clampf(0.08 + (tier - 1) * 0.035 + bonus_rarity * 0.08, 0.08, 0.35)
	var magic_chance = clampf(0.22 + (tier - 1) * 0.03 + bonus_rarity * 0.10, 0.22, 0.45)
	
	var r_roll = randf()
	var rarity = "normal"
	if r_roll < rare_chance:
		rarity = "rare"
	elif r_roll < (rare_chance + magic_chance):
		rarity = "magic"
	else:
		rarity = "normal"
	
	# 2. 根据稀有度设定基础属性与词缀数量倍率
	var life_rarity_mult = 1.0
	var atk_rarity_mult = 1.0
	var def_rarity_mult = 1.0
	var spd_rarity_mult = 1.0
	var exp_gold_mult = 1.0
	var affix_count = 0
	
	match rarity:
		"magic":
			life_rarity_mult = 2.20
			atk_rarity_mult = 1.30
			def_rarity_mult = 1.20
			spd_rarity_mult = 1.10
			exp_gold_mult = 2.20
			affix_count = randi_range(1, 2)
		"rare":
			life_rarity_mult = 4.80
			atk_rarity_mult = 1.70
			def_rarity_mult = 1.50
			spd_rarity_mult = 1.20
			exp_gold_mult = 4.50
			affix_count = randi_range(2, 4)
		_:
			# normal
			life_rarity_mult = 1.0
			atk_rarity_mult = 1.0
			def_rarity_mult = 1.0
			spd_rarity_mult = 1.0
			exp_gold_mult = 1.0
			affix_count = 0
	
	# 地图词缀全局增幅
	var map_life_mult = (1.0 + float(map_mods.get("monster_life_pct", 0.0)))
	var map_atk_mult = (1.0 + float(map_mods.get("monster_phys_damage_pct", 0.0)))
	var map_def_mult = (1.0 + float(map_mods.get("monster_defense_pct", 0.0)))
	var map_spd_mult = (1.0 + float(map_mods.get("monster_speed_pct", 0.0)))
	
	var m_hp = float(base_data.get("max_hp", 100)) * scale * map_life_mult * life_rarity_mult
	var m_atk = float(base_data.get("attack_damage", 10)) * scale * map_atk_mult * atk_rarity_mult
	var m_armor = float(base_data.get("armor", 5)) * scale * map_def_mult * def_rarity_mult
	var m_evasion = float(base_data.get("evasion", 5)) * map_def_mult * def_rarity_mult
	var m_aspd = 0.85 * map_spd_mult * spd_rarity_mult
	
	var extra_fire = float(map_mods.get("extra_fire_damage_pct", 0.0))
	var extra_cold = float(map_mods.get("extra_cold_damage_pct", 0.0))
	var extra_light = float(map_mods.get("extra_lightning_damage_pct", 0.0))
	var leech = float(map_mods.get("monster_life_steal_pct", 0.0))
	var crit_c = 0.05 + float(map_mods.get("monster_crit_chance_pct", 0.0))
	var shock_hit = int(map_mods.get("monster_shock_on_hit", 0)) > 0
	var bleed_hit = int(map_mods.get("monster_bleed_on_hit", 0)) > 0
	
	# 3. 抽取与结算怪物专属词缀
	var available_affs = DataLoader.get_monster_affixes_data().duplicate(true)
	available_affs.shuffle()
	
	var rolled_affs: Array[Dictionary] = []
	var affix_names: Array[String] = []
	
	for i in range(mini(affix_count, available_affs.size())):
		var a = available_affs[i]
		rolled_affs.append(a)
		affix_names.append(a["name_cn"])
		
		m_hp *= float(a.get("hp_mult", 1.0))
		m_armor *= float(a.get("armor_mult", 1.0))
		m_evasion *= float(a.get("evasion_mult", 1.0))
		m_aspd *= float(a.get("speed_mult", 1.0))
		m_atk *= float(a.get("phys_dmg_mult", 1.0))
		crit_c += float(a.get("crit_chance_add", 0.0))
		leech += float(a.get("life_steal_pct", 0.0))
		extra_fire += float(a.get("extra_fire_pct", 0.0))
		extra_cold += float(a.get("extra_cold_pct", 0.0))
		extra_light += float(a.get("extra_lightning_pct", 0.0))
		if a.get("shock_on_hit", false): shock_hit = true
		if a.get("bleed_on_hit", false): bleed_hit = true
	
	# 4. 组装复合怪物名称与标签
	var base_name = base_data.get("name_cn", "怪物")
	var final_name = base_name
	if not affix_names.is_empty():
		var tag_str = "·".join(affix_names)
		if rarity == "rare":
			final_name = "【%s】稀有 %s" % [tag_str, base_name]
		elif rarity == "magic":
			final_name = "【%s】魔法 %s" % [tag_str, base_name]
	
	return {
		"id": m_id,
		"rarity": rarity,
		"rarity_name_cn": MONSTER_RARITY_NAMES_CN.get(rarity, "普通"),
		"rarity_color": MONSTER_RARITY_COLORS.get(rarity, "#e2e8f0"),
		"name_cn": final_name,
		"base_name_cn": base_name,
		"is_elite": (rarity == "rare" or rarity == "magic"),
		"is_magic": (rarity == "magic"),
		"is_rare": (rarity == "rare"),
		"is_boss": false,
		"monster_affixes": rolled_affs,
		"max_hp": m_hp,
		"current_hp": m_hp,
		"attack_damage": m_atk,
		"armor": m_armor,
		"evasion": m_evasion,
		"attack_speed": m_aspd,
		"attack_timer": randf_range(0.8, 1.5),
		"extra_fire_pct": extra_fire,
		"extra_cold_pct": extra_cold,
		"extra_lightning_pct": extra_light,
		"life_steal_pct": leech,
		"crit_chance": crit_c,
		"shock_on_hit": shock_hit,
		"bleed_on_hit": bleed_hit,
		"shock_timer": 0.0,
		"bleed_timer": 0.0,
		"bleed_dps": 0.0,
		"exp_reward": int(float(base_data.get("exp_reward", 15)) * scale * exp_gold_mult),
		"gold_min": int(float(base_data.get("gold_reward_min", 2)) * scale * exp_gold_mult),
		"gold_max": int(float(base_data.get("gold_reward_max", 8)) * scale * exp_gold_mult)
	}

## 召唤终极首领
func _spawn_map_boss() -> void:
	map_boss_spawned = true
	var boss_id = "boss_skeleton_king"
	var scale = 1.8
	var map_mods = {}
	
	if is_in_waystone:
		boss_id = current_waystone.get("boss_id", "boss_skeleton_king")
		scale = float(current_waystone.get("level_scale", 2.0))
		map_mods = current_waystone.get("modifiers_summary", {})
	else:
		var map_data = DataLoader.get_map_data(current_map_id)
		scale = float(map_data.get("level_scale", 1.0)) * 1.5
	
	var base_data = DataLoader.get_monster_data(boss_id).duplicate(true)
	var life_mult = (1.0 + float(map_mods.get("monster_life_pct", 0.0)))
	var atk_mult = (1.0 + float(map_mods.get("monster_phys_damage_pct", 0.0)))
	var def_mult = (1.0 + float(map_mods.get("monster_defense_pct", 0.0)))
	
	var m_hp = float(base_data.get("max_hp", 1000)) * scale * life_mult
	var m_atk = float(base_data.get("attack_damage", 30)) * scale * atk_mult
	
	var boss_dict = {
		"id": boss_id,
		"rarity": "unique",
		"rarity_name_cn": MONSTER_RARITY_NAMES_CN["unique"],
		"rarity_color": MONSTER_RARITY_COLORS["unique"],
		"name_cn": "【史诗首领】 " + base_data.get("name_cn", "首领"),
		"base_name_cn": base_data.get("name_cn", "首领"),
		"is_elite": true,
		"is_magic": false,
		"is_rare": false,
		"is_boss": true,
		"monster_affixes": [],
		"max_hp": m_hp,
		"current_hp": m_hp,
		"attack_damage": m_atk,
		"armor": float(base_data.get("armor", 20)) * scale * def_mult,
		"evasion": float(base_data.get("evasion", 10)) * def_mult,
		"attack_speed": float(base_data.get("attack_speed", 0.9)),
		"attack_timer": 1.6,
		"extra_fire_pct": float(map_mods.get("extra_fire_damage_pct", 0.0)),
		"extra_cold_pct": float(map_mods.get("extra_cold_damage_pct", 0.0)),
		"extra_lightning_pct": float(map_mods.get("extra_lightning_damage_pct", 0.0)),
		"life_steal_pct": float(map_mods.get("monster_life_steal_pct", 0.0)),
		"crit_chance": 0.08 + float(map_mods.get("monster_crit_chance_pct", 0.0)),
		"shock_on_hit": int(map_mods.get("monster_shock_on_hit", 0)) > 0,
		"bleed_on_hit": int(map_mods.get("monster_bleed_on_hit", 0)) > 0,
		"shock_timer": 0.0,
		"bleed_timer": 0.0,
		"bleed_dps": 0.0,
		"exp_reward": int(float(base_data.get("exp_reward", 500)) * scale),
		"gold_min": int(float(base_data.get("gold_reward_min", 200)) * scale),
		"gold_max": int(float(base_data.get("gold_reward_max", 500)) * scale),
		"skills": base_data.get("skills", [])
	}
	
	active_monsters.clear()
	active_monsters.append(boss_dict)
	focused_target_index = 0
	
	_emit_squad_update()
	_sync_map_progress_ui()
	
	emit_log("[color=#ed8936]════════════════════════════════════════════[/color]")
	emit_log("[color=#f6e05e]【首领降临!】地图怪群已全部肃清！史诗首领【%s】挟8词缀之力震碎虚空降临！(HP: %.0f)[/color]" % [boss_dict["name_cn"], m_hp])
	emit_log("[color=#ed8936]════════════════════════════════════════════[/color]")

## 玩家单体普通攻击 (斩击选定主目标)
func _execute_player_attack() -> void:
	if active_monsters.is_empty():
		return
	
	if focused_target_index >= active_monsters.size():
		focused_target_index = 0
	
	var target = active_monsters[focused_target_index]
	var p_stats = InventoryManager.get_total_player_stats()
	var p_aspd = float(p_stats.get("attack_speed", 1.2)) * (1.0 + player_frenzy_stacks * 0.04)
	player_attack_timer = 1.0 / max(0.5, p_aspd)
	
	# 狂怒球层数累加
	if int(p_stats.get("frenzy_charges", 0)) > 0:
		player_frenzy_stacks = mini(3, player_frenzy_stacks + 1)
		player_frenzy_timer = 5.0
	
	var dmg_info = CombatCalculatorClass.calculate_damage(p_stats, target, null, null)
	if dmg_info.is_miss:
		emit_log("[color=#a0aec0]  -> 玩家普通攻击，被 %s [闪避]！[/color]" % target["name_cn"])
		return
	
	var final_dmg = dmg_info.amount * (1.20 if float(target.get("shock_timer", 0.0)) > 0.0 else 1.0)
	if target.get("is_elite", false) and float(p_stats.get("elite_damage_pct", 0.0)) > 0.0:
		final_dmg *= (1.0 + float(p_stats.get("elite_damage_pct", 0.0)))
	
	target["current_hp"] = max(0.0, target["current_hp"] - final_dmg)
	
	# 击中回血 (受地图回复削减词缀影响)
	var recovery_red = float(current_waystone.get("modifiers_summary", {}).get("recovery_reduction_pct", 0.0)) if is_in_waystone else 0.0
	var loh = float(p_stats.get("life_on_hit", 0.0)) * (1.0 - recovery_red)
	if loh > 0.0:
		player_hp = min(player_max_hp, player_hp + loh)
		player_state_updated.emit(player_hp, player_max_hp, player_mp, player_max_mp)
	
	# 暴击触发感电
	if dmg_info.is_crit and int(p_stats.get("shock_on_crit", 0)) > 0:
		target["shock_timer"] = 4.0
	
	# 攻击触发流血
	if int(p_stats.get("bleed_on_hit", 0)) > 0:
		target["bleed_timer"] = 3.0
		target["bleed_dps"] = final_dmg * 0.35 / 3.0
	
	if dmg_info.is_crit:
		emit_log("[color=#f6e05e]  -> 玩家斩击【暴击!】对 %s 造成 [b]%.0f[/b] 点物理伤害！%s[/color]" % [
			target["name_cn"], final_dmg, "(狂怒 x%d)" % player_frenzy_stacks if player_frenzy_stacks > 0 else ""
		])
	else:
		emit_log("  -> 玩家斩击命中 %s，造成 %.0f 点伤害。" % [target["name_cn"], final_dmg])
	
	if target["current_hp"] <= 0.0:
		_on_single_monster_killed(focused_target_index)
	
	_emit_squad_update()

## 技能施放 (多目标 AoE 与溅射判定)
func cast_skill(skill_id: String) -> bool:
	if active_monsters.is_empty():
		return false
	if skill_cooldowns.get(skill_id, 0.0) > 0.0:
		return false
	
	var s_data = DataLoader.get_skill_data(skill_id)
	if s_data.is_empty():
		return false
	
	var p_stats = InventoryManager.get_total_player_stats().duplicate(true)
	var mana_reduction = float(p_stats.get("mana_cost_reduction", 0.0))
	var mana_cost = float(s_data.get("mana_cost", 10.0)) * (1.0 - mana_reduction)
	
	if player_mp < mana_cost:
		emit_log("[color=#fc8181]  -> 【法力不足】无法施放 %s！[/color]" % s_data.get("name_cn", ""))
		return false
	
	player_mp -= mana_cost
	
	# 技能冷却受地图词缀惩罚
	var cd_penalty = float(current_waystone.get("modifiers_summary", {}).get("skill_cooldown_increase_pct", 0.0)) if is_in_waystone else 0.0
	var base_cd = float(s_data.get("cooldown", 2.0)) * (1.0 + cd_penalty)
	skill_cooldowns[skill_id] = base_cd
	skill_cooldowns_updated.emit(skill_cooldowns)
	player_state_updated.emit(player_hp, player_max_hp, player_mp, player_max_mp)
	
	var mult = float(s_data.get("damage_multiplier", 1.5))
	p_stats["attack_damage"] = float(p_stats.get("attack_damage", 25.0)) * mult
	p_stats["crit_rate"] = float(p_stats.get("crit_rate", 0.05)) + 0.1
	
	var skill_name = s_data.get("name_cn", "技能")
	
	if skill_id == "whirlwind":
		# 全屏 AoE 旋风斩：同时打击怪群中所有活怪！
		var hit_dmgs = []
		var dead_indices = []
		
		for i in range(active_monsters.size()):
			var m = active_monsters[i]
			var dmg_info = CombatCalculatorClass.calculate_damage(p_stats, m, null, null)
			var fdmg = dmg_info.amount * (1.20 if float(m.get("shock_timer", 0.0)) > 0.0 else 1.0)
			m["current_hp"] = max(0.0, m["current_hp"] - fdmg)
			hit_dmgs.append("%.0f" % fdmg)
			if m["current_hp"] <= 0.0:
				dead_indices.append(i)
		
		emit_log("[color=#ed8936]  -> 玩家施放【%s】风卷残云！全屏横扫在场 %d 只怪物，分别造成 [%s] 点群伤！[/color]" % [
			skill_name, active_monsters.size(), ", ".join(hit_dmgs)
		])
		
		# 倒序处理阵亡
		dead_indices.reverse()
		for d_idx in dead_indices:
			_on_single_monster_killed(d_idx)
			
	elif skill_id == "fireball":
		# 爆裂火球：主目标巨额单体 + 溅射在场其他全部怪物 60% 伤害
		if focused_target_index >= active_monsters.size(): focused_target_index = 0
		var primary_m = active_monsters[focused_target_index]
		var dmg_info = CombatCalculatorClass.calculate_damage(p_stats, primary_m, null, null)
		var main_dmg = dmg_info.amount * 1.35 * (1.20 if float(primary_m.get("shock_timer", 0.0)) > 0.0 else 1.0)
		primary_m["current_hp"] = max(0.0, primary_m["current_hp"] - main_dmg)
		
		var splash_count = 0
		var dead_indices = []
		if primary_m["current_hp"] <= 0.0:
			dead_indices.append(focused_target_index)
		
		for i in range(active_monsters.size()):
			if i != focused_target_index:
				var m = active_monsters[i]
				var splash_dmg = main_dmg * 0.60
				m["current_hp"] = max(0.0, m["current_hp"] - splash_dmg)
				splash_count += 1
				if m["current_hp"] <= 0.0:
					dead_indices.append(i)
		
		emit_log("[color=#f66b2e]  -> 玩家轰出【%s】！主目标 %s 承受 [b]%.0f[/b] 烈焰暴击！引发大爆炸溅射其余 %d 只怪物！[/color]" % [
			skill_name, primary_m["name_cn"], main_dmg, splash_count
		])
		
		dead_indices.sort()
		dead_indices.reverse()
		for d_idx in dead_indices:
			_on_single_monster_killed(d_idx)
			
	else:
		# 疾影闪烁 Dash
		var target = active_monsters[focused_target_index if focused_target_index < active_monsters.size() else 0]
		var dmg_info = CombatCalculatorClass.calculate_damage(p_stats, target, null, null)
		var fdmg = dmg_info.amount
		target["current_hp"] = max(0.0, target["current_hp"] - fdmg)
		emit_log("[color=#63b3ed]  -> 玩家施放【%s】穿梭闪击 %s 造成 %.0f 点迅捷伤害，并获得无敌闪避身法！[/color]" % [
			skill_name, target["name_cn"], fdmg
		])
		if target["current_hp"] <= 0.0:
			_on_single_monster_killed(focused_target_index if focused_target_index < active_monsters.size() else 0)
	
	_emit_squad_update()
	return true

## 怪群单只怪物独立反击玩家 (包含地图8词缀附加元素伤、吸血、异常效果)
func _execute_monster_counterattack(monster_index: int) -> void:
	if monster_index >= active_monsters.size():
		return
	
	var m = active_monsters[monster_index]
	var m_aspd = max(0.4, float(m.get("attack_speed", 0.85)))
	m["attack_timer"] = 1.0 / m_aspd
	
	var p_stats = InventoryManager.get_total_player_stats()
	# 地图词缀降低玩家防御
	var def_red = float(current_waystone.get("modifiers_summary", {}).get("player_defense_reduction_pct", 0.0)) if is_in_waystone else 0.0
	var effective_p_stats = p_stats.duplicate()
	effective_p_stats["armor"] = float(p_stats.get("armor", 0.0)) * (1.0 - def_red)
	effective_p_stats["evasion"] = float(p_stats.get("evasion", 0.0)) * (1.0 - def_red)
	
	var dmg_info = CombatCalculatorClass.calculate_damage(m, effective_p_stats, null, null)
	
	if dmg_info.is_miss:
		var ghost_heal = float(p_stats.get("ghost_dance_heal", 0.0))
		if ghost_heal > 0.0:
			player_hp = min(player_max_hp, player_hp + player_max_hp * ghost_heal)
			player_state_updated.emit(player_hp, player_max_hp, player_mp, player_max_mp)
			emit_log("[color=#48bb78]  <- %s 攻击玩家，被玩家 [闪避]！触发【鬼魅幽影】回血 +%.0f！[/color]" % [m["name_cn"], player_max_hp * ghost_heal])
		else:
			emit_log("[color=#48bb78]  <- %s 攻击玩家，被玩家身形一闪 [成功闪避]！[/color]" % m["name_cn"])
		return
	
	# 基础物理伤害 + 地图8词缀附加额外火/冰/雷伤害 (受玩家火/冰/电抗性减免，抗性上限 75%)
	var base_dmg = dmg_info.amount
	var p_fire_res = clampf(float(effective_p_stats.get("fire_res", 0.0)), -0.6, 0.75)
	var p_cold_res = clampf(float(effective_p_stats.get("cold_res", 0.0)), -0.6, 0.75)
	var p_light_res = clampf(float(effective_p_stats.get("lightning_res", 0.0)), -0.6, 0.75)
	
	var extra_fire = base_dmg * float(m.get("extra_fire_pct", 0.0)) * (1.0 - p_fire_res)
	var extra_cold = base_dmg * float(m.get("extra_cold_pct", 0.0)) * (1.0 - p_cold_res)
	var extra_light = base_dmg * float(m.get("extra_lightning_pct", 0.0)) * (1.0 - p_light_res)
	var total_taken = base_dmg + extra_fire + extra_cold + extra_light
	
	# 玩家承受感电增伤 20%
	if player_shock_timer > 0.0:
		total_taken *= 1.20
	
	player_hp = max(0.0, player_hp - total_taken)
	player_state_updated.emit(player_hp, player_max_hp, player_mp, player_max_mp)
	
	# 怪物吸血机制
	var leech_pct = float(m.get("life_steal_pct", 0.0))
	if leech_pct > 0.0:
		var leech_amt = total_taken * leech_pct
		m["current_hp"] = min(float(m["max_hp"]), float(m["current_hp"]) + leech_amt)
		emit_log("[color=#9f7aea]  <- %s 击中吸血，回复自身 %.0f 生命！[/color]" % [m["name_cn"], leech_amt])
	
	# 怪物击中施加感电 / 流血
	if m.get("shock_on_hit", false):
		player_shock_timer = 4.0
		emit_log("[color=#63b3ed]  <- 玩家被 %s 施加了【感电】! 承受伤害提升 20%%！[/color]" % m["name_cn"])
	
	if m.get("bleed_on_hit", false):
		player_bleed_timer = 3.0
		player_bleed_dps = total_taken * 0.35 / 3.0
		emit_log("[color=#fc8181]  <- 玩家受到 %s 撕裂流血持续创伤！[/color]" % m["name_cn"])
	
	if extra_fire > 0 or extra_cold > 0 or extra_light > 0:
		emit_log("[color=#e53e3e]  <- %s 反击命中！物理 %.0f + 词缀元素 [火+%.0f 冰+%.0f 雷+%.0f (抗性减免)]，玩家受到 %.0f 点伤害！[/color]" % [
			m["name_cn"], base_dmg, extra_fire, extra_cold, extra_light, total_taken
		])
	else:
		emit_log("[color=#e53e3e]  <- %s 反击，玩家受到 %.0f 点伤害！[/color]" % [m["name_cn"], total_taken])
	
	if player_hp <= 0.0:
		_on_player_defeated()

## 单只怪物阵亡结算
func _on_single_monster_killed(index: int) -> void:
	if index < 0 or index >= active_monsters.size():
		return
	
	var m = active_monsters[index]
	var m_name = m["name_cn"]
	var m_rarity = m.get("rarity", "normal")
	var is_boss = m.get("is_boss", false) or (m_rarity == "unique")
	
	var p_stats = InventoryManager.get_total_player_stats()
	var gold_mult = 1.0 + float(p_stats.get("gold_drop_mult", 0.0))
	var exp_mod = 1.0 + (float(current_waystone.get("modifiers_summary", {}).get("exp_bonus_pct", 0.0)) if is_in_waystone else 0.0)
	
	var exp_gained = int(m["exp_reward"] * exp_mod)
	var gold_gained = int(randi_range(m["gold_min"], m["gold_max"]) * gold_mult)
	
	if is_boss:
		emit_log("[color=#ed8936]【史诗大捷!】成功诛杀终极首领【%s】! 斩获海量经验 +%d, 金币 +%d！[/color]" % [m_name, exp_gained, gold_gained])
	elif m_rarity == "rare":
		emit_log("[color=#f6e05e]【稀有金怪击杀】诛灭黄金精英【%s】! 获得 经验 +%d, 金币 +%d[/color]" % [m_name, exp_gained, gold_gained])
	elif m_rarity == "magic":
		emit_log("[color=#63b3ed]【魔法怪群击杀】歼灭强化怪【%s】! 获得 经验 +%d, 金币 +%d[/color]" % [m_name, exp_gained, gold_gained])
	else:
		emit_log("[color=#e2e8f0]【击杀】击杀【%s】! 获得 经验 +%d, 金币 +%d[/color]" % [m_name, exp_gained, gold_gained])
	
	InventoryManager.add_exp(exp_gained)
	InventoryManager.add_gold(gold_gained)
	
	_roll_loot_drop(m_rarity)
	
	killed_map_monsters += 1
	active_monsters.remove_at(index)
	
	if is_boss:
		_on_map_completed()
		return
	
	# 从地图怪物池中补充新怪物进入怪群
	if remaining_pool_monsters > 0:
		var new_m = _generate_map_monster()
		active_monsters.append(new_m)
		remaining_pool_monsters -= 1
	elif active_monsters.is_empty() and not map_boss_spawned:
		# 全部小怪肃清，唤醒首领
		encounter_timer = 0.8
	
	_sync_map_progress_ui()

## 地图圆满通关
func _on_map_completed() -> void:
	map_completed = true
	is_in_waystone = false
	is_in_rift = false
	map_boss_spawned = false
	
	var tier = current_waystone.get("tier", 1) if not current_waystone.is_empty() else 1
	var bonus_gold = tier * 300
	var bonus_exp = tier * 400
	
	InventoryManager.add_gold(bonus_gold)
	InventoryManager.add_exp(bonus_exp)
	
	emit_log("[color=#9f7aea]════════════════════════════════════════════[/color]")
	emit_log("[color=#9f7aea]【地图通关!】恭喜圆满肃清【%s】！[/color]" % map_display_title)
	emit_log("[color=#f6e05e]• 结算通关奖励: 金币 +%d, 角色经验 +%d！[/color]" % [bonus_gold, bonus_exp])
	emit_log("[color=#9f7aea]════════════════════════════════════════════[/color]")
	
	# 通关后几率额外掉落高阶引路石通货或打造石
	if randf() < 0.75:
		var currs = DataLoader.get_all_currencies()
		if not currs.is_empty():
			var cid = "chaos" if randf() < 0.4 else "regal"
			CraftingManager.add_currency(cid, 1)
			emit_log("[color=#ed8936]【通关战利品】斩获通货：【%s】x1 (已存入工坊)！[/color]" % currs[cid].get("name_cn", "通货"))
	
	_clear_all_monsters()
	_sync_map_progress_ui()
	encounter_timer = 1.2

func _roll_loot_drop(monster_rarity: String = "normal") -> void:
	var p_stats = InventoryManager.get_total_player_stats()
	var map_mods = current_waystone.get("modifiers_summary", {}) if is_in_waystone else {}
	
	var gear_mult = (1.0 + float(p_stats.get("gear_drop_mult", 0.0))) * (1.0 + float(map_mods.get("item_quant_pct", 0.0)))
	var curr_mult = (1.0 + float(p_stats.get("currency_drop_mult", 0.0))) * (1.0 + float(map_mods.get("currency_mult_pct", 0.0)))
	var rarity_mult = 1.0 + float(map_mods.get("item_rarity_pct", 0.0))
	
	var is_boss = (monster_rarity == "unique")
	var is_rare = (monster_rarity == "rare")
	var is_magic = (monster_rarity == "magic")
	
	var drop_chance = 0.35 * gear_mult
	var num_items = 1
	if is_boss:
		drop_chance = 1.0
		num_items = randi_range(2, 4)
	elif is_rare:
		drop_chance = 1.0
		num_items = randi_range(1, 2)
	elif is_magic:
		drop_chance = clampf(0.70 * gear_mult, 0.4, 1.0)
		num_items = 1
	
	for i in range(num_items):
		if is_boss or is_rare or randf() <= drop_chance:
			var target_lvl = InventoryManager.level
			var force_rarity = ""
			if is_boss:
				force_rarity = "legendary" if (randf() < 0.45 * rarity_mult) else "rare"
			elif is_rare:
				force_rarity = "rare" if (randf() < 0.65 * rarity_mult) else "magic"
			elif is_magic:
				force_rarity = "magic" if (randf() < 0.70 * rarity_mult) else "normal"
			
			var dropped_item = ItemGenerator.generate_random_item(target_lvl, force_rarity)
			var r_color = dropped_item.get("rarity_color", "#ffffff")
			var r_name = dropped_item.get("rarity_name_cn", "普通")
			var i_name = dropped_item.get("name_cn", "装备")
			
			var filter_res = LootFilterManager.evaluate_item(dropped_item) if is_instance_valid(LootFilterManager) else {"passed": true, "action": "auto_sell"}
			
			if filter_res.get("passed", true):
				var added = InventoryManager.add_item_to_bag(dropped_item)
				if added:
					emit_log("[color=%s]【掉落】获得 [%s] %s (已存入背包)[/color]" % [r_color, r_name, i_name])
				else:
					emit_log("[color=#fc8181]【背包已满】掉落的 [%s] %s 无法拾取![/color]" % [r_name, i_name])
			else:
				var act = filter_res.get("action", "auto_sell")
				var reason = filter_res.get("reason", "")
				if act == "auto_sell":
					var price = int(dropped_item.get("sell_price", 10))
					InventoryManager.add_gold(price)
					if is_instance_valid(LootFilterManager) and LootFilterManager.show_filtered_log:
						emit_log("[color=#718096]【掉落过滤】自动回收 [%s] %s，获得金币 +%d (%s)[/color]" % [r_name, i_name, price, reason])
				elif act == "discard":
					if is_instance_valid(LootFilterManager) and LootFilterManager.show_filtered_log:
						emit_log("[color=#718096]【掉落过滤】已舍弃 [%s] %s (%s)[/color]" % [r_name, i_name, reason])
	
	# 通货掉落
	var currency_chance = 0.12 * curr_mult
	var num_curr_drops = 1
	if is_boss:
		currency_chance = 1.0
		num_curr_drops = randi_range(2, 3)
	elif is_rare:
		currency_chance = clampf(0.85 * curr_mult, 0.5, 1.0)
		num_curr_drops = randi_range(1, 2)
	elif is_magic:
		currency_chance = clampf(0.35 * curr_mult, 0.2, 0.8)
		num_curr_drops = 1
	
	if randf() <= currency_chance:
		var currencies = DataLoader.get_all_currencies()
		if not currencies.is_empty():
			for i in range(num_curr_drops):
				var cid = _roll_weighted_currency(currencies, is_boss)
				CraftingManager.add_currency(cid, 1)
				var c_info = currencies[cid]
				emit_log("[color=%s]【通货掉落】获得打造通货：【%s】x1 (已存入工坊)！[/color]" % [
					c_info.get("rarity_color", "#63b3ed"), c_info.get("name_cn", "通货")
				])

func _roll_weighted_currency(currencies: Dictionary, is_boss: bool = false) -> String:
	if is_boss and randf() < 0.35:
		return "exalted" if randf() < 0.6 else "chaos"
	
	var total_weight = 0
	for cid in currencies.keys():
		total_weight += int(currencies[cid].get("drop_weight", 10))
	
	var r = randi() % max(1, total_weight)
	var cur_w = 0
	for cid in currencies.keys():
		cur_w += int(currencies[cid].get("drop_weight", 10))
		if r < cur_w:
			return cid
	return "transmutation"

func _on_player_defeated() -> void:
	emit_log("[color=#e53e3e][b]【战败】玩家体力不支倒下... 自动回城复活休整。[/b][/color]")
	is_in_waystone = false
	is_in_rift = false
	map_boss_spawned = false
	
	stop_exploration()
	player_hp = player_max_hp
	player_mp = player_max_mp
	player_shock_timer = 0.0
	player_bleed_timer = 0.0
	player_state_updated.emit(player_hp, player_max_hp, player_mp, player_max_mp)

func simulate_idle(duration_seconds: float) -> Dictionary:
	var scale = 1.0
	var map_mods = {}
	if is_in_waystone:
		scale = float(current_waystone.get("level_scale", 1.5))
		map_mods = current_waystone.get("modifiers_summary", {})
	else:
		var map_data = DataLoader.get_map_data(current_map_id)
		scale = float(map_data.get("level_scale", 1.0))
	
	var avg_kill_time = 2.0
	var total_kills = int(duration_seconds / avg_kill_time)
	
	var total_exp = 0
	var total_gold = 0
	var filtered_items_count = 0
	var filtered_gold = 0
	var items_dropped = []
	var currencies_dropped = {}
	
	var all_curr = DataLoader.get_all_currencies()
	var quant_mult = 1.0 + float(map_mods.get("item_quant_pct", 0.0))
	var rarity_mult = 1.0 + float(map_mods.get("item_rarity_pct", 0.0))
	var curr_mult = 1.0 + float(map_mods.get("currency_mult_pct", 0.0))
	
	for i in range(total_kills):
		var r_roll = randf()
		var m_rarity = "normal"
		var k_scale = 1.0
		if r_roll < 0.10:
			m_rarity = "rare"
			k_scale = 4.5
		elif r_roll < 0.35:
			m_rarity = "magic"
			k_scale = 2.2
		else:
			m_rarity = "normal"
			k_scale = 1.0
		
		total_exp += int(18 * k_scale * scale * (1.0 + float(map_mods.get("exp_bonus_pct", 0.0))))
		total_gold += int(randi_range(3, 8) * k_scale * scale)
		
		var item_chance = 0.18
		if m_rarity == "rare": item_chance = 0.85
		elif m_rarity == "magic": item_chance = 0.45
		
		if randf() < item_chance * quant_mult:
			var force_r = ""
			if m_rarity == "rare": force_r = "rare" if randf() < 0.6 * rarity_mult else "magic"
			elif m_rarity == "magic": force_r = "magic" if randf() < 0.65 * rarity_mult else "normal"
			
			var item = ItemGenerator.generate_random_item(InventoryManager.level, force_r)
			var filter_res = LootFilterManager.evaluate_item(item) if is_instance_valid(LootFilterManager) else {"passed": true, "action": "auto_sell"}
			if filter_res.get("passed", true):
				if items_dropped.size() < 20:
					items_dropped.append(item)
					InventoryManager.add_item_to_bag(item)
			else:
				filtered_items_count += 1
				if filter_res.get("action", "auto_sell") == "auto_sell":
					var price = int(item.get("sell_price", 10))
					total_gold += price
					filtered_gold += price
		
		var c_chance = 0.12
		if m_rarity == "rare": c_chance = 0.80
		elif m_rarity == "magic": c_chance = 0.35
		
		if randf() < c_chance * curr_mult:
			var cid = _roll_weighted_currency(all_curr)
			currencies_dropped[cid] = currencies_dropped.get(cid, 0) + 1
			CraftingManager.add_currency(cid, 1)
	
	InventoryManager.add_exp(total_exp)
	InventoryManager.add_gold(total_gold)
	
	return {
		"duration": duration_seconds,
		"kills": total_kills,
		"exp": total_exp,
		"gold": total_gold,
		"items_count": items_dropped.size(),
		"filtered_count": filtered_items_count,
		"filtered_gold": filtered_gold,
		"currencies": currencies_dropped
	}

func _emit_squad_update() -> void:
	if focused_target_index >= active_monsters.size():
		focused_target_index = maxi(0, active_monsters.size() - 1)
	monsters_squad_updated.emit(active_monsters, focused_target_index)
	if not active_monsters.is_empty():
		monster_state_updated.emit(active_monsters[focused_target_index])
	else:
		monster_state_updated.emit({})

func _sync_map_progress_ui() -> void:
	var remaining = remaining_pool_monsters + active_monsters.size()
	map_progress_updated.emit(killed_map_monsters, total_map_monsters, remaining, is_active, map_display_title, map_boss_spawned)
	rift_progress_updated.emit(float(killed_map_monsters), float(maxi(1, total_map_monsters)), is_in_rift)

func emit_log(bbcode: String) -> void:
	var timestamp = Time.get_time_string_from_system()
	battle_log_emitted.emit("[color=#718096][%s][/color] %s" % [timestamp, bbcode])
