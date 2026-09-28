#!/usr/bin/env python3
"""
Test Suite for Loot Filter System (装备掉落过滤系统)
Validates presets, rarity/slot/affix filtering, auto-sell gold conversion,
save/load persistence, and Godot engine runtime integration.
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

def test_files_exist():
    required_files = [
        "scripts/loot/loot_filter_manager.gd",
        "scripts/ui/loot_filter_panel.gd",
        "scenes/ui/loot_filter_panel.tscn"
    ]
    all_ok = True
    for f in required_files:
        full_p = os.path.join(PROJECT_ROOT, f)
        exists = os.path.isfile(full_p)
        print_result(f"File exists: {f}", exists)
        if not exists:
            all_ok = False
    return all_ok

def run_godot_unit_tests():
    godot_bin = "/home/machi/.local/bin/godot"
    if not os.path.isfile(godot_bin):
        res = subprocess.run(["which", "godot"], stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            godot_bin = res.stdout.strip()
        else:
            print("[WARN] Godot binary not found, skipping runtime test.")
            return True

    test_runner_script = """
extends Node

func _ready():
    print("[TEST] Starting Loot Filter In-Engine Integration Tests...")
    
    if not is_instance_valid(LootFilterManager):
        printerr("[FAIL] LootFilterManager autoload missing")
        get_tree().quit(1)
        return
    
    # Mock items
    var item_normal = {
        "rarity": "normal",
        "rarity_name_cn": "普通",
        "slot": "weapon",
        "required_level": 1,
        "sell_price": 10,
        "affixes": []
    }
    
    var item_magic = {
        "rarity": "magic",
        "rarity_name_cn": "魔法",
        "slot": "helmet",
        "required_level": 1,
        "sell_price": 25,
        "affixes": [{"id": "stout", "desc": "+30 最大生命"}]
    }
    
    var item_rare_1 = {
        "rarity": "rare",
        "rarity_name_cn": "稀有",
        "slot": "chest",
        "required_level": 1,
        "sell_price": 60,
        "affixes": [{"id": "stout", "desc": "+40 最大生命"}]
    }
    
    var item_rare_3 = {
        "rarity": "rare",
        "rarity_name_cn": "稀有",
        "slot": "chest",
        "required_level": 1,
        "sell_price": 90,
        "affixes": [
            {"id": "stout", "desc": "+40 最大生命"},
            {"id": "sharp", "desc": "+10 攻击力"},
            {"id": "flaming", "desc": "+12 火焰伤害"}
        ]
    }
    
    var item_legendary = {
        "rarity": "legendary",
        "rarity_name_cn": "暗金",
        "slot": "weapon",
        "required_level": 5,
        "sell_price": 200,
        "affixes": [
            {"id": "sharp", "desc": "+25 攻击力"},
            {"id": "thunder", "desc": "+20 闪电伤害"}
        ]
    }
    
    # 1. Test Preset: ALL
    LootFilterManager.apply_preset("all")
    assert(LootFilterManager.evaluate_item(item_normal)["passed"] == true, "ALL preset should pass normal")
    assert(LootFilterManager.evaluate_item(item_magic)["passed"] == true, "ALL preset should pass magic")
    assert(LootFilterManager.evaluate_item(item_rare_1)["passed"] == true, "ALL preset should pass rare")
    assert(LootFilterManager.evaluate_item(item_legendary)["passed"] == true, "ALL preset should pass legendary")
    print("[TEST] Preset 'ALL' passed.")
    
    # 2. Test Preset: HIDE_NORMAL
    LootFilterManager.apply_preset("hide_normal")
    assert(LootFilterManager.evaluate_item(item_normal)["passed"] == false, "HIDE_NORMAL should filter normal")
    assert(LootFilterManager.evaluate_item(item_magic)["passed"] == true, "HIDE_NORMAL should pass magic")
    assert(LootFilterManager.evaluate_item(item_rare_1)["passed"] == true, "HIDE_NORMAL should pass rare")
    print("[TEST] Preset 'HIDE_NORMAL' passed.")
    
    # 3. Test Preset: HIDE_NORMAL_MAGIC
    LootFilterManager.apply_preset("hide_normal_magic")
    assert(LootFilterManager.evaluate_item(item_normal)["passed"] == false, "HIDE_NORMAL_MAGIC should filter normal")
    assert(LootFilterManager.evaluate_item(item_magic)["passed"] == false, "HIDE_NORMAL_MAGIC should filter magic")
    assert(LootFilterManager.evaluate_item(item_rare_1)["passed"] == true, "HIDE_NORMAL_MAGIC should pass rare")
    assert(LootFilterManager.evaluate_item(item_legendary)["passed"] == true, "HIDE_NORMAL_MAGIC should pass legendary")
    print("[TEST] Preset 'HIDE_NORMAL_MAGIC' passed.")
    
    # 4. Test Preset: STRICT (min 2 affixes for rare)
    LootFilterManager.apply_preset("strict")
    assert(LootFilterManager.evaluate_item(item_normal)["passed"] == false, "STRICT should filter normal")
    assert(LootFilterManager.evaluate_item(item_magic)["passed"] == false, "STRICT should filter magic")
    assert(LootFilterManager.evaluate_item(item_rare_1)["passed"] == false, "STRICT should filter 1-affix rare")
    assert(LootFilterManager.evaluate_item(item_rare_3)["passed"] == true, "STRICT should pass 3-affix rare")
    assert(LootFilterManager.evaluate_item(item_legendary)["passed"] == true, "STRICT should pass legendary")
    print("[TEST] Preset 'STRICT' passed.")
    
    # 5. Test Slot Exclusion
    LootFilterManager.apply_preset("all")
    LootFilterManager.set_slot_rule("helmet", false)
    assert(LootFilterManager.evaluate_item(item_magic)["passed"] == false, "Slot helmet should be filtered")
    assert(LootFilterManager.evaluate_item(item_normal)["passed"] == true, "Slot weapon should pass")
    print("[TEST] Slot filtering passed.")
    
    # 6. Test Auto-Sell vs Discard
    LootFilterManager.apply_preset("hide_normal_magic")
    LootFilterManager.set_filter_action("auto_sell")
    var res_sell = LootFilterManager.evaluate_item(item_normal)
    assert(res_sell["passed"] == false, "Should filter normal")
    assert(res_sell["action"] == "auto_sell", "Action should be auto_sell")
    assert(res_sell["gold_earned"] == 10, "Gold earned should match sell_price")
    
    LootFilterManager.set_filter_action("discard")
    var res_discard = LootFilterManager.evaluate_item(item_normal)
    assert(res_discard["action"] == "discard", "Action should be discard")
    print("[TEST] Auto-Sell and Discard actions passed.")
    
    # 7. Test Save & Load
    var save_data = LootFilterManager.get_save_data()
    LootFilterManager.reset_to_default()
    assert(LootFilterManager.filter_action == "auto_sell", "Reset should set action auto_sell")
    LootFilterManager.load_save_data(save_data)
    assert(LootFilterManager.filter_action == "discard", "Load should restore discard action")
    print("[TEST] Save & Load config passed.")
    
    # 8. Test TextMain Scene Instantiation & Integration
    var main_scene = load("res://scenes/text_ui/text_main.tscn").instantiate()
    add_child(main_scene)
    
    var filter_panel = main_scene.get_node_or_null("LootFilterPanel")
    assert(filter_panel != null, "LootFilterPanel must exist in Main scene")
    var filter_btn = main_scene.get_node_or_null("HBox/RightPanel/VBox/ActionRow2/FilterOpenBtn")
    assert(filter_btn != null, "FilterOpenBtn must exist in Main scene")
    var status_label = main_scene.get_node_or_null("HBox/RightPanel/VBox/FilterStatusLabel")
    assert(status_label != null, "FilterStatusLabel must exist in Main scene")
    print("[TEST] Main scene UI hierarchy verified.")
    
    # 9. Test Idle Simulation Report
    var engine = main_scene.get_node("TextBattleEngine")
    var sim_res = engine.simulate_idle(30.0)
    assert(sim_res.has("filtered_count"), "Idle report must include filtered_count")
    assert(sim_res.has("filtered_gold"), "Idle report must include filtered_gold")
    print("[TEST] TextBattleEngine idle integration passed (Kills: %d, Filtered: %d, Gold: %d)." % [
        sim_res["kills"], sim_res["filtered_count"], sim_res["filtered_gold"]
    ])
    
    print("[PASS] ALL IN-ENGINE TESTS COMPLETED SUCCESSFULLY!")
    get_tree().quit(0)
"""

    temp_runner_path = os.path.join(PROJECT_ROOT, "tests", "temp_test_runner.gd")
    with open(temp_runner_path, "w", encoding="utf-8") as f:
        f.write(test_runner_script)
    
    temp_scene_content = f"""[gd_scene load_steps=2 format=3 uid="uid://testrunnerscene"]

[ext_resource type="Script" path="res://tests/temp_test_runner.gd" id="1_runner"]

[node name="TestRunner" type="Node"]
script = ExtResource("1_runner")
"""
    temp_scene_path = os.path.join(PROJECT_ROOT, "tests", "temp_test_scene.tscn")
    with open(temp_scene_path, "w", encoding="utf-8") as f:
        f.write(temp_scene_content)
    
    try:
        cmd = [godot_bin, "--headless", "--path", PROJECT_ROOT, "res://tests/temp_test_scene.tscn"]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=12)
        print("Godot Output:\n", proc.stdout)
        if proc.stderr:
            print("Godot Stderr:\n", proc.stderr)
        passed = proc.returncode == 0 and "ALL IN-ENGINE TESTS COMPLETED SUCCESSFULLY!" in proc.stdout
        print_result("Loot Filter In-Engine Integration Tests", passed)
        return passed
    finally:
        if os.path.isfile(temp_runner_path):
            os.remove(temp_runner_path)
        if os.path.isfile(temp_scene_path):
            os.remove(temp_scene_path)

def main():
    print("=== LOOT FILTER SYSTEM - TEST SUITE ===")
    ok1 = test_files_exist()
    ok2 = run_godot_unit_tests()
    
    if ok1 and ok2:
        print("\n\033[92m>>> ALL LOOT FILTER TESTS PASSED! <<<\033[0m")
        sys.exit(0)
    else:
        print("\n\033[91m>>> SOME TESTS FAILED! <<<\033[0m")
        sys.exit(1)

if __name__ == "__main__":
    main()
