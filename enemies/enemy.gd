class_name Enemy
extends CharacterBody2D

enum Direction{
	LEFT = -1,
	RIGHT = +1,
}

@export var direction = Direction.LEFT:
	set(v):
		direction = v
		graphics.scale.x = -direction
@export var max_speed: float = 180.0
@export var acceleration: float = 2000.0

var default_gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var graphics: Node2D = $Graphics
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var state_machine: Node = $StateMachine
