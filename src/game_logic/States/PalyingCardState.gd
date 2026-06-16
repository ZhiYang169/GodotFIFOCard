class_name PlayingCardState
extends States


func enter() -> void:
	super.enter()
	print("PlayingCardState Enter")

	# 新一轮消除开始，清空 play area
	EventBus.clear_play_area.emit()

	# 循环处理所有匹配（含碰撞连锁），不通过状态机回跳
	while true:
		var match_info = game_manager.get_last_matches()
		if match_info.is_empty():
			print("  no match info — exit chain loop")
			break

		var remove_start = match_info.start_index_in_handcards
		var remove_count = match_info.cards.size()

		# 1. 清洁删除（数组缩短，不留 null）
		game_manager.remove_matched_cards(remove_start, remove_count)

		# 2. 通知 UI 播放牌飞行 + 左牌右移动画
		EventBus.cards_eliminated.emit(match_info)

		# 3. 等待动画播放完毕
		await EventBus.elimination_animation_finished

		# 4. 飞行动画结束后才通知 PlayArea 展示（牌"飞到了"再显示）
		EventBus.get_playing_card.emit(match_info)

		# 5. 在清洁数据上检测碰撞
		var collision = game_manager.find_collision_match(remove_start)
		if collision.is_empty():
			print("  no collision, exit chain loop")
			break

		print("  collision match! chain combo")
		game_manager.set_current_match_from_collision(collision)
		# 循环回到顶部，处理碰撞匹配

	# 所有匹配处理完毕，进入补牌阶段
	print("  all matches resolved, go to FILLING")
	go_to("FILLING")


func exit() -> void:
	super.exit()
