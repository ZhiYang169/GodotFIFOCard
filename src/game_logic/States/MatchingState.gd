class_name MatchingState
extends States


func enter() -> void:
	super.enter()
	print("MatchingState Enter")

	var success = game_manager._get_suit_segment()
	if success:
		go_to("PLAYING")
	else:
		go_to("POP_CARD")
