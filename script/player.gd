extends CharacterBody2D

enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
	WALL_JUMP,
	ATTACK_1,
	ATTACK_2,
	ATTACK_3,
}

@export var can_combo: bool = false 

const GROUND_STATES := [State.IDLE, State.RUNNING]
const JUMP_VELOCITY = -320.0
const WALL_JUMP_VELOCITY = Vector2(380, -280)
const RUN_SPEED = 160.0
const FLOOR_ACCELERATION = RUN_SPEED / 0.2
const AIR_ACCELERATION = RUN_SPEED / 0.1
var is_first_tick = false
var default_gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_combo_requested := false

@onready var state_machine: Node = $StateMachine
@onready var foot_checker: RayCast2D = $Graphics/FootChecker
@onready var head_checker: RayCast2D = $Graphics/HeadChecker
@onready var graphics: Node2D = $Graphics
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var jump_request_timer: Timer = $JumpRequestTimer


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		jump_request_timer.start()
	if event.is_action_released("jump"):
		jump_request_timer.stop()
		if velocity.y < JUMP_VELOCITY / 2:
			velocity.y = JUMP_VELOCITY / 2
	
	if event.is_action_pressed("attack") and can_combo:
		is_combo_requested = true

func stand(gravity: float,delta: float) -> void:
	var acceleration = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += gravity * delta
	move_and_slide()


func move(gravity, delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	var acceleration = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	velocity.y += gravity * delta
	move_and_slide()
	
	if not is_zero_approx(direction	):
		graphics.scale.x = 1 if direction > 0 else -1


func tick_physics(state: State, delta: float) -> void:
	match state:
		State.IDLE:
			move(default_gravity, delta)
		
		State.RUNNING:
			move(default_gravity, delta)
		
		State.JUMP:
			move(0 if is_first_tick else default_gravity, delta)
		
		State.FALL:
			move(default_gravity, delta)
		
		State.LANDING:
			stand(default_gravity, delta)
			
		State.WALL_SLIDING:
			move(default_gravity / 6.0, delta)
		
		State.WALL_JUMP:
			if state_machine.state_timer < 0.1:
				stand(0 if is_first_tick else default_gravity, delta)
				velocity.x *= get_wall_normal().x
			else:
				move(default_gravity, delta)
		
		State.ATTACK_1,State.ATTACK_2,State.ATTACK_3:
			stand(default_gravity, delta)
		
	is_first_tick = false


func can_wall_slide() -> bool:
	return is_on_wall() and foot_checker.is_colliding() and head_checker.is_colliding()


func get_next_state(state: State) -> State:
	var can_jump = is_on_floor() or not coyote_timer.is_stopped()
	var should_jump = can_jump and not jump_request_timer.is_stopped()
	if should_jump:
		return State.JUMP
	
	if state in GROUND_STATES and not is_on_floor():
		return State.FALL
	
	var direction = Input.get_axis("move_left", "move_right")
	var is_still = is_zero_approx(direction)
	match state:
		State.IDLE:
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if not is_still:
				return State.RUNNING
		
		State.RUNNING:
			if not is_on_floor():
				return State.FALL
			if Input.is_action_just_pressed("attack"):
				return State.ATTACK_1
			if is_still:
				return State.IDLE
				
		State.JUMP:
			if velocity.y >= 0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if can_wall_slide():
				return State.WALL_SLIDING
		
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
				
		State.WALL_SLIDING:
			if jump_request_timer.time_left > 0:
				return State.WALL_JUMP
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		
		State.WALL_JUMP:
			if can_wall_slide() and not is_first_tick:
				return State.WALL_SLIDING
			if velocity.y >= 0:
				return State.FALL
		
		State.ATTACK_1:
			if not animation_player.is_playing():
				return State.ATTACK_2 if is_combo_requested else State.IDLE
		
		State.ATTACK_2:
			if not animation_player.is_playing():
				return State.ATTACK_3 if is_combo_requested else State.IDLE
			
		State.ATTACK_3:
			if not animation_player.is_playing():
				return State.IDLE
		
	return state
	
func transition_state(from: State, to: State) -> void:
	match to:
		State.IDLE:
			animation_player.play("idle")	
		
		State.RUNNING:
			animation_player.play("running")	
			
		State.JUMP:
			animation_player.play("jump")
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
			jump_request_timer.start()
		
		State.FALL:
			animation_player.play("fall")	
			if from in GROUND_STATES:
				coyote_timer.start()
		
		State.LANDING:
			animation_player.play("landing")	
		
		State.WALL_SLIDING:
			animation_player.play("wall_sliding")	
		
		State.WALL_JUMP:
			animation_player.play("jump")
			velocity = WALL_JUMP_VELOCITY
			velocity.x *= get_wall_normal().x
			jump_request_timer.start() 
		
		State.ATTACK_1:
			animation_player.play("attack_1")
			is_combo_requested = false
		
		State.ATTACK_2:
			animation_player.play("attack_2")
			is_combo_requested = false
		
		State.ATTACK_3:
			animation_player.play("attack_3")
			is_combo_requested = false
		
	is_first_tick = true
		
