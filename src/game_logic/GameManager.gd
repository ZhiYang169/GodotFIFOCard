class_name GameManager
extends Node


@export var card_manager : CardManager
@export var dbg_hand_cards:bool = true


var hand_cards : Array[CardData] = []
var active_card : CardData = null
var current_lvl: LevelConfig
var current_score : int = 0
var current_level_id :int = 1
var hand_size : int = 10
var insert_index : int = -1
var current_match : Array[CardData] = []
var _current_segment_start : int = -1


var dbg_hands_card_set = [
	{"suit":CardData.Suit.HEARTS  , "rank":"2"},
	{"suit":CardData.Suit.HEARTS  , "rank":"5"},
	{"suit":CardData.Suit.DIAMONDS, "rank":"3"},
	{"suit":CardData.Suit.CLUBS   , "rank":"J"},
	{"suit":CardData.Suit.CLUBS   , "rank":"5"},
	{"suit":CardData.Suit.SPADES  , "rank":"A"},
	{"suit":CardData.Suit.SPADES  , "rank":"K"},
	{"suit":CardData.Suit.CLUBS   , "rank":"3"},
	{"suit":CardData.Suit.DIAMONDS, "rank":"4"},
	{"suit":CardData.Suit.DIAMONDS, "rank":"9"},
	{"suit":CardData.Suit.SPADES  , "rank":"Q"},
]


func _ready() -> void:
	if not card_manager:
		card_manager = get_node_or_null("../CardManager") as CardManager
	if not card_manager:
		push_error("GameManager: CardManager not found!")


func start_level(level_id:int):
	current_lvl = LevelDatabase.get_level(level_id)
	current_score = 0
	hand_size = current_lvl.hand_size
	EventBus.level_started.emit(hand_size)
	hand_cards.clear()
	current_match.clear()
	_current_segment_start = -1
	insert_index = -1
	card_manager.create_poker_deck()

	if(dbg_hand_cards):
		var debug_cards = _debug_build_hand_cards()
		for c in debug_cards:
			hand_cards.append(c)
	else:
		var drawn_cards = card_manager.draw_cards(current_lvl.hand_size + 1)
		# Fix: use while loop since pop_front() shrinks the array
		while not drawn_cards.is_empty():
			hand_cards.append(drawn_cards.pop_front())

	var card_drawn_event = CardEvent.new()
	card_drawn_event.cards = hand_cards.duplicate()
	EventBus.card_drawned.emit(card_drawn_event)


func insert_active_card(index:int, card_data:CardData) -> void:
	hand_cards.insert(index, card_data)
	insert_index = index
	var hand_cards_update_event = CardEvent.new()
	hand_cards_update_event.cards = hand_cards.duplicate()
	EventBus.update_hand_queue_ui.emit(hand_cards_update_event)


# ============================================================
#  清洁数据操作 —— 不留 null 占位符
# ============================================================

## 从 hand_cards 中真正删除匹配的牌（数组缩短）
func remove_matched_cards(start_index: int, count: int) -> Array[CardData]:
	var removed: Array[CardData] = []
	var actual = min(count, hand_cards.size() - start_index)
	for _i in range(actual):
		removed.append(hand_cards[start_index])
		hand_cards.remove_at(start_index)
	return removed


## 从左侧补牌（牌堆抽牌，插入 hand_cards 前方）
func draw_cards_to_front(count: int) -> Array[CardData]:
	var drawn = card_manager.draw_cards(count)
	for i in range(drawn.size()):
		hand_cards.insert(i, drawn[i])
	return drawn


# ============================================================
#  同花色连续段检测（纯算法，无副作用）
# ============================================================

## 从 index 向两侧扩展，找到完整同花色连续段
## 返回匹配的 CardData 数组；不足 3 张返回空
## 内部记录段起始位置到 _current_segment_start
func _find_suit_segment_at(index: int) -> Array[CardData]:
	_current_segment_start = -1
	if index < 0 or index >= hand_cards.size():
		return []

	var suit = hand_cards[index].suit
	var start = index
	var end = index

	while start > 0 and hand_cards[start - 1].suit == suit:
		start -= 1
	while end < hand_cards.size() - 1 and hand_cards[end + 1].suit == suit:
		end += 1

	var seg_len = end - start + 1
	if seg_len < 3:
		return []

	_current_segment_start = start
	var segment: Array[CardData] = []
	for i in range(start, end + 1):
		segment.append(hand_cards[i])
	return segment


## 在 clean 数组上检测碰撞匹配
## removal_start = 刚删除的起始位置
## 删除后，removal_start-1 和 removal_start 位置的牌新相邻
func find_collision_match(removal_start: int) -> Array[CardData]:
	if removal_start <= 0 or removal_start >= hand_cards.size():
		return []

	var left_card = hand_cards[removal_start - 1]
	var right_card = hand_cards[removal_start]

	if left_card.suit != right_card.suit:
		return []

	# 同花色！从 left_card 位置展开找完整段
	return _find_suit_segment_at(removal_start - 1)


## 供 MatchingState 使用：在 insert_index 处检测匹配
func find_match_at_insert_pos() -> bool:
	if insert_index < 0 or insert_index >= hand_cards.size():
		return false
	current_match = _find_suit_segment_at(insert_index)
	insert_index = -1  # 消费掉
	return not current_match.is_empty()


# 兼容旧接口：IdleState → MatchingState 调用
func _get_suit_segment() -> bool:
	return find_match_at_insert_pos()


# ============================================================
#  查询接口
# ============================================================

func get_last_matches() -> CardEvent:
	var match_info = CardEvent.new()
	if current_match.is_empty():
		match_info.cards = []
		match_info.start_index_in_handcards = -1
		return match_info
	match_info.cards = current_match.duplicate()
	match_info.start_index_in_handcards = _current_segment_start
	return match_info


func set_current_match_from_collision(segment: Array[CardData]) -> void:
	current_match = segment
	# _current_segment_start 已由 _find_suit_segment_at 设置


func get_poker_deck_size() -> int:
	return card_manager.get_poker_deck_size()


# ============================================================
#  回合结束 / 死局判定
# ============================================================

func check_round_end() -> bool:
	if card_manager.get_poker_deck_size() <= 0:
		if _get_aviable_handqueue_segment():
			return true
		else:
			return false
	else:
		return true


func _get_aviable_handqueue_segment() -> bool:
	var spades_num = 0
	var dimonds_num = 0
	var hearts_num = 0
	var clubs_num = 0
	for card in hand_cards:
		if card == null:
			continue
		match card.suit:
			CardData.Suit.SPADES:  spades_num  += 1
			CardData.Suit.HEARTS:  hearts_num  += 1
			CardData.Suit.CLUBS:   clubs_num   += 1
			CardData.Suit.DIAMONDS: dimonds_num += 1

	if (spades_num >= 3) or (hearts_num >= 3) or (dimonds_num >= 3) or (clubs_num >= 3):
		return true
	else:
		return false


# ============================================================
#  Active Card 操作
# ============================================================

func pop_active_card() -> CardEvent:
	if hand_cards.is_empty():
		var empty_event = CardEvent.new()
		empty_event.cards = []
		return empty_event

	active_card = hand_cards[-1].duplicate()
	var active_card_changed_event = CardEvent.new()
	active_card_changed_event.cards = hand_cards.duplicate()
	active_card_changed_event.start_index_in_handcards = hand_cards.size() - 1
	hand_cards.pop_back()
	return active_card_changed_event


# ============================================================
#  Debug
# ============================================================

func _debug_build_hand_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	var id: int = 0
	for spec in dbg_hands_card_set:
		cards.append(card_manager.create_poker(spec["suit"], spec["rank"], id))
		id += 1
	return cards
