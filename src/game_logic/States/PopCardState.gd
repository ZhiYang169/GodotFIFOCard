class_name PopCardState
extends States


func enter() ->void:
	super.enter()
	var active_card_changed_event = game_manager.pop_active_card()
	EventBus.active_card_changed.emit(active_card_changed_event)
	go_to("IDLE")
	# else:
		# go_to("PopActiveCard")
