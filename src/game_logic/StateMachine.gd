class_name StateMachine
extends Node

signal state_changed(new_state:String,old_state:String)

@export var initial_state: Node

var cur_state : States

var _states:Dictionary

func _ready():
	_collect_states()
	if initial_state:
		print(initial_state.name)
		change_state(initial_state.name)
	print("State Machine Ready" )
	
func _collect_states() -> void:
	for child in get_children():
		if child is States:
			_states[child.name] = child
			child.state_machine = self  
			child.set_process(false)
			child.set_physics_process(false)

			if not child.transition_requested.is_connected(_on_transition_request):
				child.transition_requested.connect(_on_transition_request)

func change_state(state_name:String) -> void:
	var current_name = cur_state.name if cur_state else ""
	if state_name == current_name:
		return
	var new_state = _states.get(state_name)
	if not new_state:
		push_error("Can't Find State %s" % state_name)
		return
	var old_name = cur_state.name if cur_state else " "

	if cur_state:
		cur_state.exit()
		cur_state.set_process(false)
		cur_state.set_physics_process(false)

	cur_state = new_state
	cur_state.set_process(true)
	cur_state.set_physics_process(true)
	cur_state.enter()

	state_changed.emit(state_name,old_name)
	print("State changed %s -> %s" %[old_name,state_name])

func _on_transition_request(nxt_state : String) -> void:
	change_state(nxt_state)

func get_current_state_name() -> String:
	return cur_state.name if cur_state else ""
