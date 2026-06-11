class_name IdleState
extends States


func enter() ->void:
	super.enter()
	print("Idle State Enter")
	EventBus.active_card_inserted.connect(_on_active_card_instered)

func exit() ->void :
	EventBus.active_card_inserted.disconnect(_on_active_card_instered)
	super.exit()

func _on_active_card_instered(event:CardEvent) ->void:
	var index = event.target_index_in_handcards
	var card_data = event.cards[-1]
	game_manager.insert_active_card(index,card_data)
	go_to("MATCHING")	
