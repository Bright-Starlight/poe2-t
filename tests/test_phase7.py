#!/usr/bin/env python3
"""
Unit and Functional tests for Phase 7:
- Passive skill tree data schema & dependency graph validation
- Atlas Rifts & Boss monster definitions
"""

import os
import json
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class TestPhase7Systems(unittest.TestCase):
    def test_passive_tree_json(self):
        pt_file = os.path.join(PROJECT_ROOT, "data", "talents", "passive_tree.json")
        self.assertTrue(os.path.isfile(pt_file), "passive_tree.json must exist")
        
        with open(pt_file, "r", encoding="utf-8") as f:
            tree = json.load(f)
        
        expected_branches = ["physical", "elemental", "crit_speed", "defense", "magic_find"]
        all_node_ids = set()
        
        for b in expected_branches:
            self.assertIn(b, tree, f"Missing branch {b}")
            self.assertIn("name_cn", tree[b])
            nodes = tree[b].get("nodes", [])
            self.assertGreater(len(nodes), 0, f"Branch {b} should have nodes")
            
            for n in nodes:
                nid = n.get("id")
                self.assertNotIn(nid, all_node_ids, f"Duplicate node ID: {nid}")
                all_node_ids.add(nid)
                self.assertIn("name_cn", n)
                self.assertIn("desc", n)
                self.assertIn("modifiers", n)
        
        # Verify all requirements point to existing nodes
        for b in expected_branches:
            for n in tree[b]["nodes"]:
                for req in n.get("req", []):
                    self.assertIn(req, all_node_ids, f"Node {n['id']} requires non-existent node {req}")

    def test_rifts_and_bosses(self):
        rifts_file = os.path.join(PROJECT_ROOT, "data", "maps", "rifts.json")
        monsters_file = os.path.join(PROJECT_ROOT, "data", "monsters", "monsters.json")
        
        self.assertTrue(os.path.isfile(rifts_file))
        self.assertTrue(os.path.isfile(monsters_file))
        
        with open(rifts_file, "r", encoding="utf-8") as f:
            rifts = json.load(f)
        with open(monsters_file, "r", encoding="utf-8") as f:
            monsters = json.load(f)
        
        for rid, rdata in rifts.items():
            self.assertIn("boss_id", rdata)
            boss_id = rdata["boss_id"]
            self.assertIn(boss_id, monsters, f"Rift {rid} references non-existent boss {boss_id}")
            self.assertTrue(monsters[boss_id].get("is_boss", False), f"Monster {boss_id} must have is_boss=true")

if __name__ == "__main__":
    unittest.main()
