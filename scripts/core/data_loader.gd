extends Node

## DataLoader: 全局统一数据加载器
## 负责解析、校验与缓存 res://data/ 目录下的所有 JSON 配置文件

var _monsters_cache: Dictionary = {}
var _skills_cache: Dictionary = {}
var _items_cache: Dictionary = {}
var _affixes_cache: Dictionary = {}
var _maps_cache: Dictionary = {}
var _currencies_cache: Dictionary = {}
var _talents_cache: Dictionary = {}
var _rifts_cache: Dictionary = {}
var _map_affixes_cache: Dictionary = {}
var _waystones_cache: Dictionary = {}
var _slot_icons_cache: Dictionary = {}
var _monster_affixes_cache: Array = []

const SLOT_NAMES_CN: Dictionary = {
	"weapon": "主手武器",
	"helmet": "头部防具",
	"chest": "胸部铠甲",
	"gloves": "手部护甲",
	"boots": "足部胫甲",
	"amulet": "项链护符",
	"ring": "戒指指环"
}

func _ready() -> void:
	print("[DataLoader] Initializing game data caches...")
	_load_all_data()

func _load_all_data() -> void:
	_monsters_cache = load_json_file("res://data/monsters/monsters.json")
	_skills_cache = load_json_file("res://data/skills/skills.json")
	_items_cache = load_json_file("res://data/items/base_items.json")
	_affixes_cache = load_json_file("res://data/affixes/affixes.json")
	_maps_cache = load_json_file("res://data/maps/maps.json")
	_currencies_cache = load_json_file("res://data/crafting/currencies.json")
	_talents_cache = load_json_file("res://data/talents/passive_tree.json")
	_rifts_cache = load_json_file("res://data/maps/rifts.json")
	_map_affixes_cache = load_json_file("res://data/affixes/map_affixes.json")
	_waystones_cache = load_json_file("res://data/maps/waystones.json")
	_monster_affixes_cache = load_json_array("res://data/affixes/monster_affixes.json")
	_preload_slot_icons()
	
	print("[DataLoader] Loaded: %d monsters, %d skills, %d base items, %d maps, %d currencies, %d talent trees, %d rifts, %d waystones, %d monster affixes, %d slot icons." % [
		_monsters_cache.size(), _skills_cache.size(), _items_cache.size(), _maps_cache.size(), _currencies_cache.size(), _talents_cache.size(), _rifts_cache.size(), _waystones_cache.size(), _monster_affixes_cache.size(), _slot_icons_cache.size()
	])

func _preload_slot_icons() -> void:
	var slots = ["weapon", "helmet", "chest", "gloves", "boots", "amulet", "ring"]
	for s in slots:
		var path = "res://assets/icons/slots/%s.svg" % s
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			_slot_icons_cache[s] = load(path)
		else:
			push_warning("[DataLoader] Missing slot icon at: %s" % path)

func get_slot_icon(slot: String) -> Texture2D:
	if _slot_icons_cache.has(slot):
		return _slot_icons_cache[slot]
	var path = "res://assets/icons/slots/%s.svg" % slot
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var tex = load(path) as Texture2D
		_slot_icons_cache[slot] = tex
		return tex
	return null

func get_slot_name_cn(slot: String) -> String:
	return SLOT_NAMES_CN.get(slot, slot if slot != "" else "装备")

func load_json_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		printerr("[DataLoader] JSON file not found: %s" % file_path)
		return {}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("[DataLoader] Failed to open file: %s" % file_path)
		return {}
	
	var json_text = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		printerr("[DataLoader] JSON Parse Error in %s: %s at line %d" % [file_path, json.get_error_message(), json.get_error_line()])
		return {}
	
	if json.data is Dictionary:
		return json.data
	return {}

func load_json_array(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		printerr("[DataLoader] JSON file not found: %s" % file_path)
		return []
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		printerr("[DataLoader] Failed to open file: %s" % file_path)
		return []
	
	var json_text = file.get_as_text()
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		printerr("[DataLoader] JSON Parse Error in %s: %s at line %d" % [file_path, json.get_error_message(), json.get_error_line()])
		return []
	
	if json.data is Array:
		return json.data
	return []

func get_monster_affixes_data() -> Array:
	return _monster_affixes_cache

func get_monster_data(monster_id: String) -> Dictionary:
	return _monsters_cache.get(monster_id, {})

func get_skill_data(skill_id: String) -> Dictionary:
	return _skills_cache.get(skill_id, {})

func get_item_data(item_id: String) -> Dictionary:
	return _items_cache.get(item_id, {})

func get_affixes_data() -> Dictionary:
	return _affixes_cache

func get_map_data(map_id: String) -> Dictionary:
	return _maps_cache.get(map_id, {})

func get_all_monsters() -> Dictionary:
	return _monsters_cache

func get_all_skills() -> Dictionary:
	return _skills_cache

func get_all_base_items() -> Dictionary:
	return _items_cache

func get_all_maps() -> Dictionary:
	return _maps_cache

func get_currency_data(currency_id: String) -> Dictionary:
	return _currencies_cache.get(currency_id, {})

func get_all_currencies() -> Dictionary:
	return _currencies_cache

func get_passive_tree_data() -> Dictionary:
	return _talents_cache

func get_rift_data(rift_id: String) -> Dictionary:
	return _rifts_cache.get(rift_id, {})

func get_all_rifts() -> Dictionary:
	return _rifts_cache

func get_map_affixes_data() -> Dictionary:
	return _map_affixes_cache

func get_waystone_data(waystone_id: String) -> Dictionary:
	return _waystones_cache.get(waystone_id, {})

func get_all_waystones() -> Dictionary:
	return _waystones_cache
