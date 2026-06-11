class_name PlayingCard
extends  Control

@export var card_scene: PackedScene  

@export var SLOT_SIZE:Vector2
@export var GAP_SIZE = Vector2i(20,140)
@export var deal_interval : float = 0.08
@export var fly_duration  : float = 0.25
var scale_ration :float
@onready var containter = $PlayingCardContainter


var  cards_ui : Array[Card] = []
var  slots : Array[Control] = []

func _ready() -> void:
	_connect_signals()

func _clear_slots() ->void:
	for i in range(len(slots)):
		if is_instance_valid(slots[i]):
			slots[i].remove_child(cards_ui[i])
			slots[i].queue_free()
	slots.clear()


func _create_slots(slot_count:int):
	print("create_slot")
	_clear_slots()
	var tmp_card = card_scene.instantiate()
	scale_ration  = containter.size.y / tmp_card.size.y
	SLOT_SIZE = Vector2i(int(tmp_card.size.x*scale_ration),int(tmp_card.size.y*scale_ration))
	var slot_start_pos = int((containter.size.x-(slot_count+1)*GAP_SIZE.x-slot_count*SLOT_SIZE.x)/2)
	tmp_card.queue_free()
	for i in range(slot_count):
		var slot = create_slot(i,slot_start_pos)
		containter.add_child(slot)
		slots.append(slot)

func create_slot(index:int,start_pos:int) -> Control:
	var slot = Control.new()
	slot.name = "Slot%d" %index
	slot.size = SLOT_SIZE
	slot.position = Vector2i(start_pos + GAP_SIZE.x*(index+1)+SLOT_SIZE.x*index,0)
	return slot

func _create_card_ui(card_data:CardData) ->Card:
	var card_ui = card_scene.instantiate()
	card_ui.data = card_data
	card_ui.scale = Vector2(scale_ration,scale_ration)
	return card_ui


func update_play_area(cards:Array[CardData]) ->void :
	print("update play area")
	_clear_slots()
	for card_ui in cards_ui :
		card_ui.queue_free()
	cards_ui.clear()
	_create_slots(cards.size())
	for card in cards : 
		cards_ui.append(_create_card_ui(card))
	for i in range(len(slots)):
		slots[i].add_child(cards_ui[i])

func _connect_signals():
	EventBus.get_playing_card.connect(_on_playing_card_get)	

func _on_playing_card_get(event:CardEvent):
	print("playing area get cards")
	update_play_area(event.cards)
	#EventBus.get_playing_card.connect(_on_playing_card_get)
# 
# 
# 
	# update_play_area(event.cards)
