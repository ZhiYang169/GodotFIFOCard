extends Node

# =====UI——>逻辑层========
signal card_slot_clicked(slot_index: int)
signal active_card_played()                    # 点击打出 active card
signal item_used(item_slot: int, target_index: int)
signal shop_item_purchased(item_id: String)
signal next_level_requested()
signal restart_requested()
signal return_to_menu_requested()
signal card_selected(card:Card)
signal update_hand_queue_ui(event:CardEvent)

signal card_drag_started(card:Card)

# =====逻辑层->UI =========
signal card_drawned(event:CardEvent)
signal active_card_changed(event:CardEvent)
signal level_started(hand_size: int)
signal active_card_inserted(event:CardEvent)
signal get_playing_card(event:CardEvent)

# ====逻辑层内信号 ========
signal poker_deck_shuffled()
signal poker_deck_is_empty()
signal deal_animation_finished()

# ====UI <----> UI =========
signal card_droped(card:Card,pos:Vector2)

# ====动画时序信号 (UI → 状态机) ====
signal elimination_animation_finished()   # 消除动画播放完毕
signal fill_animation_finished()          # 补牌动画播放完毕

# ====消除/补牌事件 (状态机 → UI) ====
signal clear_play_area()                     # 新一轮消除开始前清空 play area
signal cards_eliminated(event: CardEvent)  # 通知 UI 播放消除动画
signal cards_filled(event: CardEvent)      # 通知 UI 播放补牌动画
