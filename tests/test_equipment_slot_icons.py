#!/usr/bin/env python3
"""
Test Suite: Equipment Slot Visual Icons
Verifies that all 7 equipment slots have valid SVG assets, DataLoader caching,
and proper UI icon binding across Equipment Grid, Inventory, Item Tooltip,
Crafting Workshop, and Loot Filter panels.
"""

import os
import sys
import subprocess
import xml.etree.ElementTree as ET

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SLOTS = ["weapon", "helmet", "chest", "gloves", "boots", "amulet", "ring"]

def print_result(check_name: str, passed: bool, detail: str = ""):
    status = "\033[92m[PASS]\033[0m" if passed else "\033[91m[FAIL]\033[0m"
    print(f"{status} {check_name}")
    if detail and not passed:
        print(f"       -> {detail}")

def test_svg_assets():
    print("\n--- 1. Testing SVG Slot Icon Assets ---")
    all_ok = True
    for slot in SLOTS:
        svg_path = os.path.join(PROJECT_ROOT, "assets", "icons", "slots", f"{slot}.svg")
        if not os.path.isfile(svg_path):
            print_result(f"Asset exists: {slot}.svg", False, f"Missing file: {svg_path}")
            all_ok = False
            continue
        
        try:
            tree = ET.parse(svg_path)
            root = tree.getroot()
            if not root.tag.endswith("svg"):
                print_result(f"Valid SVG root: {slot}.svg", False, f"Root tag is {root.tag}")
                all_ok = False
                continue
            viewbox = root.attrib.get("viewBox", "")
            if not viewbox:
                print_result(f"Valid viewBox: {slot}.svg", False, "Missing viewBox attribute")
                all_ok = False
                continue
            print_result(f"SVG Asset: {slot}.svg (viewBox='{viewbox}')", True)
        except Exception as e:
            print_result(f"Parse SVG: {slot}.svg", False, str(e))
            all_ok = False
    return all_ok

def test_in_engine_slot_icons():
    print("\n--- 2. Testing In-Engine DataLoader & UI Icon Integration ---")
    
    godot_bin = "/home/machi/.local/bin/godot"
    if not os.path.isfile(godot_bin):
        res = subprocess.run(["which", "godot"], stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            godot_bin = res.stdout.strip()
        else:
            print("[WARN] Godot binary not found, skipping runtime test.")
            return True
            
    gdscript_test = """extends Node

func _ready():
	print("[TEST] Starting Equipment Slot Icons In-Engine Tests...")
	
	# 1. Test DataLoader icon loading and caching
	var slots = ["weapon", "helmet", "chest", "gloves", "boots", "amulet", "ring"]
	for s in slots:
		var tex = DataLoader.get_slot_icon(s)
		assert(tex != null, "DataLoader.get_slot_icon failed for slot: " + s)
		assert(tex is Texture2D, "get_slot_icon should return Texture2D for slot: " + s)
		var cn_name = DataLoader.get_slot_name_cn(s)
		assert(cn_name != "" and cn_name != s, "get_slot_name_cn failed for slot: " + s)
	print("[PASS] DataLoader slot icons & names mapping verified for all 7 slots.")
	
	# 2. Test TextMain equipment grid & inventory integration
	if is_instance_valid(GameManager):
		GameManager.offline_report_pending.clear()
	var main_scene = load("res://scenes/text_ui/text_main.tscn").instantiate()
	add_child(main_scene)
	
	# Check EquipGrid buttons
	var equip_grid = main_scene.get_node("HBox/LeftPanel/VBox/EquipGrid")
	assert(equip_grid != null, "EquipGrid node must exist")
	for child in equip_grid.get_children():
		var btn = child as Button
		assert(btn.icon != null, "EquipGrid button must have a slot icon set")
		assert(btn.expand_icon == true, "EquipGrid button should have expand_icon set to true")
	print("[PASS] TextMain EquipGrid 7 slot buttons icon binding verified.")
	
	# Add item to inventory and check BagList row
	var test_item = {
		"id": "test_helm",
		"name_cn": "测试重盔",
		"slot": "helmet",
		"rarity": "rare",
		"rarity_name_cn": "稀有",
		"rarity_color": "#f6e05e",
		"required_level": 5,
		"base_stats": {"max_hp": 50.0},
		"affixes": [{"desc": "+20 力量"}],
		"sell_price": 40
	}
	InventoryManager.add_item_to_bag(test_item)
	main_scene._refresh_inventory_ui()
	
	var bag_container = main_scene.get_node("HBox/RightPanel/VBox/Scroll/BagList")
	assert(bag_container.get_child_count() > 0, "Bag list should contain item rows")
	var first_row = bag_container.get_child(bag_container.get_child_count() - 1)
	var item_btn = first_row.get_child(0) as Button
	assert(item_btn != null, "Item button must exist in bag row")
	assert(item_btn.icon != null, "Inventory item button must have slot icon attached")
	assert(item_btn.expand_icon == true, "Inventory item button should expand icon")
	print("[PASS] Inventory item row icon binding verified (Icon: helmet).")
	
	# 3. Test ItemTooltip icon display
	var tooltip_scene = load("res://scenes/ui/item_tooltip.tscn").instantiate()
	add_child(tooltip_scene)
	tooltip_scene.display_item(test_item, false, 0)
	var tt_icon = tooltip_scene.get_node("VBox/HeaderRow/IconRect") as TextureRect
	assert(tt_icon != null, "Tooltip IconRect node must exist")
	assert(tt_icon.texture != null, "Tooltip IconRect texture must be set")
	assert(tt_icon.visible == true, "Tooltip IconRect must be visible for valid items")
	print("[PASS] ItemTooltip header slot icon display verified.")
	
	# 4. Test CraftingPanel icon display
	var craft_scene = load("res://scenes/ui/crafting_panel.tscn").instantiate()
	add_child(craft_scene)
	craft_scene.open_for_item(test_item, false, 0)
	var craft_icon = craft_scene.get_node("VBox/ItemInfoBox/ItemHeaderRow/ItemIconRect") as TextureRect
	assert(craft_icon != null, "CraftingPanel ItemIconRect node must exist")
	assert(craft_icon.texture != null, "CraftingPanel ItemIconRect texture must be set")
	assert(craft_icon.visible == true, "CraftingPanel ItemIconRect must be visible")
	print("[PASS] CraftingPanel target item slot icon display verified.")
	
	# 5. Test LootFilterPanel slot checkboxes icons
	var filter_scene = load("res://scenes/ui/loot_filter_panel.tscn").instantiate()
	add_child(filter_scene)
	var weapon_chk = filter_scene.get_node("VBox/SlotsGrid/WeaponCheck") as CheckBox
	assert(weapon_chk.icon != null, "LootFilterPanel WeaponCheck must have slot icon")
	var ring_chk = filter_scene.get_node("VBox/SlotsGrid/RingCheck") as CheckBox
	assert(ring_chk.icon != null, "LootFilterPanel RingCheck must have slot icon")
	print("[PASS] LootFilterPanel slot checkboxes icon binding verified.")
	
	print("[ALL_EQUIPMENT_SLOT_ICON_TESTS_PASSED]")
	get_tree().quit(0)
"""
    
    temp_runner_path = os.path.join(PROJECT_ROOT, "tests", "temp_icon_test_runner.gd")
    with open(temp_runner_path, "w", encoding="utf-8") as f:
        f.write(gdscript_test)
        
    temp_scene_content = f"""[gd_scene load_steps=2 format=3 uid="uid://icontestscene"]

[ext_resource type="Script" path="res://tests/temp_icon_test_runner.gd" id="1_icon_runner"]

[node name="TestRunner" type="Node"]
script = ExtResource("1_icon_runner")
"""
    temp_scene_path = os.path.join(PROJECT_ROOT, "tests", "temp_icon_test_scene.tscn")
    with open(temp_scene_path, "w", encoding="utf-8") as f:
        f.write(temp_scene_content)
        
    try:
        cmd = [godot_bin, "--headless", "--path", PROJECT_ROOT, "res://tests/temp_icon_test_scene.tscn"]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=15)
        
        print("Godot Output:\n", proc.stdout)
        if proc.stderr:
            print("Godot Stderr:\n", proc.stderr)
            
        passed = (proc.returncode == 0) and ("[ALL_EQUIPMENT_SLOT_ICON_TESTS_PASSED]" in proc.stdout)
        print_result("Godot Headless Slot Icons Integration", passed)
        return passed
    except Exception as e:
        print_result("Godot Headless Slot Icons Integration", False, str(e))
        return False
    finally:
        if os.path.isfile(temp_runner_path):
            os.remove(temp_runner_path)
        if os.path.isfile(temp_scene_path):
            os.remove(temp_scene_path)

def main():
    print("=== TEST SUITE: EQUIPMENT SLOT VISUAL ICONS ===")
    r1 = test_svg_assets()
    r2 = test_in_engine_slot_icons()
    
    if r1 and r2:
        print("\n>>> ALL EQUIPMENT SLOT ICON TESTS PASSED! <<<")
        sys.exit(0)
    else:
        print("\n>>> SOME TESTS FAILED! <<<")
        sys.exit(1)

if __name__ == "__main__":
    main()
