extends Node3D
@export var movement_speed: float = 20
@export var movement_target: Marker3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var prev_position: Vector3

var safe_vel: Vector3

func _ready():
	# These values need to be adjusted for the actor's speed
	# and the navigation layout.
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5
	nav_agent.max_speed = movement_speed

	nav_agent.debug_enabled = false

	nav_agent.velocity_computed.connect(apply_velocity)

	# Make sure to not await during _ready.
	actor_setup.call_deferred()

func actor_setup():
	# Wait for the first physics frame so the NavigationServer can sync.
	await get_tree().physics_frame

	# Now that the navigation map is no longer empty, set the movement target.
	set_movement_target(movement_target.global_position)

func set_movement_target(movement_target: Vector3):
	nav_agent.set_target_position(movement_target)

func _physics_process(delta):
	if movement_target.global_position != prev_position:
		set_movement_target(movement_target.global_position) # never stop
	if nav_agent.is_navigation_finished():
		return

	var current_agent_position: Vector3 = global_position
	var next_path_position: Vector3 = nav_agent.get_next_path_position()

	var velocity = current_agent_position.direction_to(next_path_position) * movement_speed
	nav_agent.velocity = velocity
	
	global_position += safe_vel * delta
	prev_position = movement_target.global_position
	
func apply_velocity(safe_velocity: Vector3):
	safe_vel = safe_velocity
