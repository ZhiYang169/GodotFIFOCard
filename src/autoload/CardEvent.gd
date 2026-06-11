class_name CardEvent
extends RefCounted

var cards: Array[CardData] = []
var start_index_in_handcards: int = -1
var end_index_in_handcards: int = -1
var target_index_in_handcards: int = -1
var operation: String = ""

func is_empty() -> bool:
    return cards.is_empty()

func count() -> int :
    return cards.size()