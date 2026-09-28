#!/usr/bin/env python3
"""
Pixel ARPG Game Launcher & Dev Utility
Usage:
    python3 run.py            # Run the game
    python3 run.py --test     # Run integrity checks
    python3 run.py --download # Download official Godot 4.3 binary
"""

import os
import sys
import shutil
import subprocess
import argparse
import urllib.request
import zipfile
import io

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))

def find_godot_executable():
    # 1. Check environment variable
    if "GODOT4_BIN" in os.environ and os.path.isfile(os.environ["GODOT4_BIN"]):
        return os.environ["GODOT4_BIN"]
    
    # 2. Check local bin
    local_paths = [
        os.path.expanduser("~/.local/bin/godot"),
        os.path.expanduser("~/.local/bin/godot4"),
        os.path.join(PROJECT_DIR, "bin", "godot"),
        "/usr/local/bin/godot",
        "/usr/bin/godot",
        "/usr/bin/godot4",
        "/snap/bin/godot"
    ]
    for p in local_paths:
        if os.path.isfile(p) and os.access(p, os.X_OK):
            return p
            
    # 3. Check PATH
    for candidate in ["godot", "godot4", "godot-engine"]:
        found = shutil.which(candidate)
        if found:
            return found
            
    return None

def download_godot():
    target_dir = os.path.expanduser("~/.local/bin")
    os.makedirs(target_dir, exist_ok=True)
    
    url = "https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip"
    print(f"\n[Download] Fetching Godot 4.3 from {url}...")
    print("[Download] This may take 1-2 minutes depending on network speed...")
    
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = resp.read()
        print("[Download] Download complete, extracting...")
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            for name in z.namelist():
                z.extract(name, target_dir)
                full_path = os.path.join(target_dir, name)
                os.chmod(full_path, 0o755)
                symlink_path = os.path.join(target_dir, "godot")
                if os.path.exists(symlink_path) or os.path.islink(symlink_path):
                    try:
                        os.remove(symlink_path)
                    except Exception:
                        pass
                try:
                    os.symlink(full_path, symlink_path)
                except Exception:
                    pass
                print(f"[Success] Installed Godot 4 binary at: {full_path}")
                return full_path
    except Exception as e:
        print(f"[Error] Failed to auto-download Godot: {e}")
        print("\nManual download link: https://godotengine.org/download/")
        return None

def run_checks():
    test_script = os.path.join(PROJECT_DIR, "tests", "verify_project.py")
    if os.path.isfile(test_script):
        subprocess.run([sys.executable, test_script])
    else:
        print("[Error] Test script not found at tests/verify_project.py")

def main():
    parser = argparse.ArgumentParser(description="Pixel ARPG Launcher & Utility")
    parser.add_argument("--test", action="store_true", help="Run project integrity checks")
    parser.add_argument("--download", action="store_true", help="Download Godot 4.3 binary")
    parser.add_argument("--extra-args", nargs=argparse.REMAINDER, help="Pass additional arguments to Godot")
    args = parser.parse_args()

    if args.test:
        run_checks()
        return

    if args.download:
        download_godot()
        return

    godot_path = find_godot_executable()
    if not godot_path:
        print("\n" + "="*60)
        print("  [!] Godot 4 executable was not found on your system PATH.")
        print("="*60)
        print("\nOptions to launch the game:")
        print("  1. Open Godot 4 Editor GUI -> Import -> Select project.godot -> Run")
        print("  2. Run 'python3 run.py --download' to automatically download Godot 4")
        print("  3. Set GODOT4_BIN environment variable to your godot binary path:")
        print("     export GODOT4_BIN=/path/to/godot")
        print("     python3 run.py")
        print("="*60 + "\n")
        return

    print(f"[Launcher] Starting Pixel ARPG with: {godot_path}")
    cmd = [godot_path, "--path", PROJECT_DIR]
    if args.extra_args:
        cmd.extend(args.extra_args)
    try:
        subprocess.run(cmd)
    except KeyboardInterrupt:
        print("\n[Launcher] Game exited.")

if __name__ == "__main__":
    main()
