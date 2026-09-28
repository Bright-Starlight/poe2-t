extends Node

## EventBus: 全局事件总线，用于跨系统、跨场景解耦通信
## 避免节点间直接产生强耦合依赖

# 游戏状态信号
signal game_started
signal game_paused(is_paused: bool)

# 玩家状态信号
signal player_spawned(player_node: Node2D)
signal player_health_changed(current_hp: float, max_hp: float)
signal player_mana_changed(current_mp: float, max_mp: float)
signal player_exp_changed(current_exp: int, max_exp: int, level: int)
signal player_gold_changed(current_gold: int)
signal player_stats_changed(stats: Dictionary)
signal player_died

# 怪物与战斗信号
signal monster_spawned(monster_node: Node2D)
signal monster_died(monster_node: Node2D, reward_info: Dictionary)
signal combat_damage_dealt(damage_info: Dictionary)

# 掉落与背包信号
signal item_dropped(item_data: Dictionary, spawn_position: Vector2)
signal item_picked_up(item_data: Dictionary)
signal inventory_changed
signal equipment_changed

# 系统与操作信号
signal auto_combat_toggled(is_enabled: bool)
signal ui_window_toggled(window_name: String, is_open: bool)
signal debug_log_emitted(message: String)
