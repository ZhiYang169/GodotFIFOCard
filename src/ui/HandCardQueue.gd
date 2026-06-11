class_name HandCardQueue
extends Control

@export var card_scene: PackedScene  
# @export var card_manager: CardManager
# @export var game_manager: GameManager
@export var SLOT_SIZE:Vector2 
@export var GAP_SIZE = Vector2i(20,140)
@export var deal_interval: float = 0.08
@export var fly_duration:float = 0.25
var scale_ration :float
@export var draw_pile :Control
@onready var containter = $HandCardContainter

# var _cards_data : Array[CardData] = []
var cards_ui : Array[Card] = []
var slots :Array[Control] = []
var gaps  :Array[Button]  = []
var insert_index :int = -1
var hand_size_local :int = 0 
# signal card_drawned(handcard_data:Array[CardData])

func _ready():
	# _create_slots(15)
	_connect_signals()
	
func _clear_slots() ->void:
	for i in range(len(slots)):
		if is_instance_valid(slots[i]):
			slots[i].remove_child(cards_ui[i])
			slots[i].queue_free()
	slots.clear()

	for gap in gaps:
		if is_instance_valid(gap):
			gap.queue_free()
	gaps.clear()

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
	for i in range(slot_count+1):
		var gap = create_gap_button(i,slot_start_pos)
		containter.add_child(gap)
		gaps.append(gap)


func create_slot(index:int,start_pos:int) -> Control:
	var slot = Control.new()
	slot.name = "Slot%d" %index
	slot.size = SLOT_SIZE
	slot.position = Vector2i(start_pos + GAP_SIZE.x*(index+1)+SLOT_SIZE.x*index,0)
	return slot

func create_gap_button(index:int,start_pos:int) -> Button:
	var button = Button.new()
	button.name = "Button%d" %index
	button.position = Vector2i(start_pos + GAP_SIZE.x*(index)+(SLOT_SIZE.x)*index - SLOT_SIZE.x/2,0)
	button.size = Vector2(GAP_SIZE.x+SLOT_SIZE.x ,GAP_SIZE.y)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.mouse_entered.connect(_on_gap_mouse_entered.bind(index))
	button.mouse_exited.connect(_on_gap_mouse_exited)
	button.modulate.a=0
	return button
# func create_collsion_shape_slot(index:int,start_pos:int) -> CollisionShape2D:
	# var cs = CollisionShape2D.new()
	# cs.name = "Collision%d" %index
	# slot.size = GAP_SIZE+



func _connect_signals():
		EventBus.card_drawned.connect(_on_card_drawned)
		EventBus.level_started.connect(_on_level_started)
		EventBus.card_drag_started.connect(_on_drag_started)
		EventBus.card_droped.connect(_on_drag_ended)
		EventBus.get_playing_card.connect(_on_playing_card_get)
		EventBus.update_hand_queue_ui.connect(_on_card_ui_update)
		EventBus.active_card_changed.connect(_on_active_card_changed)

func _disconnect_signals():
		EventBus.card_drawned.disconnect(_on_card_drawned)
		EventBus.level_started.disconnect(_on_level_started)
		# EventBus.get_playing_card.disconnect(_on_playing_card_get)

func _on_level_started(hand_size:int):
	_create_slots(hand_size+1)
	# hand_size_local = hand_size
	
func _on_card_drawned(event:CardEvent):
	var handcard_data = event.cards

	for card_data in handcard_data:
		# _cards_data.append(card_data)
		cards_ui.append(_create_card_ui(card_data))
	for i in range(len(slots)):
		slots[i].add_child(cards_ui[i])
		var start_pos = draw_pile.global_position - slots[i].global_position
		cards_ui[i].position = start_pos
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(cards_ui[i], "position", Vector2.ZERO, fly_duration).set_delay(i * deal_interval)
	var total_time= handcard_data.size()*deal_interval+fly_duration
	get_tree().create_timer(total_time).timeout.connect(_on_deal_finished)
	# _disconnect_signals()
			
func update_handque(cards:Array[CardData]) ->void :
	print("update handcard queue")
	_clear_slots()
	for card_ui in cards_ui :
		if(card_ui != null):
			card_ui.queue_free()
	cards_ui.clear()
	_create_slots(cards.size())
	for card in cards : 
		cards_ui.append(_create_card_ui(card))
	for i in range(len(slots)):
		slots[i].add_child(cards_ui[i])


func _remove_cards_and_shift_hand_card_queue(remove_num,remove_start_pos:int) ->void :
	print("remove number = %d"%remove_num)
	for i in range(remove_num):
		slots[i+remove_start_pos].remove_child(cards_ui[i+remove_start_pos])
		cards_ui[i+remove_start_pos].queue_free()
		cards_ui[i+remove_start_pos] = null
	var write_idx = remove_start_pos + remove_num -1
	for read_idx in range(remove_start_pos -1,-1,-1):
		slots[read_idx].remove_child(cards_ui[read_idx])
		slots[write_idx].add_child(cards_ui[read_idx])
	
		var offset = slots[read_idx].global_position - slots[write_idx].global_position

		cards_ui[read_idx].position = offset
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(cards_ui[read_idx],"position",Vector2.ZERO,fly_duration)
		cards_ui[write_idx] = cards_ui[read_idx]
		cards_ui[read_idx ] = null
		write_idx -=1

#func _shift_cards()

func _create_card_ui(card_data:CardData) ->Card:
	var card_ui = card_scene.instantiate()
	card_ui.data = card_data
	card_ui.scale = Vector2(scale_ration,scale_ration)
	return card_ui

func _on_deal_finished()->void :
	EventBus.deal_animation_finished.emit(cards_ui)

# func update_handQueue_ui(_cards_data:Array[CardData]):
	# for data in _cards_data:
		# _create_card_ui(data)
func _on_drag_started(card:Card) ->void:
	for gap in gaps:
		gap.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_drag_ended(card: Card, _pos: Vector2) ->void:
	if(insert_index >= 0 ):
		# _create_slots(hand_size_local+1)
		# _add_cards_to_hand_card_queue([card],insert_index)
		var active_card_insert_event = CardEvent.new()
		active_card_insert_event.target_index_in_handcards = insert_index
		active_card_insert_event.cards.clear()
		active_card_insert_event.cards.append(card.data)
		EventBus.active_card_inserted.emit(active_card_insert_event)
		
	for gap in gaps:
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_gap_mouse_entered(index:int):
	print("enter gap %d" %index)
	#TODO activecard
	insert_index = index
	

func _on_gap_mouse_exited():
	insert_index = -1;

func _on_active_card_changed(event:CardEvent):
	var remove_num = event.cards.size()
	var remove_start_pos = event.start_index_in_handcards
	_remove_cards_and_shift_hand_card_queue(remove_num,remove_start_pos)

func _on_playing_card_get(event:CardEvent):
	var remove_num = event.cards.size()
	var remove_start_pos = event.start_index_in_handcards
	_remove_cards_and_shift_hand_card_queue(remove_num,remove_start_pos)

func _on_card_ui_update(event:CardEvent):
	update_handque(event.cards)
