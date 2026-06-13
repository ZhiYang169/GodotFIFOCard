class_name PlayingCardState
extends States


func enter() ->void:
	super.enter()
	var match_info = game_manager.get_last_matches()
	print("got same suit")
	EventBus.get_playing_card.emit(match_info)
	game_manager.delete_cards_from_hand_queue(match_info.cards.size(), match_info.start_index_in_handcards)
	go_to("FILLING_CARD")

	# else:
		# go_to("PopActiveCard")
