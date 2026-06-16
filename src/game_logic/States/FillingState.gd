class_name FillingState
extends States


func enter() -> void:
	super.enter()
	print("FillingState Enter")

	# 补到 hand_size + 1（因为后面 POP_CARD 会弹走一张当激活牌）
	var cards_needed = (game_manager.hand_size + 1) - game_manager.hand_cards.size()
	if cards_needed <= 0:
		print("  no cards needed, goto POP_CARD")
		go_to("POP_CARD")
		return

	# 1. 从牌堆抽牌，插入 hand_cards 左侧
	var drawn = game_manager.draw_cards_to_front(cards_needed)

	if drawn.is_empty():
		print("  deck is empty, no cards drawn")
		# 死局判定
		if not game_manager.check_round_end():
			print("  GAME OVER")
			go_to("POP_CARD")   # TODO: 改为 GAME_OVER 状态
		else:
			go_to("POP_CARD")
		return

	# 2. 通知 UI 播放补牌动画
	var fill_event = CardEvent.new()
	fill_event.cards = drawn.duplicate()
	EventBus.cards_filled.emit(fill_event)

	# 3. 等待动画播放完毕
	await EventBus.fill_animation_finished

	# 4. 补牌边界碰撞检测
	#    drawn_count 张牌插入在 index 0..drawn_count-1
	#    检查 drawn_count-1 和 drawn_count 之间
	var collision = game_manager.find_collision_match(cards_needed)
	if not collision.is_empty():
		print("  fill collision match!")
		game_manager.set_current_match_from_collision(collision)
		go_to("PLAYING")
	else:
		print("  no fill collision, goto POP_CARD to end round")
		go_to("POP_CARD")


func exit() -> void:
	super.exit()
