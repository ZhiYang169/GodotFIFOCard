class_name SetupState
extends States

func enter() ->void:
	super.enter()
	print("SetupState Enter")
	game_manager.start_level(game_manager.current_level_id)
	await EventBus.deal_animation_finished
	await get_tree().process_frame
	print("goto pop_card")
	go_to("POP_CARD")


	# Called every time the node is added to the scene.
	# Initialization here
