class_name Card
extends Control

@export var data: CardData :
	set(value):
		data = value
		# 关键：数据赋值时更新UI（可能_ready已经执行过了）
		if is_inside_tree():
			_initial_ui()

@onready var FrontTexture = $Front/CardFront
@onready var BackTexture = $Back/CardBack
@onready var CardButton = $CardButton
@export var draggable:bool = false


var is_selsected = false
var is_dragged = false
var _drag_start_pos: Vector2
var _drag_threshold :float = 5.0
var is_botton_down: bool = false

const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.3, 1.0)  # 金色高亮
const DEFAULT_COLOR := Color.WHITE

func _ready():
	if data != null:
		_initial_ui()
	else:
		print("data is null")



func _initial_ui() ->void:
	match data.type:
		CardData.Type.NORMAL:
			var suit_str = _get_suit_string(data.suit)
			var rank_str = data.rank
			var texture_path ="res://assets/textures/card_%s_%s.png" % [suit_str, rank_str]
			FrontTexture.texture = load(texture_path)
			BackTexture.texture = load("res://assets/textures/card_back.png")

func _get_suit_string(suit: CardData.Suit) -> String:
	match suit:
		CardData.Suit.SPADES: return "spades"
		CardData.Suit.HEARTS: return "hearts"
		CardData.Suit.CLUBS: return "clubs"
		CardData.Suit.DIAMONDS: return "diamonds"
	return ""

func set_highlight(on: bool) -> void:
	modulate = HIGHLIGHT_COLOR if on else DEFAULT_COLOR

# func _on_card_button_pressed() -> void:
	# pass # Replace with function body.


func _on_card_button_button_down() -> void:
	is_botton_down = true
	print("button down")
	is_dragged = false
	_drag_start_pos = get_global_mouse_position()


func _on_card_button_button_up() -> void:
		is_botton_down = false
		if is_dragged:
			EventBus.card_droped.emit(self,get_global_mouse_position())
			is_dragged = false
		else:
			EventBus.card_selected.emit(self)

func _process(_delta: float) -> void:
	if not draggable:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and is_botton_down:
		var mouse_pos = get_global_mouse_position()
		if not is_dragged and mouse_pos.distance_to(_drag_start_pos) > _drag_threshold:
			is_dragged = true
			EventBus.card_drag_started.emit(self)
