class_name GameManager
extends Node


@export var card_manager : CardManager
@export var dbg_hand_cards:bool = true


# signal card_drawned(array:Array[CardData])

# signal play_state_change(new_state,old_state)


var hand_cards : Array[CardData]
var active_card : CardData
var current_lvl: LevelConfig
var current_score : int = 0
var current_level_id :int = 1
var hand_size : int =10
var insert_index : int = -1
var current_matches : Array[Array] = []
var matches_start_index_in_hand_queue : int = -1
var dbg_hands_card_set = [
	{"suit":CardData.Suit.HEARTS  , "rank":"2"},
	{"suit":CardData.Suit.HEARTS  , "rank":"5"},
	{"suit":CardData.Suit.DIAMONDS, "rank":"3"},
	{"suit":CardData.Suit.CLUBS   , "rank":"J"},
	{"suit":CardData.Suit.CLUBS   , "rank":"5"},
	{"suit":CardData.Suit.SPADES  , "rank":"A"},
	{"suit":CardData.Suit.SPADES  , "rank":"K"},
	{"suit":CardData.Suit.HEARTS   , "rank":"J"},
	{"suit":CardData.Suit.DIAMONDS, "rank":"4"},
	{"suit":CardData.Suit.DIAMONDS, "rank":"9"},
	{"suit":CardData.Suit.SPADES  , "rank":"Q"},
]



func _ready() -> void:
	# _connect_signals()
	# card_manager.create_poker_deck()
	pass


func start_level(level_id:int):
	current_lvl = LevelDatabase.get_level(level_id)
	current_score = 0
	hand_size = current_lvl.hand_size
	EventBus.level_started.emit(hand_size)
	hand_cards.clear()
	card_manager.create_poker_deck()
	var drawn_cards : Array[CardData]
	if(dbg_hand_cards):
		drawn_cards = _debug_build_hand_cards()
	else:
		drawn_cards = card_manager.draw_cards(current_lvl.hand_size+1)
	# active_card = drawn_cards.pop_back()
	for i in range(len(drawn_cards)):
		hand_cards.append(drawn_cards.pop_front())
	
	
	# var active_card_changed_event = CardEvent.new()
	# active_card_changed_event.cards.clear()
	# active_card_changed_event.cards.append(active_card)
	# EventBus.active_card_changed.emit(active_card_changed_event)

	var card_drawn_event = CardEvent.new()
	card_drawn_event.cards = hand_cards.duplicate()
	EventBus.card_drawned.emit(card_drawn_event)

	# pop_active_card()

func insert_active_card(index:int,card_data:CardData) -> void:
	hand_cards.insert(index,card_data)
	insert_index = index
	var hand_cards_update_event = CardEvent.new()
	hand_cards_update_event.cards = hand_cards.duplicate()
	EventBus.update_hand_queue_ui.emit(hand_cards_update_event)


func set_current_matches(matches: Array[Array]) -> void:
	current_matches = matches

func get_current_matches() ->Array[Array]:
	return current_matches

func _get_suit_segment() ->bool :
	if insert_index >= hand_cards.size() :
		print("Error!!!!")
		return false
	var suit_segment : Array[CardData] = []
	var suit = hand_cards[insert_index].suit
	suit_segment.append(hand_cards[insert_index])
	matches_start_index_in_hand_queue = insert_index
	var i=insert_index + 1
	#向右搜索是否形成连续同花色，如果有就放入sui_setment
	while(i < hand_cards.size()):
		if(hand_cards[i].suit == suit):
			suit_segment.append(hand_cards[i])
			i=i+1
		else:
			break
	#向左搜索是否形成连续同花色，如果有就放入sui_setment
	i = insert_index -1
	while(i >=0):
		if(hand_cards[i].suit == suit):
			suit_segment.append(hand_cards[i])
			matches_start_index_in_hand_queue = i
			i -= 1
		else:
			break
	print(suit_segment)
	if(suit_segment.size() <3):
		matches_start_index_in_hand_queue = -1
		insert_index = -1
		print("not get matches")
		return false
	else :
		current_matches.append(suit_segment)
		if(matches_start_index_in_hand_queue -1 >=0 ) :
			insert_index = matches_start_index_in_hand_queue -1
		else :
			insert_index =0
		print("get matches")
		return true

func get_last_matches() ->CardEvent:
	var match_info = CardEvent.new()
	if current_matches.is_empty():
		match_info.cards = []
		match_info.start_index_in_handcards =-1
		return match_info

	match_info.cards  = current_matches[-1].duplicate()
	match_info.start_index_in_handcards = matches_start_index_in_hand_queue
	return match_info

func delete_cards_from_hand_queue(remove_num: int, remove_start_pos: int) -> void:
	# 左侧牌向右移填补空位（与 HandCardQueue UI 保持一致）
	# 例: [A, B, C, D, E, F] 删 C,D (remove_start=2, remove_num=2)
	#     → [null, null, A, B, E, F]
	var write_idx = remove_start_pos + remove_num - 1
	for read_idx in range(remove_start_pos - 1, -1, -1):
		hand_cards[write_idx] = hand_cards[read_idx]
		hand_cards[read_idx] = null
		write_idx -= 1
	print("delete %d cards from index %d" % [remove_num, remove_start_pos])

func check_round_end() :
	if(card_manager.get_poker_deck_size() <= 0) :
		if _get_aviable_handqueue_segment() : 
			return true
	else :
		return true 


func _get_aviable_handqueue_segment() :
	var spades_num =0
	var dimonds_num = 0
	var hearts_num = 0
	var clubs_num = 0
	for card in  hand_cards:
		match card.suit:
			CardData.Suit.SPADES: spades_num +=1
			CardData.Suit.HEARTS: hearts_num +=1
			CardData.Suit.CLUBS : clubs_num  +=1
			CardData.Suit.DIAMONDS: dimonds_num+=1

	if (spades_num >=3) or (hearts_num >=3) or (dimonds_num >=3) or (clubs_num >=3) :
		return true
	else:
		return false

func pop_active_card() -> CardEvent:
	active_card = hand_cards[-1].duplicate()
	var active_card_changed_event = CardEvent.new()
	active_card_changed_event.cards.clear()
	active_card_changed_event.cards = hand_cards.duplicate()
	active_card_changed_event.start_index_in_handcards = hand_cards.size() -1
	hand_cards.pop_back()
	return active_card_changed_event


func _debug_build_hand_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	var id: int = 0
	for spec in dbg_hands_card_set :
		cards.append(card_manager.create_poker(spec["suit"],spec["rank"],id))
		id +=1
	return cards
