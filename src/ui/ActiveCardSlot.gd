class_name ActiveCardSlot
extends Control


@export var card_scene: PackedScene
@export var SLOT_SIZE:Vector2
@onready var drag_layer : CanvasLayer = $"../DragLayer"
var scale_ration : float
var _drag_ghost
var active_card : Card = null

func _ready():
	_initial_active_card_slot()
	_connect_signals()


func _initial_active_card_slot():
	print("initial card slot")
	var tmp_card = card_scene.instantiate()
	scale_ration = self.size.y/tmp_card.size.y
	SLOT_SIZE = Vector2i(int(tmp_card.size.x*scale_ration),int(tmp_card.size.y*scale_ration))
	self.size = SLOT_SIZE
	tmp_card.queue_free()


func _on_drag_started(card: Card) -> void:
	print("=== drag started ===")
	print("card is null? ", card == null)
	print("card parent: ", card.get_parent())
	if card.get_parent() != self:
		return
	print("drag_started")
	_drag_ghost = card_scene.instantiate()
	_drag_ghost.data = card.data
	_drag_ghost.scale = card.scale
	_drag_ghost.modulate.a = 1
	_drag_ghost.z_index = 100
	_drag_ghost.top_level = true
	_drag_ghost.mouse_filter= Control.MOUSE_FILTER_IGNORE
	_set_mouse_filter_recursive(_drag_ghost, Control.MOUSE_FILTER_IGNORE)
	drag_layer.add_child(_drag_ghost)
	_drag_ghost.global_position = card.global_position
	if active_card:
		active_card.modulate.a = 0

func _set_mouse_filter_recursive(node: Node, filter: Control.MouseFilter) -> void:
	if node is Control:
		node.mouse_filter = filter
	for child in node.get_children():
		_set_mouse_filter_recursive(child, filter)

func _connect_signals():
	EventBus.active_card_changed.connect(_on_active_card_changed)
	EventBus.card_drag_started.connect(_on_drag_started)
	EventBus.card_droped.connect(_on_drag_ended)
	EventBus.active_card_inserted.connect(_on_active_card_inserted)

func _disconnect_signals():
	EventBus.active_card_changed.disconnect(_on_active_card_changed)
	EventBus.card_drag_started.disconnect(_on_drag_started)
	EventBus.card_droped.disconnect(_on_drag_ended)
	EventBus.active_card_inserted.disconnect(_on_active_card_inserted)

func _on_active_card_changed(event:CardEvent):
	print("active change — waiting for fly animation")
	# 等手牌队列的飞行动画结束再显示
	await get_tree().create_timer(0.3).timeout
	var active_card_data = event.cards[-1]
	active_card = card_scene.instantiate()
	active_card.data = active_card_data
	active_card.scale = Vector2(scale_ration,scale_ration)
	active_card.modulate.a = 1
	active_card.draggable = true
	self.add_child(active_card)
	print("active card shown")

func _on_drag_ended(card: Card, _pos: Vector2) -> void:
	if card.get_parent() != self:
		return
	if _drag_ghost:
		print("activeslot drag_end")
		_drag_ghost.queue_free()
		_drag_ghost = null
		if active_card:
			active_card.modulate.a = 1

func _on_active_card_inserted(event:CardEvent) ->void:
	if _drag_ghost:
		_drag_ghost.queue_free()
		_drag_ghost = null
	if active_card:
		print("release active card")
		self.remove_child(active_card)
		active_card.queue_free()

func _process(_delta: float) -> void:
	if _drag_ghost:
		_drag_ghost.global_position = get_global_mouse_position() - (_drag_ghost.size * _drag_ghost.scale / 2)
