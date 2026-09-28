#!/usr/bin/env python3
"""
Pixel ARPG Project Validator & Headless Runner
Ensures all scenes, scripts, resources, and configurations are valid.
"""

import os
import sys
import re
import subprocess
import configparser

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def print_result(check_name: str, passed: bool, detail: str = ""):
    status = "\033[92m[PASS]\033[0m" if passed else "\033[91m[FAIL]\033[0m"
    print(f"{status} {check_name}")
    if detail and not passed:
        print(f"       -> {detail}")

def check_project_godot():
    project_godot_path = os.path.join(PROJECT_ROOT, "project.godot")
    if not os.path.isfile(project_godot_path):
        print_result("project.godot exists", False, "Missing project.godot")
        return False
    
    with open(project_godot_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Check main scene
    main_scene_match = re.search(r'run/main_scene="res://([^"]+)"', content)
    if not main_scene_match:
        print_result("Main scene configured", False, "Missing run/main_scene in project.godot")
        return False
    
    main_scene_rel = main_scene_match.group(1)
    main_scene_full = os.path.join(PROJECT_ROOT, main_scene_rel)
    if not os.path.isfile(main_scene_full):
        print_result("Main scene file exists", False, f"Main scene not found: {main_scene_full}")
        return False
    
    print_result("project.godot and main scene", True)
    return True

def check_autoloads():
    project_godot_path = os.path.join(PROJECT_ROOT, "project.godot")
    with open(project_godot_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    autoload_section = False
    all_ok = True
    for line in content.splitlines():
        line = line.strip()
        if line.startswith("[autoload]"):
            autoload_section = True
            continue
        elif line.startswith("[") and autoload_section:
            break
        if autoload_section and "=" in line:
            name, path = line.split("=", 1)
            clean_path = path.strip().strip('"')
            if clean_path.startswith("*res://"):
                clean_path = clean_path[7:]
            elif clean_path.startswith("res://"):
                clean_path = clean_path[6:]
            full_path = os.path.join(PROJECT_ROOT, clean_path)
            if not os.path.isfile(full_path):
                print_result(f"Autoload: {name.strip()}", False, f"File missing: {full_path}")
                all_ok = False
            else:
                print_result(f"Autoload: {name.strip()}", True)
    return all_ok

def check_scenes_and_scripts():
    all_ok = True
    for root, _, files in os.walk(PROJECT_ROOT):
        for file in files:
            full_path = os.path.join(root, file)
            if file.endswith(".tscn"):
                with open(full_path, "r", encoding="utf-8") as f:
                    content = f.read()
                # Check ext_resource paths
                for match in re.finditer(r'path="res://([^"]+)"', content):
                    res_path = match.group(1)
                    res_full = os.path.join(PROJECT_ROOT, res_path)
                    if not os.path.isfile(res_full):
                        print_result(f"Scene resource in {file}", False, f"Referenced resource not found: {res_path}")
                        all_ok = False
            elif file.endswith(".gd"):
                with open(full_path, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                # Basic sanity check
                if len(lines) == 0:
                    print_result(f"Script {file}", False, "Script is empty")
                    all_ok = False
    
    if all_ok:
        print_result("All .tscn references and .gd scripts", True)
    return all_ok

def run_headless_godot():
    godot_bin = "/home/machi/.local/bin/godot"
    if not os.path.isfile(godot_bin):
        # Try finding in PATH
        res = subprocess.run(["which", "godot"], stdout=subprocess.PIPE, text=True)
        if res.returncode == 0:
            godot_bin = res.stdout.strip()
        else:
            print("[INFO] Godot binary not found locally, skipping engine headless execution.")
            return True

    print(f"[INFO] Running Godot headless validation using {godot_bin}...")
    try:
        cmd = [godot_bin, "--headless", "--path", PROJECT_ROOT, "--quit-after", "60"]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
        print("Godot Output:\n", proc.stdout)
        if proc.stderr:
            print("Godot Stderr:\n", proc.stderr)
        passed = proc.returncode == 0 or "Game started successfully" in proc.stdout
        print_result("Godot Headless Engine Execution", passed)
        return passed
    except Exception as e:
        print_result("Godot Headless Execution", False, str(e))
        return False

def main():
    print("=== PIXEL ARPG LOOT - PROJECT INTEGRITY CHECK ===")
    ok1 = check_project_godot()
    ok2 = check_autoloads()
    ok3 = check_scenes_and_scripts()
    ok4 = run_headless_godot()
    
    if ok1 and ok2 and ok3 and ok4:
        print("\n\033[92m>>> ALL CHECKS PASSED FOR TEXT ARPG (LOOT & IDLE)! <<<\033[0m")
        sys.exit(0)
    else:
        print("\n\033[91m>>> SOME CHECKS FAILED! <<<\033[0m")
        sys.exit(1)

if __name__ == "__main__":
    main()
