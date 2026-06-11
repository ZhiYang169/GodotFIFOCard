# src/game_logic/state_machine/State.gd
class_name States
extends Node

## 状态内部请求切换到另一个状态
## 用法：在子类中 emit(transition_requested, "NextStateName")
signal transition_requested(next_state_name: String)

## 反向引用到状态机（由 StateMachine 自动设置）
var state_machine: StateMachine

## 便捷引用到 GameManager（因为 StateMachine 是 Game 的子节点）
var game_manager: GameManager:
	get:
		if not _game_manager:
			_game_manager = get_node_or_null("/root/Game/GameManager")
		return _game_manager
var _game_manager: GameManager

## 进入状态时调用（子类必须 super.enter()）
func enter() -> void:
	pass

## 退出状态时调用（子类必须 super.exit()）
func exit() -> void:
	pass

## 便捷方法：请求切换到指定状态
func go_to(state_name: String) -> void:
	transition_requested.emit(state_name)
