class_name StateMachine
extends Node

var state_timer: float

var current_state: int:
	set(v):
		owner.transition_state(current_state, v)
		current_state = v
		state_timer = 0

func _ready() -> void:
	await owner.ready
	current_state = 0

func _physics_process(delta: float) -> void:
	while true:
		var next := owner.get_next_state(current_state) as int
		if current_state == next:
			break
		current_state = next
	state_timer += delta
	owner.tick_physics(current_state, delta)

	
