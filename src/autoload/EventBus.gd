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
