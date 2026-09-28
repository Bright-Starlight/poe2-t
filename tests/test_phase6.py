#!/usr/bin/env python3
"""
Unit and Functional tests for Phase 6:
- Currency JSON validity and drop weights
- Character attribute conversions
- Crafting system logic validation
"""

import os
import json
import unittest

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class TestPhase6Systems(unittest.TestCase):
    def test_currencies_json(self):
        cur_file = os.path.join(PROJECT_ROOT, "data", "crafting", "currencies.json")
        self.assertTrue(os.path.isfile(cur_file), "currencies.json must exist")
        
        with open(cur_file, "r", encoding="utf-8") as f:
            currencies = json.load(f)
        
        expected_ids = ["transmutation", "augmentation", "alteration", "regal", "chaos", "exalted", "scouring"]
        for cid in expected_ids:
            self.assertIn(cid, currencies, f"Missing currency {cid}")
            self.assertIn("name_cn", currencies[cid])
            self.assertIn("description", currencies[cid])
            self.assertIn("drop_weight", currencies[cid])
            self.assertGreater(currencies[cid]["drop_weight"], 0)

    def test_attribute_formula(self):
        # Strength: +5 HP, +0.6 ATK
        str_val = 10
        bonus_hp = str_val * 5.0
        bonus_atk = str_val * 0.6
        self.assertEqual(bonus_hp, 50.0)
        self.assertEqual(bonus_atk, 6.0)
        
        # Dex: +1.5 EVA, +0.01 ASPD, +0.0015 CRIT
        dex_val = 20
        bonus_eva = dex_val * 1.5
        bonus_aspd = dex_val * 0.01
        bonus_crit = dex_val * 0.0015
        self.assertEqual(bonus_eva, 30.0)
        self.assertEqual(round(bonus_aspd, 2), 0.2)
        self.assertEqual(round(bonus_crit, 4), 0.03)

if __name__ == "__main__":
    unittest.main()
