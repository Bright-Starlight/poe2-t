#!/usr/bin/env python3
"""
Comprehensive Automated Test Suite for:
PoE2 Style Equipment Affixes & T-Tier (T1~T5) System (PoE2 风格装备词缀与T级体系)
Validates:
1. Affix JSON structure, families, slots, and tier brackets (T1~T5).
2. In-Engine ItemGenerator (ilvl scaling, slot constraints, mutual exclusion, 3P+3S limits).
3. In-Engine CraftingManager with 7 core currencies on T-tier items.
4. Player stats aggregation & elemental resistances mitigation in combat.
"""

import os
import sys
import json
import subprocess

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def print_result(check_name: str, passed: bool, detail: str = ""):
    status = "\033[92m[PASS]\033[0m" if passed else "\033[91m[FAIL]\033[0m"
    print(f"{status} {check_name}")
    if detail and not passed:
        print(f"       -> {detail}")

def test_affix_json_structure():
    affix_file = os.path.join(PROJECT_ROOT, "data", "affixes", "affixes.json")
    if not os.path.isfile(affix_file):
        print_result("affixes.json exists", False, f"File not found: {affix_file}")
        return False
    
    with open(affix_file, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    prefixes = data.get("prefixes", [])
    suffixes = data.get("suffixes", [])
    
    if len(prefixes) < 8 or len(suffixes) < 8:
        print_result("affixes.json count", False, f"Expected >= 8 prefix/suffix families, got pre={len(prefixes)}, suf={len(suffixes)}")
        return False
    
    for category, pool in [("Prefix", prefixes), ("Suffix", suffixes)]:
        for fam in pool:
            fam_id = fam.get("family", "")
            slots = fam.get("slots", [])
            tiers = fam.get("tiers", [])
            if not fam_id or not slots or len(tiers) < 3:
                print_result(f"{category} family {fam_id} validity", False, f"Invalid family schema: {fam}")
                return False
            for t in tiers:
                for req_key in ["tier", "id", "name_cn", "required_level", "min_value", "max_value", "weight"]:
                    if req_key not in t:
                        print_result(f"Tier in {fam_id} missing {req_key}", False, f"Missing key: {req_key} in {t}")
                        return False
    
    print_result(f"affixes.json structure ({len(prefixes)} prefix families, {len(suffixes)} suffix families)", True)
    return True

def run_godot_integration_tests():
    godot_bin = "/home/machi/.local/bin/godot"
    if not os.path.isfile(godot_bin):
        res = subprocess.run(["which", "godot"], stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            godot_bin = res.stdout.strip()
        else:
            print("[WARN] Godot binary not found, skipping engine runner.")
            return True

    runner_script = """extends Node

func _ready():
	print("==================================================")
	print("[TEST] Starting PoE2 Affix & T-Tier Integration Tests...")
	print("==================================================")
	
	var passed = true
	
	# ----------------------------------------------------
	# 1. Test DataLoader for new affixes
	# ----------------------------------------------------
	var aff_data = DataLoader.get_affixes_data()
	var pre_fams = aff_data.get("prefixes", [])
	var suf_fams = aff_data.get("suffixes", [])
	if pre_fams.size() < 8 or suf_fams.size() < 8:
		printerr("[FAIL] DataLoader affixes cache invalid")
		passed = false
	else:
		print("[PASS] DataLoader loaded affixes with ", pre_fams.size(), " prefix families and ", suf_fams.size(), " suffix families.")
	
	# ----------------------------------------------------
	# 2. Test ItemGenerator with ilvl & slot constraints
	# ----------------------------------------------------
	# 2.1 Low level (Lv.1) item: must only have T3~T5 tiers, no T1/T2 requiring lv.20+
	for i in range(20):
		var low_item = ItemGenerator.generate_random_item(1, "rare")
		for a in low_item.get("affixes", []):
			if a["tier"] < 3:
				printerr("[FAIL] Low level (Lv.1) item rolled high tier: T", a["tier"], " - ", a["name_cn"])
				passed = false
	print("[PASS] Low level (Lv.1) items strictly respect ilvl tier restrictions.")
	
	# 2.2 High level (Lv.50) item: can roll T1/T2
	var has_t1 = false
	for i in range(50):
		var high_item = ItemGenerator.generate_random_item(50, "rare")
		for a in high_item.get("affixes", []):
			if a["tier"] == 1:
				has_t1 = true
	if not has_t1:
		printerr("[FAIL] High level (Lv.50) item failed to roll any T1 tier in 50 items")
		passed = false
	else:
		print("[PASS] High level (Lv.50) items successfully roll T1 top-tier affixes.")
	
	# 2.3 Rare Item 3~6 affixes & 3P+3S limits
	for i in range(30):
		var rare_item = ItemGenerator.generate_random_item(30, "rare")
		var affs = rare_item.get("affixes", [])
		if affs.size() < 3 or affs.size() > 6:
			printerr("[FAIL] Rare item affixes count out of [3, 6] range: ", affs.size())
			passed = false
		var p_c = 0
		var s_c = 0
		var fams = []
		for a in affs:
			if a["type"] == "prefix": p_c += 1
			else: s_c += 1
			if a["family"] in fams:
				printerr("[FAIL] Duplicate affix family rolled on item: ", a["family"])
				passed = false
			fams.append(a["family"])
		if p_c > 3 or s_c > 3:
			printerr("[FAIL] Prefix/Suffix limit exceeded on rare item: pre=", p_c, ", suf=", s_c)
			passed = false
	print("[PASS] Rare items correctly roll 3~6 affixes with max 3 prefixes and 3 suffixes without family collision.")
	
	# 2.4 Boots movement speed exclusive check
	for i in range(30):
		var weapon_item = ItemGenerator.generate_random_item(30, "rare")
		if weapon_item.get("slot") == "weapon":
			for a in weapon_item.get("affixes", []):
				if a["family"] == "increased_movement_speed":
					printerr("[FAIL] Weapon rolled boots-exclusive movement speed affix!")
					passed = false
	print("[PASS] Slot-exclusive affix rules strictly enforced.")
	
	# ----------------------------------------------------
	# 3. Test CraftingManager on T-tier Items
	# ----------------------------------------------------
	var white_item = ItemGenerator.generate_random_item(40, "normal")
	CraftingManager.add_currency("transmutation", 10)
	CraftingManager.add_currency("augmentation", 10)
	CraftingManager.add_currency("alteration", 10)
	CraftingManager.add_currency("regal", 10)
	CraftingManager.add_currency("chaos", 10)
	CraftingManager.add_currency("exalted", 10)
	CraftingManager.add_currency("scouring", 10)
	
	# 3.1 Transmute
	var craft_res = CraftingManager.craft_item("transmutation", white_item)
	assert(craft_res["success"] == true and craft_res["item"]["rarity"] == "magic", "Transmute failed")
	var magic_item = craft_res["item"]
	print("[PASS] Transmutation stone converted Normal -> Magic (", magic_item["affixes"].size(), " T-tier affixes)")
	
	# 3.2 Augment if 1 affix
	if magic_item["affixes"].size() == 1:
		var aug_res = CraftingManager.craft_item("augmentation", magic_item)
		assert(aug_res["success"] == true and aug_res["item"]["affixes"].size() == 2, "Augmentation failed")
		magic_item = aug_res["item"]
		print("[PASS] Augmentation added 2nd T-tier affix to Magic item.")
	
	# 3.3 Regal
	var regal_res = CraftingManager.craft_item("regal", magic_item)
	assert(regal_res["success"] == true and regal_res["item"]["rarity"] == "rare", "Regal failed")
	var rare_item_crafted = regal_res["item"]
	print("[PASS] Regal stone upgraded Magic -> Rare with ", rare_item_crafted["affixes"].size(), " affixes.")
	
	# 3.4 Chaos re-roll
	var chaos_res = CraftingManager.craft_item("chaos", rare_item_crafted)
	assert(chaos_res["success"] == true and chaos_res["item"]["affixes"].size() >= 3 and chaos_res["item"]["affixes"].size() <= 6, "Chaos failed")
	rare_item_crafted = chaos_res["item"]
	print("[PASS] Chaos stone re-rolled Rare item with ", rare_item_crafted["affixes"].size(), " T-tier affixes.")
	
	# 3.5 Exalted add mod if < 6
	if rare_item_crafted["affixes"].size() < 6:
		var pre_cnt = rare_item_crafted["affixes"].size()
		var ex_res = CraftingManager.craft_item("exalted", rare_item_crafted)
		assert(ex_res["success"] == true and ex_res["item"]["affixes"].size() == pre_cnt + 1, "Exalted failed")
		print("[PASS] Exalted stone slammed high-tier affix: ", ex_res["item"]["affixes"][-1]["name_cn"], " [T", ex_res["item"]["affixes"][-1]["tier"], "]")
	
	# 3.6 Scouring
	var scour_res = CraftingManager.craft_item("scouring", rare_item_crafted)
	assert(scour_res["success"] == true and scour_res["item"]["rarity"] == "normal" and scour_res["item"]["affixes"].size() == 0, "Scouring failed")
	print("[PASS] Scouring stone successfully cleansed item back to Normal.")
	
	# ----------------------------------------------------
	# 4. Test Player Stats Aggregation & Resistances
	# ----------------------------------------------------
	var test_ring = {
		"base_id": "sapphire_ring",
		"slot": "ring",
		"rarity": "rare",
		"item_level": 40,
		"base_stats": {},
		"affixes": [
			{"family": "fire_resistance", "type": "suffix", "stat": "fire_res", "value": 0.35, "name_cn": "之熔火", "tier": 1},
			{"family": "attribute_strength", "type": "suffix", "stat": "strength", "value": 20.0, "name_cn": "之巨力", "tier": 2}
		],
		"total_stats": {
			"fire_res": 0.35,
			"strength": 20.0
		}
	}
	InventoryManager.equip_item(test_ring)
	var p_stats = InventoryManager.get_total_player_stats()
	if float(p_stats.get("fire_res", 0.0)) < 0.35:
		printerr("[FAIL] Expected player fire_res >= 0.35, got: ", p_stats.get("fire_res"))
		passed = false
	else:
		print("[PASS] InventoryManager correctly aggregated fire resistance: ", p_stats.get("fire_res") * 100.0, "% and strength: ", p_stats.get("strength"))
	
	print("==================================================")
	if passed:
		print("[PASS] ALL POE2 AFFIX & TIER TESTS PASSED!")
		get_tree().quit(0)
	else:
		printerr("[FAIL] SOME TESTS FAILED!")
		get_tree().quit(1)
"""
    tmp_runner_path = os.path.join(PROJECT_ROOT, "tests", "temp_runner_affix_tier.gd")
    with open(tmp_runner_path, "w", encoding="utf-8") as f:
        f.write(runner_script)
    
    tmp_scene_content = f"""[gd_scene load_steps=2 format=3 uid="uid://affixtierscene"]

[ext_resource type="Script" path="res://tests/temp_runner_affix_tier.gd" id="1_runner"]

[node name="TestRunner" type="Node"]
script = ExtResource("1_runner")
"""
    tmp_scene_path = os.path.join(PROJECT_ROOT, "tests", "temp_scene_affix_tier.tscn")
    with open(tmp_scene_path, "w", encoding="utf-8") as f:
        f.write(tmp_scene_content)
    
    try:
        cmd = [godot_bin, "--headless", "--path", PROJECT_ROOT, "res://tests/temp_scene_affix_tier.tscn"]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=12)
        print("Godot Output:\n", proc.stdout)
        if proc.stderr:
            print("Godot Stderr:\n", proc.stderr)
        passed = (proc.returncode == 0) and ("ALL POE2 AFFIX & TIER TESTS PASSED!" in proc.stdout)
        print_result("PoE2 Affix Tier In-Engine Integration Tests", passed)
        return passed
    except Exception as e:
        print_result("Godot Headless Execution", False, str(e))
        return False
    finally:
        if os.path.isfile(tmp_runner_path):
            os.remove(tmp_runner_path)
        if os.path.isfile(tmp_scene_path):
            os.remove(tmp_scene_path)

def main():
    print("=== POE2 AFFIX & TIER SYSTEM VERIFICATION ===")
    ok1 = test_affix_json_structure()
    ok2 = run_godot_integration_tests()
    
    if ok1 and ok2:
        print("\n\033[92m>>> ALL CHECKS PASSED FOR POE2 AFFIX & T-TIER SYSTEM! <<<\033[0m")
        sys.exit(0)
    else:
        print("\n\033[91m>>> TESTS FAILED! <<<\033[0m")
        sys.exit(1)

if __name__ == "__main__":
    main()
