class_name NodeFiniteStateMachine
extends Node

## 通用节点状态机:把孩子里的 NodeState 按「节点名小写」注册,靠 transition 信号切换。
## 子状态节点名必须唯一(如 idle / walk / use)。
##
## 用法:挂在一个 Node 上,把 initial_state 指向某个子状态,子状态脚本 extends NodeState。

@export var initial_state: NodeState

var states: Dictionary = {}
var current_state: NodeState
var current_state_name: String = ""


func _ready() -> void:
	for child in get_children():
		if child is NodeState:
			states[child.name.to_lower()] = child
			child.transition.connect(on_state_transition)
	if initial_state != null:
		current_state = initial_state
		current_state_name = initial_state.name.to_lower()
		# 延迟到本帧末:_ready 是自下而上的,父节点(比如 Player)的 @onready
		# 变量此刻还没赋值,状态里访问 owner 会拿到 null。
		current_state.on_enter.call_deferred()


func _process(delta: float) -> void:
	if current_state != null:
		current_state.on_process(delta)


func _physics_process(delta: float) -> void:
	if current_state == null:
		return
	current_state.on_physics_process(delta)
	current_state.on_next_transitions()


func on_state_transition(state_name: String) -> void:
	var key := state_name.to_lower()
	if current_state != null and key == current_state_name:
		return

	var next: NodeState = states.get(key)
	if next == null:
		push_warning("NodeFiniteStateMachine: 未知状态 '%s'" % state_name)
		return

	if current_state != null:
		current_state.on_exit()
	current_state = next
	current_state_name = key
	current_state.on_enter()
