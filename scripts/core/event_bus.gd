extends Node
## 全局信号总线

signal money_changed(amount: int)
signal rep_changed(rep: int, star: int)
signal time_changed(day: int, period: int)
signal speed_changed(speed: int)
signal building_placed(index: int)
signal building_removed(index: int)
signal region_changed(count: int)
signal payout(cell: Vector2, amount: int)
signal notice(text: String)
signal board_changed
signal boss_changed
signal star_up(star: int, title: String)
signal return_to_menu
signal intro_boss(boss_name: String, hours: int, power: int)
signal news_paper(title: String, body: String)
signal cycle_ready
signal goal_changed
signal achievement_unlocked(id: String, title: String, desc: String, money: int, rep: int)
