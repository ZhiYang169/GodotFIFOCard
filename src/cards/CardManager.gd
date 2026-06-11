class_name CardManager
extends Node

const SUITS = [CardData.Suit.SPADES, CardData.Suit.HEARTS,
			   CardData.Suit.DIAMONDS, CardData.Suit.CLUBS]

const RANKS = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]

var poker_deck :Array[CardData] = []
var item_deck  :Array[CardData] = []
var _id_counter:int



func create_poker(suit: CardData.Suit, rank: String, id: int) -> CardData:
	var poker = CardData.new()
	poker.suit = suit
	poker.rank = rank
	poker.type = CardData.Type.NORMAL
	poker.id = id
	return poker
	


func create_poker_deck() -> void:
	poker_deck.clear()
	_id_counter = 0

	for suit in SUITS:
		for rank in RANKS:
			var poker_card = CardData.new()
			poker_card.suit = suit
			poker_card.rank = rank
			poker_card.id = _id_counter
			poker_card.type = CardData.Type.NORMAL
			poker_deck.append(poker_card)
			_id_counter += 1

	shuffle_deck()

func delete_card_from_poker_deck(card:CardData)->void:
	if(poker_deck.is_empty()):
		EventBus.poker_deck_is_empty.emit()
	poker_deck.erase(card)

func add_card_to_poker_deck(card:CardData)->void:
	poker_deck.append(card)
	

func shuffle_deck()->void:
	for i in range(3):
		_shuffle_deck(poker_deck)
	EventBus.poker_deck_shuffled.emit()
	

func _shuffle_deck(arr:Array) ->void:
	var n = arr.size()
	for i in range (n-1,0,-1):
		var j = randi()%(i+1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func draw_cards(count:int) -> Array[CardData]:
	var drawn_cards:Array[CardData] = []
	for i in range(0,count):
		if(poker_deck.is_empty()):
			EventBus.poker_deck_is_empty.emit()
			return[]
		drawn_cards.append(poker_deck.pop_back())
	return drawn_cards

func get_poker_deck_size() -> int :
	return poker_deck.size()
