class_name PlayingCard
extends Control

@export var card_scene: PackedScene

@export var SLOT_SIZE: Vector2
@export var GAP_SIZE = Vector2i(20, 140)
var scale_ration: float
@onready var containter = $PlayingCardContainter

var cards_ui: Array[Card] = []
var slots: Array[Control] = []


func _ready() -> void:
	_connect_signals()


func _init_scale() -> void:
	if scale_ration > 0:
		return
	var tmp_card = card_scene.instantiate()
	scale_ration = containter.size.y / tmp_card.size.y
	SLOT_SIZE = Vector2i(int(tmp_card.size.x * scale_ration), int(tmp_card.size.y * scale_ration))
	tmp_card.queue_free()


func _clear_all() -> void:
	# 先把 card_ui 从 slot 里拆出来，防止 queue_free slot 时连带释放
	for card_ui in cards_ui:
		if is_instance_valid(card_ui) and card_ui.get_parent():
			card_ui.get_parent().remove_child(card_ui)
	# 安全清 slot
	for slot in slots:
		if is_instance_valid(slot):
			slot.queue_free()
	slots.clear()
	# 再清 card_ui
	for card_ui in cards_ui:
		if is_instance_valid(card_ui):
			card_ui.queue_free()
	cards_ui.clear()


func _slot_start_pos(slot_count: int) -> int:
	return int((containter.size.x - (slot_count + 1) * GAP_SIZE.x - slot_count * SLOT_SIZE.x) / 2)


func _append_to_play_area(new_count: int) -> void:
	"""只追加新 card 的 slot，不 detach 已有的 card_ui"""
	# 创���新 slot 给刚追加的牌
	for i in range(cards_ui.size() - new_count, cards_ui.size()):
		var slot = Control.new()
		slot.name = "PlaySlot%d" % i
		slot.size = SLOT_SIZE
		containter.add_child(slot)
		slots.append(slot)

	# 把新 card_ui 放入新 slot
	for i in range(cards_ui.size() - new_count, cards_ui.size()):
		if is_instance_valid(slots[i]) and is_instance_valid(cards_ui[i]):
			slots[i].add_child(cards_ui[i])

	# 所有 slot 重新居中（只调位置，不拆子节点）
	var total = cards_ui.size()
	var start_pos = _slot_start_pos(total)
	for i in range(total):
		if is_instance_valid(slots[i]):
			slots[i].position = Vector2i(start_pos + GAP_SIZE.x * (i + 1) + SLOT_SIZE.x * i, 0)


func _create_card_ui(card_data: CardData) -> Card:
	var card_ui = card_scene.instantiate()
	card_ui.data = card_data
	card_ui.scale = Vector2(scale_ration, scale_ration)
	return card_ui


func _connect_signals():
	EventBus.get_playing_card.connect(_on_playing_card_get)
	EventBus.clear_play_area.connect(reset_play_area)


func _on_playing_card_get(event: CardEvent):
	print("playing area get %d cards (total now: %d)" % [event.cards.size(), cards_ui.size() + event.cards.size()])
	_init_scale()

	# ★ 累积追加，不清空已有的
	for card_data in event.cards:
		cards_ui.append(_create_card_ui(card_data))

	# 追加新 slot（不拆旧 card_ui），然后全部 slot 重新居中
	_append_to_play_area(event.cards.size())


func reset_play_area() -> void:
	"""新一轮开始时清空（由状态机在 SETUP 时调用）"""
	_clear_all()
