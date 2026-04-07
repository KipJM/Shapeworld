extends Node3D
class_name Agent

enum AgentState {Idle, GoingToRide, Queuing, OnRide, Activity, Leaving, Left}

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var id: int

var profile: AgentProfile
var stay_time_preference: int
var state: AgentState
var state_details: String
var fastpasses: Array[FastPass]

@onready var agent_manager: AgentManager = get_tree().current_scene.get_node("%AgentManager")
@onready var time_manager: TimeManager = get_tree().current_scene.get_node("%TimeManager")
@onready var ride_manager: RideManager = get_tree().current_scene.get_node("%Rides")
@onready var profile_manager: AgentProfileManager = get_tree().current_scene.get_node("%AgentProfiles")

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
var safe_vel: Vector3
var walk_vel: float

var target_ride: Ride
var arrival_time: float
var travel_timer: float

func initialize(_id: int, _profile: AgentProfile) -> void:
	time_manager.tick.connect(_tick)
	
	self.id = _id
	self.profile = _profile
	
	self.stay_time_preference = int(randfn(profile.stay_time_preference, profile.stay_time_preference/4.0))
	
	self.state = AgentState.Idle

	init_nav_agent()
	
	#TODO: Remove
	nav_agent.debug_enabled = false
	walk_to_ride(ride_manager.get_random_ride())
	
func init_nav_agent() -> void:
	nav_agent.max_speed = 10000.0 # no limit
	nav_agent.velocity_computed.connect(on_velocity_computed)


## Returns [walktime (inworld): float, walk_distance: float]
func get_walktime_to_ride(ride: Ride) -> Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		nav_agent.get_navigation_map(),
		global_position,
		ride.global_position,
		true
	)
	
	var total_distance: float = 0.0
	
	if path.size() > 1:
		for i in range(path.size() - 1):
			total_distance += path[i].distance_to(path[i + 1])

	#print(total_distance)

	# This is in-world seconds
	var walk_time_sec: float = total_distance / self.walk_vel
	return [walk_time_sec, total_distance]


func walk_to_ride(ride: Ride):
	self.state = AgentState.GoingToRide
	self.state_details = ride.name
	
	self.target_ride = ride
	
	self.walk_vel = profile_manager.get_walk_speed() * randf_range(1.01,1.2) # variation in walking speed, also make it faster to prevent teleporting
	var a = get_walktime_to_ride(ride)
	
	var walktime: float = a[0]
	
	print(walktime) 
	# decoupled from minute
	self.arrival_time = walktime
	self.travel_timer = 0
	
	if walktime == 0: # we're already here :) the vel calculation will likely break so we just skip it
		return
	
	#print(self.walk_vel)
	#nav_agent.max_speed = self.walk_vel
	
	# Start walk
	nav_agent.target_position = ride.global_position


func arrive_at_ride():
	self.state = AgentState.Queuing
	
	if not nav_agent.is_navigation_finished():
		# Teleport to destination
		self.global_position = self.target_ride.global_position
	
	# TODO: change this. for testing
	walk_to_ride(ride_manager.get_random_ride())
	pass



func _physics_process(delta: float) -> void:
	if state == AgentState.GoingToRide:
		# Calculate velocity
		var vel = global_position.direction_to(nav_agent.get_next_path_position()) * self.walk_vel
		vel.y = 0
		
		nav_agent.velocity = vel
		global_position += self.safe_vel * delta
		
		travel_timer += delta

		if travel_timer >= arrival_time or nav_agent.is_target_reached():
			# Arrived
			arrive_at_ride()



func _tick(minute: int, _delta: float) -> void:
	pass


func on_velocity_computed(_safe_vel: Vector3) -> void:
	self.safe_vel = _safe_vel
