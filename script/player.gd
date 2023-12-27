extends CharacterBody2D

enum State{
	IDLE,
	RUNNING,
	JUMP,
	FALL,
	LANDING,
	WALL_SLIDING,
}

const GROUND_STATES := [State.IDLE, State.RUNNING]
const JUMP_VELOCITY = -320.0
const RUN_SPEED = 160.0
const FLOOR_ACCELERATION = RUN_SPEED / 0.2
const AIR_ACCELERATION = RUN_SPEED / 0.02
var is_first_tick = false
var default_gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

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
			stand(delta)
			
		State.WALL_SLIDING:
			move(default_gravity / 6.0, delta)
	
	is_first_tick = false


func stand(delta: float) -> void:
	var acceleration = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.y += default_gravity * delta
	move_and_slide()


func move(gravity, delta: float) -> void:
	var direction = Input.get_axis("move_left", "move_right")
	var acceleration = FLOOR_ACCELERATION if is_on_floor() else AIR_ACCELERATION
	velocity.x = move_toward(velocity.x, direction * RUN_SPEED, acceleration * delta)
	move_and_slide()
	velocity.y += gravity * delta
	
	if not is_zero_approx(direction	):
		graphics.scale.x = -1 if direction < 0 else 1
		

func get_next_state(state: State) -> State:
	var can_jump = is_on_floor() or not coyote_timer.is_stopped()
	var should_jump = can_jump and not jump_request_timer.is_stopped()
	if should_jump:
		return State.JUMP
		
	var direction = Input.get_axis("move_left", "move_right")
	var is_still = is_zero_approx(direction)
	match state:
		State.IDLE:
			if not is_on_floor():
				return State.FALL
			if not is_still:
				return State.RUNNING
		
		State.RUNNING:
			if not is_on_floor():
				return State.FALL
			if is_still:
				return State.IDLE
				
		State.JUMP:
			if velocity.y > 0:
				return State.FALL
		
		State.FALL:
			if is_on_floor():
				return State.LANDING if is_still else State.RUNNING
			if is_on_wall() and foot_checker.is_colliding() and head_checker.is_colliding():
				return State.WALL_SLIDING
		
		State.LANDING:
			if not is_still:
				return State.RUNNING
			if not animation_player.is_playing():
				return State.IDLE
				
		State.WALL_SLIDING:
			if is_on_floor():
				return State.IDLE
			if not is_on_wall():
				return State.FALL
		
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
			
	is_first_tick = true
		
