class_name NodeState
extends Node

## 状态基类。子类按需覆写。
##
## transition 带一个参数:目标状态的节点名(大小写不敏感)。
## ⚠️ 参数不能省 —— 若声明成无参 signal,子状态里的 transition.emit("walk")
## 会在运行时抛 "too many arguments",而且只在真的切换时才炸(见 DECISIONS.md)。
@warning_ignore("unused_signal")  # 基类只声明,由子状态 emit
signal transition(state_name: String)


func on_enter() -> void:
	pass


func on_exit() -> void:
	pass


func on_process(_delta: float) -> void:
	pass


func on_physics_process(_delta: float) -> void:
	pass


## 每物理帧最后调用:在这里判断要不要切状态
func on_next_transitions() -> void:
	pass
