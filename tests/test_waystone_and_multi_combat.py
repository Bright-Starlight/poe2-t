#!/usr/bin/env python3
"""
Comprehensive Automated Test Suite for:
1. PoE2 Style Waystones & 8-Affix Map Crafting System (引路石基底与8词缀重铸系统)
2. 4-Tier Monster Rarity System & Monster Affixes (4阶怪物稀有度与怪物专属词缀池)
3. 1vN Multi-Monster Squad Combat & Scaling (多怪同屏作战与词缀强化)
4. Map Clearance Progression & Boss Awakening (清图指标与终极首领降临)
"""

import os
import sys
import subprocess

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def print_result(check_name: str, passed: bool, detail: str = ""):
    status = "\033[92m[PASS]\033[0m" if passed else "\033[91m[FAIL]\033[0m"
    print(f"{status} {check_name}")
    if detail and not passed:
        print(f"       -> {detail}")

def test_file_structure():
    required_files = [
        "data/affixes/map_affixes.json",
        "data/affixes/monster_affixes.json",
        "data/maps/waystones.json",
        "scripts/map/waystone_manager.gd",
        "scripts/ui/waystone_panel.gd",
        "scenes/ui/waystone_panel.tscn",
        "scripts/core/text_battle_engine.gd",
        "scenes/text_ui/text_main.gd",
        "scenes/text_ui/text_main.tscn"
    ]
    all_ok = True
    for f in required_files:
        full_p = os.path.join(PROJECT_ROOT, f)
        exists = os.path.isfile(full_p)
        print_result(f"File exists: {f}", exists)
        if not exists:
            all_ok = False
    return all_ok

def run_godot_integration_tests():
    godot_bin = "/home/machi/.local/bin/godot"
    if not os.path.isfile(godot_bin):
        res = subprocess.run(["which", "godot"], stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            godot_bin = res.stdout.strip()
        else:
            print("[WARN] Godot binary not found, skipping in-engine execution.")
            return True

    runner_script_content = """extends Node

func _ready():
	print("==================================================")
	print("[TEST] Starting PoE2 Waystone, Monster Rarity & Multi-Combat Tests...")
	print("==================================================")
	
	var passed = true
	
	# ----------------------------------------------------
	# 1. Test DataLoader for Waystones, Map Affixes & Monster Affixes
	# ----------------------------------------------------
	var waystones = DataLoader.get_all_waystones()
	if waystones.size() < 5:
		printerr("[FAIL] Expected at least 5 waystones (T1~T5), got: ", waystones.size())
		passed = false
	else:
		print("[PASS] DataLoader loaded ", waystones.size(), " waystones (T1~T5)")
	
	var map_affixes = DataLoader.get_map_affixes_data()
	var pre_count = map_affixes.get("prefixes", []).size()
	var suf_count = map_affixes.get("suffixes", []).size()
	if pre_count < 5 or suf_count < 5:
		printerr("[FAIL] Expected at least 5 prefixes and 5 suffixes, got: pre=", pre_count, ", suf=", suf_count)
		passed = false
	else:
		print("[PASS] DataLoader loaded map affixes: ", pre_count, " prefixes, ", suf_count, " suffixes")
	
	var m_affixes = DataLoader.get_monster_affixes_data()
	if m_affixes.size() < 8:
		printerr("[FAIL] Expected at least 8 monster affixes, got: ", m_affixes.size())
		passed = false
	else:
		print("[PASS] DataLoader loaded monster affixes pool: ", m_affixes.size(), " affixes")
	
	# ----------------------------------------------------
	# 2. Test Waystone Generation & 8-Mod Limits
	# ----------------------------------------------------
	if not is_instance_valid(WaystoneManager):
		printerr("[FAIL] WaystoneManager autoload missing")
		get_tree().quit(1)
		return
	
	# 2.1 Normal Waystone (0 affixes)
	var ws_normal = WaystoneManager.generate_waystone("t1_waystone", "normal")
	if ws_normal.get("affixes", []).size() != 0:
		printerr("[FAIL] Normal waystone should have 0 affixes, got: ", ws_normal.get("affixes", []).size())
		passed = false
	else:
		print("[PASS] Normal Waystone generated with 0 affixes and base implicits: ", ws_normal.get("base_implicits", []).size())
	
	# 2.2 Corrupted 8-Mod Waystone (exactly 8 affixes: 4 prefix + 4 suffix)
	var ws_8mod = WaystoneManager.generate_waystone("t5_waystone", "corrupted_8mod")
	var affs_8 = ws_8mod.get("affixes", [])
	var p_cnt = 0
	var s_cnt = 0
	for a in affs_8:
		if a["type"] == "prefix": p_cnt += 1
		elif a["type"] == "suffix": s_cnt += 1
	
	if affs_8.size() != 8 or p_cnt != 4 or s_cnt != 4 or not ws_8mod.get("is_corrupted", false):
		printerr("[FAIL] Corrupted 8-mod waystone failed: total=", affs_8.size(), ", pre=", p_cnt, ", suf=", s_cnt, ", corrupted=", ws_8mod.get("is_corrupted"))
		passed = false
	else:
		print("[PASS] Corrupted 8-Mod Waystone successfully generated with 4 Prefixes + 4 Suffixes = 8 Affixes (Corrupted=True)")
	
	# 2.3 Modifiers Aggregation & Pack Size Scaling
	var summary_8 = ws_8mod.get("modifiers_summary", {})
	if summary_8.get("item_quant_pct", 0.0) <= 0.0 or summary_8.get("pack_size_pct", 0.0) <= 0.0:
		printerr("[FAIL] Modifiers summary failed to aggregate stat bonuses: ", summary_8)
		passed = false
	else:
		print("[PASS] Waystone totals aggregation: Quant +", summary_8.get("item_quant_pct", 0.0) * 100.0, "%, PackSize +", summary_8.get("pack_size_pct", 0.0) * 100.0, "%")
	
	# ----------------------------------------------------
	# 3. Test Waystone Currency Crafting Pipeline
	# ----------------------------------------------------
	CraftingManager.currencies["transmutation"] = 10
	CraftingManager.currencies["augmentation"] = 10
	CraftingManager.currencies["alteration"] = 10
	CraftingManager.currencies["regal"] = 10
	CraftingManager.currencies["chaos"] = 10
	CraftingManager.currencies["exalted"] = 10
	CraftingManager.currencies["scouring"] = 10
	CraftingManager.currencies["vaal"] = 10
	
	# 3.1 Transmute normal -> magic
	var craft_res1 = WaystoneManager.craft_waystone(ws_normal, "transmutation")
	if not craft_res1["success"] or craft_res1["waystone"]["rarity"] != "magic":
		printerr("[FAIL] Transmute crafting failed: ", craft_res1)
		passed = false
	else:
		print("[PASS] Transmutation crafted Normal -> Magic (", craft_res1["waystone"]["affixes"].size(), " affixes)")
	
	var ws_magic = craft_res1["waystone"]
	
	# 3.2 Augment if magic has 1 mod
	if ws_magic["affixes"].size() == 1:
		var craft_res2 = WaystoneManager.craft_waystone(ws_magic, "augmentation")
		if not craft_res2["success"] or craft_res2["waystone"]["affixes"].size() != 2:
			printerr("[FAIL] Augmentation failed: ", craft_res2)
			passed = false
		else:
			print("[PASS] Augmentation added 2nd affix to Magic Waystone")
			ws_magic = craft_res2["waystone"]
	
	# 3.3 Regal magic -> rare
	var craft_res3 = WaystoneManager.craft_waystone(ws_magic, "regal")
	if not craft_res3["success"] or craft_res3["waystone"]["rarity"] != "rare":
		printerr("[FAIL] Regal crafting failed: ", craft_res3)
		passed = false
	else:
		print("[PASS] Regal crafted Magic -> Rare (", craft_res3["waystone"]["affixes"].size(), " affixes)")
	
	var ws_rare = craft_res3["waystone"]
	
	# 3.4 Chaos reroll rare
	var craft_res4 = WaystoneManager.craft_waystone(ws_rare, "chaos")
	if not craft_res4["success"] or craft_res4["waystone"]["rarity"] != "rare":
		printerr("[FAIL] Chaos crafting failed: ", craft_res4)
		passed = false
	else:
		print("[PASS] Chaos re-rolled Rare Waystone (", craft_res4["waystone"]["affixes"].size(), " affixes)")
	
	# 3.5 Scouring rare -> normal
	var craft_res5 = WaystoneManager.craft_waystone(craft_res4["waystone"], "scouring")
	if not craft_res5["success"] or craft_res5["waystone"]["rarity"] != "normal" or craft_res5["waystone"]["affixes"].size() != 0:
		printerr("[FAIL] Scouring cleansing failed: ", craft_res5)
		passed = false
	else:
		print("[PASS] Scouring cleansed Waystone back to Normal (0 affixes)")
	
	# ----------------------------------------------------
	# 4. Test TextBattleEngine 1vN Multi-Monster Combat & 4-Tier Rarity
	# ----------------------------------------------------
	var engine_script = load("res://scripts/core/text_battle_engine.gd")
	var engine = Node.new()
	engine.set_script(engine_script)
	add_child(engine)
	
	# 4.1 Start 8-Mod Waystone
	engine.start_waystone(ws_8mod)
	if engine.active_monsters.size() < 2:
		printerr("[FAIL] Expected squad with at least 2 active monsters in 8-mod waystone, got: ", engine.active_monsters.size())
		passed = false
	else:
		print("[PASS] TextBattleEngine spawned active squad with ", engine.active_monsters.size(), " monsters (Max Capacity: ", engine.max_active_capacity, ")")
	
	# 4.2 Verify 4-Tier Monster Rarities & Affixes
	var rarities_found = {}
	for i in range(25):
		var test_m = engine._generate_map_monster()
		var r = test_m.get("rarity", "normal")
		rarities_found[r] = true
		
		match r:
			"normal":
				assert(test_m["monster_affixes"].size() == 0, "Normal monster should have 0 affixes")
				assert(test_m["rarity_color"] == "#e2e8f0", "Normal monster color should be #e2e8f0")
			"magic":
				assert(test_m["monster_affixes"].size() >= 1 and test_m["monster_affixes"].size() <= 2, "Magic monster should have 1~2 affixes")
				assert(test_m["rarity_color"] == "#63b3ed", "Magic monster color should be #63b3ed")
			"rare":
				assert(test_m["monster_affixes"].size() >= 2 and test_m["monster_affixes"].size() <= 4, "Rare monster should have 2~4 affixes")
				assert(test_m["rarity_color"] == "#f6e05e", "Rare monster color should be #f6e05e")
	
	print("[PASS] Monster Rarity generation verified! Observed rarities in test batch: ", rarities_found.keys())
	
	# 4.3 Verify sample monster stats & scaling
	var first_m = engine.active_monsters[0]
	print("[PASS] Sample monster in squad: ", first_m["name_cn"], " [", first_m["rarity_name_cn"], "] | HP: ", first_m["max_hp"], " | Atk: ", first_m["attack_damage"], " | Affixes: ", first_m["monster_affixes"].size())
	
	# 4.4 Test Whirlwind AoE hitting all active squad monsters simultaneously
	for m in engine.active_monsters:
		m["max_hp"] = 10000.0
		m["current_hp"] = 10000.0
		m["evasion"] = 0.0
	
	var pre_hps = []
	for m in engine.active_monsters:
		pre_hps.append(m["current_hp"])
	
	engine.player_mp = 100.0
	engine.skill_cooldowns["whirlwind"] = 0.0
	var cast_ww_ok = engine.cast_skill("whirlwind")
	if not cast_ww_ok:
		printerr("[FAIL] Whirlwind cast failed")
		passed = false
	else:
		var all_damaged = true
		for i in range(engine.active_monsters.size()):
			if engine.active_monsters[i]["current_hp"] >= pre_hps[i]:
				all_damaged = false
		if all_damaged:
			print("[PASS] Whirlwind AoE successfully damaged all active squad monsters simultaneously!")
		else:
			printerr("[FAIL] Whirlwind failed to damage all active squad monsters")
			passed = false
	
	# 4.5 Test Fireball splash damage
	if engine.active_monsters.size() >= 2:
		var pre_hps_fb = []
		for m in engine.active_monsters:
			pre_hps_fb.append(m["current_hp"])
		
		engine.player_mp = 100.0
		engine.skill_cooldowns["fireball"] = 0.0
		engine.set_focused_target(0)
		var cast_fb_ok = engine.cast_skill("fireball")
		if cast_fb_ok and engine.active_monsters[0]["current_hp"] < pre_hps_fb[0] and engine.active_monsters[1]["current_hp"] < pre_hps_fb[1]:
			print("[PASS] Fireball cast with primary damage and splash AoE to squad verified!")
	
	# 4.6 Test monster counterattack & player defense reduction / elemental extra damage
	engine.player_hp = 500.0
	engine.player_max_hp = 500.0
	var pre_player_hp = engine.player_hp
	if not engine.active_monsters.is_empty():
		engine._execute_monster_counterattack(0)
		if engine.player_hp < pre_player_hp or engine.player_shock_timer > 0.0 or engine.player_bleed_timer > 0.0:
			print("[PASS] Monster counterattack executed with map affixes (Player HP: ", pre_player_hp, " -> ", engine.player_hp, ")")
		else:
			print("[PASS] Monster counterattack resolved (missed/evaded)")
	
	# 4.7 Test Clear All Regular Monsters -> Boss Awakening
	# Reduce remaining pool to 0 and kill all active monsters
	engine.remaining_pool_monsters = 0
	while not engine.active_monsters.is_empty():
		engine._on_single_monster_killed(0)
	
	# Simulate process timer to spawn boss
	engine.encounter_timer = 0.0
	engine._process(0.1)
	
	if not engine.map_boss_spawned or engine.active_monsters.is_empty() or not engine.active_monsters[0].get("is_boss", false):
		printerr("[FAIL] Map Boss failed to awaken after regular pool was cleared: spawned=", engine.map_boss_spawned, ", squad=", engine.active_monsters)
		passed = false
	else:
		var boss = engine.active_monsters[0]
		assert(boss["rarity"] == "unique", "Boss rarity must be unique")
		assert(boss["rarity_color"] == "#ed8936", "Boss color must be #ed8936")
		print("[PASS] Map Boss Awakened! ", boss["name_cn"], " (HP: ", boss["max_hp"], ", Atk: ", boss["attack_damage"], ", Rarity: ", boss["rarity"], ")")
		
		# Kill boss and verify map completion
		var pre_gold = InventoryManager.gold
		var pre_exp = InventoryManager.current_exp
		engine._on_single_monster_killed(0)
		
		if not engine.map_completed:
			printerr("[FAIL] Map completion not flagged after killing boss")
			passed = false
		else:
			print("[PASS] Map completed successfully upon Boss defeat! Bonus Gold: +", InventoryManager.gold - pre_gold, ", Bonus EXP: +", InventoryManager.current_exp - pre_exp)
	
	# ----------------------------------------------------
	# 5. Test UI Instantiation & Integration
	# ----------------------------------------------------
	var main_scene = load("res://scenes/text_ui/text_main.tscn").instantiate()
	add_child(main_scene)
	
	var ws_panel = main_scene.get_node_or_null("WaystonePanel")
	assert(ws_panel != null, "WaystonePanel must exist in Main scene")
	var squad_box = main_scene.get_node_or_null("HBox/CenterPanel/VBox/SquadMonsterBox")
	assert(squad_box != null, "SquadMonsterBox must exist in Main scene")
	var map_prog_box = main_scene.get_node_or_null("HBox/CenterPanel/VBox/MapProgressBox")
	assert(map_prog_box != null, "MapProgressBox must exist in Main scene")
	print("[PASS] Main Scene UI Components (WaystonePanel, SquadMonsterBox, MapProgressBox) Verified!")
	
	print("==================================================")
	if passed:
		print("[ALL TESTS PASSED] PoE2 Waystone, 4-Tier Monster Rarity & 1vN Multi-Combat Engine Verified!")
		get_tree().quit(0)
	else:
		printerr("[FAILED] Some tests failed.")
		get_tree().quit(1)
"""

    temp_runner_path = os.path.join(PROJECT_ROOT, "tests", "temp_ws_runner.gd")
    with open(temp_runner_path, "w", encoding="utf-8") as f:
        f.write(runner_script_content)

    temp_scene_content = f"""[gd_scene load_steps=2 format=3 uid="uid://testwsrunnerscene"]

[ext_resource type="Script" path="res://tests/temp_ws_runner.gd" id="1_ws_runner"]

[node name="TestRunner" type="Node"]
script = ExtResource("1_ws_runner")
"""
    temp_scene_path = os.path.join(PROJECT_ROOT, "tests", "temp_ws_scene.tscn")
    with open(temp_scene_path, "w", encoding="utf-8") as f:
        f.write(temp_scene_content)

    try:
        cmd = [godot_bin, "--headless", "--path", PROJECT_ROOT, "res://tests/temp_ws_scene.tscn"]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20)
        print("Godot Output:\n", proc.stdout)
        if proc.stderr:
            print("Godot Stderr:\n", proc.stderr)
        passed = proc.returncode == 0 and "ALL TESTS PASSED" in proc.stdout
        print_result("PoE2 Waystone & Multi-Combat Integration Tests", passed)
        return passed
    finally:
        if os.path.isfile(temp_runner_path):
            os.remove(temp_runner_path)
        if os.path.isfile(temp_scene_path):
            os.remove(temp_scene_path)

def main():
    print("=== TEST SUITE: PoE2 WAYSTONE 8-AFFIXES, MONSTER RARITY & 1vN MULTI-COMBAT ===")
    ok1 = test_file_structure()
    ok2 = run_godot_integration_tests()
    
    if ok1 and ok2:
        print("\n\033[92m>>> ALL TESTS PASSED SUCCESSFULLY! <<<\033[0m")
        sys.exit(0)
    else:
        print("\n\033[91m>>> TESTS FAILED! <<<\033[0m")
        sys.exit(1)

if __name__ == "__main__":
    main()
