class_name CardData
extends Resource

enum Suit {SPADES,HEARTS,CLUBS,DIAMONDS,NONE}
enum Type {NORMAL}

@export var id:int
@export var suit:Suit
@export var rank:String
@export var type:Type


func get_value() ->int:
	match rank:
		"A": return 11
		"J","Q","K": return 10
		_: return int(rank)
