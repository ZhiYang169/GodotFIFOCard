class_name HandCardQueue
extends Control

@export var card_scene: PackedScene
@export var SLOT_SIZE:Vector2
@export var GAP_SIZE = Vector2i(20,140)
@export var deal_interval: float = 0.08
@export var fly_duration:float = 0.25
var scale_ration :float
@export var draw_pile :Control
@onready var containter = $HandCardContainter

var cards_ui : Array[Card] = []
var slots :Array[Control] = []
var gaps  :Array[Button]  = []
var insert_index :int = -1
var hand_size_local :int = 0

# 动画用引用
@onready var drag_layer: CanvasLayer = $"../DragLayer"
@onready var active_card_slot: Control = $"../ActiveCardSlot"
@onready var playing_area: Control = $"../PlayingCard"

# 延迟引用 GameManager（与 States 同模式）
var game_manager: GameManager:
	get:
		if not _game_manager:
			_game_manager = get_node_or_null("/root/Game/GameManager") as GameManager
		return _game_manager
var _game_manager: GameManager


func _ready():
	if not draw_pile:
		draw_pile = get_node_or_null("../DrawPile") as Control
	_connect_signals()


# ============================================================
#  飞行动画辅助
# ============================================================

## 创建一个幽灵牌，从 source_pos 飞到 target_pos，到达后自动释放
func _fly_card(card_data: CardData, source_pos: Vector2, target_pos: Vector2, delay: float = 0.0) -> void:
	if not drag_layer:
		return

	var ghost = card_scene.instantiate()
	ghost.data = card_data
	ghost.scale = Vector2(scale_ration, scale_ration)
	ghost.modulate.a = 0.85
	ghost.z_index = 100
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.top_level = true
	ghost.global_position = source_pos
	drag_layer.add_child(ghost)

	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if delay > 0:
		tween.tween_interval(delay)
	tween.tween_property(ghost, "global_position", target_pos, fly_duration)
	tween.tween_callback(ghost.queue_free)


# ============================================================
#  信号连接
# ============================================================

func _connect_signals():
	EventBus.card_drawned.connect(_on_card_drawned)
	EventBus.level_started.connect(_on_level_started)
	EventBus.card_drag_started.connect(_on_drag_started)
	EventBus.card_droped.connect(_on_drag_ended)
	EventBus.update_hand_queue_ui.connect(_on_card_ui_update)
	EventBus.active_card_changed.connect(_on_active_card_changed)
	EventBus.cards_eliminated.connect(_on_cards_eliminated)
	EventBus.cards_filled.connect(_on_cards_filled)


func _disconnect_signals():
	EventBus.card_drawned.disconnect(_on_card_drawned)
	EventBus.level_started.disconnect(_on_level_started)


func _on_level_started(hand_size:int):
	_create_slots(hand_size + 1)


# ============================================================
#  初始发牌（从牌堆飞入）
# ============================================================

func _on_card_drawned(event:CardEvent):
	var handcard_data = event.cards
	for card_data in handcard_data:
		cards_ui.append(_create_card_ui(card_data))
	for i in range(len(slots)):
		slots[i].add_child(cards_ui[i])
		var start_pos = draw_pile.global_position - slots[i].global_position
		cards_ui[i].position = start_pos
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(cards_ui[i], "position", Vector2.ZERO, fly_duration).set_delay(i * deal_interval)
	var total_time = handcard_data.size()*deal_interval+fly_duration
	get_tree().create_timer(total_time).timeout.connect(_on_deal_finished)


func _on_deal_finished() -> void:
	EventBus.deal_animation_finished.emit()


# ============================================================
#  消除动画：匹配牌飞到 PlayingArea → 左牌右移 → 发完成信号
# ============================================================

func _on_cards_eliminated(event: CardEvent) -> void:
	var remove_count = event.cards.size()
	var start_idx = event.start_index_in_handcards
	print("HandCardQueue: eliminate %d cards from index %d" % [remove_count, start_idx])

	var target_pos := Vector2.ZERO
	if playing_area:
		target_pos = playing_area.global_position + playing_area.size / 2

	# 1. 匹配的牌飞到 PlayingArea
	for i in range(remove_count):
		var idx = start_idx + i
		if idx < cards_ui.size() and is_instance_valid(cards_ui[idx]):
			var card_ui = cards_ui[idx]
			var source_pos = card_ui.global_position + card_ui.size * card_ui.scale / 2
			# 创建幽灵飞走
			_fly_card(card_ui.data, source_pos, target_pos, i * 0.06)
			# 原卡淡出
			var tween = create_tween()
			tween.tween_property(card_ui, "modulate:a", 0.0, 0.2)
			tween.tween_callback(card_ui.queue_free)

	# 2. 等待飞行动画
	await get_tree().create_timer(fly_duration + 0.15).timeout

	# 3. 左牌向右移位
	_shift_left_cards_right(start_idx, remove_count)

	# 4. 等待移位动画
	await get_tree().create_timer(fly_duration + 0.05).timeout

	# 5. 通知状态机
	EventBus.elimination_animation_finished.emit()


## 将消除位置左侧的牌向右移动，填空右侧空位
func _shift_left_cards_right(remove_start: int, remove_count: int) -> void:
	var write_idx = remove_start + remove_count - 1
	for read_idx in range(remove_start - 1, -1, -1):
		if not is_instance_valid(cards_ui[read_idx]):
			continue

		if is_instance_valid(slots[read_idx]):
			slots[read_idx].remove_child(cards_ui[read_idx])
		if is_instance_valid(slots[write_idx]):
			slots[write_idx].add_child(cards_ui[read_idx])

		var offset = slots[read_idx].global_position - slots[write_idx].global_position
		cards_ui[read_idx].position = offset
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(cards_ui[read_idx], "position", Vector2.ZERO, fly_duration)

		cards_ui[write_idx] = cards_ui[read_idx]
		cards_ui[read_idx] = null
		write_idx -= 1

	for i in range(remove_count):
		var idx = remove_start + i
		if idx < cards_ui.size():
			cards_ui[idx] = null


# ============================================================
#  补牌动画：新牌从牌堆飞入左侧
# ============================================================

func _on_cards_filled(event: CardEvent) -> void:
	var new_cards = event.cards
	if new_cards.is_empty():
		EventBus.fill_animation_finished.emit()
		return

	print("HandCardQueue: fill %d cards" % new_cards.size())

	_clear_slots()

	var all_cards: Array[CardData] = []
	if game_manager:
		all_cards = game_manager.hand_cards.duplicate()
	else:
		all_cards = new_cards.duplicate()

	_create_slots(all_cards.size())

	var tween_list: Array[Tween] = []
	for i in range(all_cards.size()):
		var card_ui = _create_card_ui(all_cards[i])
		cards_ui.append(card_ui)
		slots[i].add_child(card_ui)

		if i < new_cards.size():
			var target_pos = card_ui.position
			card_ui.position = draw_pile.global_position - slots[i].global_position
			var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(card_ui, "position", target_pos, fly_duration)
			tween_list.append(tween)

	if tween_list.size() > 0:
		tween_list[-1].tween_callback(func(): EventBus.fill_animation_finished.emit())
	else:
		EventBus.fill_animation_finished.emit()


# ============================================================
#  Active Card 变更：弹出的牌飞到 ActiveCardSlot
# ============================================================

func _on_active_card_changed(event:CardEvent):
	var pop_idx = event.start_index_in_handcards

	# ★ 弹出的牌从手牌位置飞到 ActiveCardSlot
	if pop_idx >= 0 and pop_idx < cards_ui.size() and is_instance_valid(cards_ui[pop_idx]):
		var card_ui = cards_ui[pop_idx]
		var source_pos = card_ui.global_position + card_ui.size * card_ui.scale / 2
		var target_pos := Vector2.ZERO
		if active_card_slot:
			target_pos = active_card_slot.global_position + active_card_slot.size / 2
		_fly_card(card_ui.data, source_pos, target_pos, 0.0)

	# 正常移位 + 重建
	var remove_num = 1
	_shift_left_cards_right(pop_idx, remove_num)
	update_handque(event.cards.slice(0, -1))


# ============================================================
#  通用 UI 更新
# ============================================================

func update_handque(cards:Array[CardData]) -> void:
	print("update handcard queue")
	_clear_slots()
	_create_slots(cards.size())
	for card in cards:
		cards_ui.append(_create_card_ui(card))
	for i in range(len(slots)):
		slots[i].add_child(cards_ui[i])


func _create_card_ui(card_data:CardData) -> Card:
	var card_ui = card_scene.instantiate()
	card_ui.data = card_data
	card_ui.scale = Vector2(scale_ration, scale_ration)
	return card_ui


func sync_from_game_manager() -> void:
	if game_manager:
		update_handque(game_manager.hand_cards.duplicate())


# ============================================================
#  Slot / Gap 管理
# ============================================================

func _clear_slots() ->void:
	for i in range(len(slots)):
		if is_instance_valid(slots[i]):
			slots[i].queue_free()
	slots.clear()

	for gap in gaps:
		if is_instance_valid(gap):
			gap.queue_free()
	gaps.clear()

	for card_ui in cards_ui:
		if is_instance_valid(card_ui):
			card_ui.queue_free()
	cards_ui.clear()


func _create_slots(slot_count:int):
	print("create_slot count=%d" % slot_count)
	_clear_slots()
	var tmp_card = card_scene.instantiate()
	scale_ration  = containter.size.y / tmp_card.size.y
	SLOT_SIZE = Vector2i(int(tmp_card.size.x*scale_ration),int(tmp_card.size.y*scale_ration))
	var slot_start_pos = int((containter.size.x-(slot_count+1)*GAP_SIZE.x-slot_count*SLOT_SIZE.x)/2)
	tmp_card.queue_free()

	for i in range(slot_count):
		var slot = create_slot(i, slot_start_pos)
		containter.add_child(slot)
		slots.append(slot)

	for i in range(slot_count+1):
		var gap = create_gap_button(i, slot_start_pos)
		containter.add_child(gap)
		gaps.append(gap)


func create_slot(index:int, start_pos:int) -> Control:
	var slot = Control.new()
	slot.name = "Slot%d" % index
	slot.size = SLOT_SIZE
	slot.position = Vector2i(start_pos + GAP_SIZE.x*(index+1)+SLOT_SIZE.x*index, 0)
	return slot


func create_gap_button(index:int, start_pos:int) -> Button:
	var button = Button.new()
	button.name = "Button%d" % index
	button.position = Vector2i(start_pos + GAP_SIZE.x*(index)+(SLOT_SIZE.x)*index - SLOT_SIZE.x/2, 0)
	button.size = Vector2(GAP_SIZE.x+SLOT_SIZE.x, GAP_SIZE.y)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.mouse_entered.connect(_on_gap_mouse_entered.bind(index))
	button.mouse_exited.connect(_on_gap_mouse_exited)
	button.modulate.a=0
	return button


# ============================================================
#  拖放交互
# ============================================================

func _on_drag_started(card:Card) -> void:
	for gap in gaps:
		gap.mouse_filter = Control.MOUSE_FILTER_PASS


func _on_drag_ended(card: Card, _pos: Vector2) -> void:
	if(insert_index >= 0):
		var active_card_insert_event = CardEvent.new()
		active_card_insert_event.target_index_in_handcards = insert_index
		active_card_insert_event.cards.clear()
		active_card_insert_event.cards.append(card.data)
		EventBus.active_card_inserted.emit(active_card_insert_event)

	for gap in gaps:
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_gap_mouse_entered(index:int):
	_highlight_adjacent_cards(insert_index, false)
	insert_index = index
	_highlight_adjacent_cards(index, true)


func _on_gap_mouse_exited():
	_highlight_adjacent_cards(insert_index, false)
	insert_index = -1


func _highlight_adjacent_cards(gap_index: int, on: bool) -> void:
	if gap_index < 0:
		return
	var left_idx = gap_index - 1
	if left_idx >= 0 and left_idx < cards_ui.size():
		if cards_ui[left_idx] != null:
			cards_ui[left_idx].set_highlight(on)
	var right_idx = gap_index
	if right_idx >= 0 and right_idx < cards_ui.size():
		if cards_ui[right_idx] != null:
			cards_ui[right_idx].set_highlight(on)


func _on_card_ui_update(event:CardEvent):
	update_handque(event.cards)
