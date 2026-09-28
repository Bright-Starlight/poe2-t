extends Node

## GameManager: 全局游戏生命周期、存档持久化与离线收益管理器

const GAME_VERSION: String = "v0.1.0-alpha"
const SAVE_PATH: String = "user://savegame.json"

enum GameState {
	INITIALIZING,
	TITLE_SCREEN,
	IN_GAME,
	PAUSED,
	GAME_OVER
}

var current_state: GameState = GameState.INITIALIZING
var is_auto_combat_enabled: bool = false
var game_time: float = 0.0

var auto_save_timer: float = 0.0
var offline_report_pending: Dictionary = {}

func _ready() -> void:
	print("[GameManager] Initializing Pixel ARPG Loot Game - Version: %s" % GAME_VERSION)
	_setup_system()
	
	# 尝试读取存档
	load_game()

func _process(delta: float) -> void:
	if current_state == GameState.IN_GAME:
		game_time += delta
		auto_save_timer += delta
		if auto_save_timer >= 25.0:
			auto_save_timer = 0.0
			save_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()

func _setup_system() -> void:
	randomize()
	current_state = GameState.IN_GAME
	EventBus.game_started.emit()
	print("[GameManager] Game started successfully.")

func save_game() -> bool:
	if not is_instance_valid(InventoryManager) or not is_instance_valid(CraftingManager):
		return false
	
	var save_data = {
		"version": GAME_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"player": {
			"level": InventoryManager.level,
			"current_exp": InventoryManager.current_exp,
			"max_exp": InventoryManager.max_exp,
			"gold": InventoryManager.gold,
			"unspent_stat_points": InventoryManager.unspent_stat_points,
			"allocated_strength": InventoryManager.allocated_strength,
			"allocated_dexterity": InventoryManager.allocated_dexterity,
			"allocated_intelligence": InventoryManager.allocated_intelligence,
			"base_stats": InventoryManager.base_player_stats,
			"equipped_slots": InventoryManager.equipped_slots,
			"bag_items": InventoryManager.bag_items
		},
		"crafting": {
			"currencies": CraftingManager.currencies
		},
		"talents": {
			"unspent": TalentManager.unspent_talent_points if is_instance_valid(TalentManager) else 0,
			"allocated": TalentManager.allocated_nodes if is_instance_valid(TalentManager) else []
		},
		"loot_filter": LootFilterManager.get_save_data() if is_instance_valid(LootFilterManager) else {}
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		printerr("[GameManager] Failed to save game to %s" % SAVE_PATH)
		return false
	
	file.store_string(JSON.stringify(save_data, "\t"))
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("[GameManager] No existing savegame found, starting new game.")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	
	var json_str = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		printerr("[GameManager] Corrupted savegame format.")
		return false
	
	var data = json.data as Dictionary
	var p_data = data.get("player", {})
	if not p_data.is_empty():
		InventoryManager.level = int(p_data.get("level", 1))
		InventoryManager.current_exp = int(p_data.get("current_exp", 0))
		InventoryManager.max_exp = int(p_data.get("max_exp", 100))
		InventoryManager.gold = int(p_data.get("gold", 50))
		
		InventoryManager.unspent_stat_points = int(p_data.get("unspent_stat_points", 0))
		InventoryManager.allocated_strength = int(p_data.get("allocated_strength", 0))
		InventoryManager.allocated_dexterity = int(p_data.get("allocated_dexterity", 0))
		InventoryManager.allocated_intelligence = int(p_data.get("allocated_intelligence", 0))
		
		if p_data.has("base_stats"):
			for k in p_data["base_stats"].keys():
				InventoryManager.base_player_stats[k] = float(p_data["base_stats"][k])
		
		if p_data.has("equipped_slots"):
			InventoryManager.equipped_slots = p_data["equipped_slots"]
		
		if p_data.has("bag_items"):
			var items_arr: Array[Dictionary] = []
			for it in p_data["bag_items"]:
				if it is Dictionary:
					items_arr.append(it)
			InventoryManager.bag_items = items_arr
	
	var c_data = data.get("crafting", {})
	if not c_data.is_empty() and c_data.has("currencies"):
		for k in c_data["currencies"].keys():
			CraftingManager.currencies[k] = int(c_data["currencies"][k])
		CraftingManager.currencies_updated.emit(CraftingManager.currencies)
	
	var t_data = data.get("talents", {})
	if not t_data.is_empty() and is_instance_valid(TalentManager):
		TalentManager.unspent_talent_points = int(t_data.get("unspent", 0))
		var alloc_arr: Array[String] = []
		for nid in t_data.get("allocated", []):
			alloc_arr.append(str(nid))
		TalentManager.allocated_nodes = alloc_arr
		TalentManager.talents_updated.emit(TalentManager.allocated_nodes, TalentManager.unspent_talent_points)
	
	var f_data = data.get("loot_filter", {})
	if not f_data.is_empty() and is_instance_valid(LootFilterManager):
		LootFilterManager.load_save_data(f_data)
	
	# 离线挂机收益计算 (上限 12 小时 = 43200 秒)
	var last_time = int(data.get("timestamp", 0))
	var now_time = int(Time.get_unix_time_from_system())
	var elapsed = now_time - last_time
	
	if elapsed >= 15:
		var offline_sec = min(43200, elapsed)
		offline_report_pending = {
			"elapsed_seconds": offline_sec,
			"real_seconds": elapsed
		}
	
	print("[GameManager] Savegame loaded successfully. Player Lv.%d, Gold: %d" % [
		InventoryManager.level, InventoryManager.gold
	])
	return true

func get_formatted_play_time() -> String:
	var total_seconds: int = int(game_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
