extends Node3D
class_name Agent

enum AgentState {Idle, GoingToRide, Queuing, FastPassQueuing, OnRide, InActivity, Leaving, Left}

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var id: int

var profile: AgentProfile
var stay_time_preference: int
var exit_time: int

var fastpass_aware: bool
var onlinewait_aware: bool

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
	self.exit_time = time_manager.current_minute + stay_time_preference
	self.fastpass_aware = randf() <= profile_manager.fastpass_aware_percent
	self.onlinewait_aware = randf() <= profile_manager.onlinewait_aware_percent
	
	self.state = AgentState.Idle

	init_nav_agent()
	
func init_nav_agent() -> void:
	nav_agent.max_speed = profile_manager.get_walk_speed() * 3 # slightly above average walk speed :)
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
	var walk_time_sec: float = total_distance / profile_manager.get_walk_speed() # use default walk speed
	return [walk_time_sec, total_distance]


func walk_to_ride(ride: Ride) -> void:
	self.state = AgentState.GoingToRide
	self.state_details = ride.name
	
	self.target_ride = ride
	
	self.walk_vel = profile_manager.get_walk_speed()
	var a: Array = get_walktime_to_ride(ride)
	self.walk_vel = profile_manager.get_walk_speed() * randf_range(1.1,1.4) # variation in walking speed, also make it faster to prevent teleporting
	
	var walktime: float = a[0]
	
	# decoupled from minute
	self.arrival_time = walktime
	self.travel_timer = 0
	
	if walktime == 0: # we're already here :) the vel calculation will likely break so we just skip it
		return
	
	#print(self.walk_vel)
	#nav_agent.max_speed = self.walk_vel
	
	# Start walk
	nav_agent.target_position = ride.global_position

func check_if_go_home() -> bool:
	if not time_manager.park_open:
		return true
	
	if time_manager.current_minute > exit_time:
		return true
	
	return false	
	
func go_home():
	self.state = AgentState.Leaving
	self.state_details = "LEAVING"
	
	self.target_ride = null
	
	self.walk_vel = profile_manager.get_walk_speed() * randf_range(1,1.4) # variation in walking speed
	
	#print(self.walk_vel)
	#nav_agent.max_speed = self.walk_vel
	
	# Start walk
	nav_agent.target_position = Vector3.ZERO # exit is at (0,0,0). yes hardcoded is bad. no i dont care


func _physics_process(delta: float) -> void:
	if state == AgentState.GoingToRide:
		# Calculate velocity
		var vel: Vector3 = global_position.direction_to(nav_agent.get_next_path_position()) * self.walk_vel
		vel.y = 0
		
		nav_agent.velocity = vel
		global_position += self.safe_vel * delta
		
		travel_timer += delta

		if travel_timer >= arrival_time or nav_agent.is_target_reached():
			# Arrived
			arrive_at_ride()
	
		
	elif state == AgentState.Leaving:
		var vel: Vector3 = global_position.direction_to(nav_agent.get_next_path_position()) * self.walk_vel
		vel.y = 0
		
		nav_agent.velocity = vel
		global_position += self.safe_vel * delta
	
		if nav_agent.is_target_reached():
			# arrived
			state = AgentState.Left
			
			# destroy self
			agent_manager.in_park_agents.erase(self)
			queue_free()
			


func _tick(minute: int, _delta: float) -> void:
	if state == AgentState.Idle or state == AgentState.GoingToRide:
		if check_if_go_home():
			go_home()
			return
			
	if state == AgentState.Idle:
		# TODO: Debug: go to random
		walk_to_ride(ride_manager.get_random_ride())
		


func on_velocity_computed(_safe_vel: Vector3) -> void:
	self.safe_vel = _safe_vel


func arrive_at_ride() -> bool:
	self.state = AgentState.Queuing
	
	if not nav_agent.is_navigation_finished():
		# Teleport to destination
		self.global_position = self.target_ride.global_position
		self.global_position.x += randf_range(-2,2) # some randomness
		self.global_position.z += randf_range(-2,2) # some randomness

	# Check if agent has valid fastpass for this ride (or other rides), if so, use the fastpass
	
	# fastpass cleanup :)
	for i in range(len(fastpasses)-1, -1, -1):
		fastpasses[i].cleanup(time_manager.current_minute)
	
	fastpasses.sort_custom(func(a, b): return a.time <= b.time)
	
	var fp_failover = false
	
	if not fastpasses.is_empty():
		var match_fp = fastpasses.filter(func(obj): return obj.ride == target_ride).front()
		if match_fp != null:
			if target_ride.redeem_fastpass(self, match_fp):
				return true
			# else: failover
		
		# Special checks are done if the agent has fastpasses for other rides,
		# ensure waittime + ride time + walk time to fastpass does not exceed time requirement
		var closest_fp = fastpasses[0]
		if (closest_fp.time > (target_ride.standby_wait_time + target_ride.run_time + ceili(get_walktime_to_ride(closest_fp.ride)[0] / 60.0) + 1) # added one minute just in case
			 and target_ride.standby_wait_time <= profile.wait_threshold):
			# we have enough time to ride this :)
			target_ride.enter_queue(self)
			return true

		else:
			# not enough time to ride this one :(
			# Failover
			fp_failover = true
	

	if target_ride.standby_wait_time <= profile.wait_threshold and not fp_failover:
		# we ride :)
		target_ride.enter_queue(self)
		return true
	elif fastpass_aware and target_ride.fastpass_available and len(fastpasses) < profile_manager.max_fastpasses:
		# fp available. Get fastpass if possible
		var possible_fp = target_ride.get_fastpass_if_possible(self)
		if possible_fp != null:
			fastpasses.append(possible_fp)
			state = AgentState.Idle
	
	state = AgentState.Idle
	return false
	

# Ride called functions

func enter_fp_queue() -> void:
	state = AgentState.FastPassQueuing
	
func enter_standby_queue() -> void:
	state = AgentState.Queuing

func get_on_ride() -> void:
	state = AgentState.OnRide
	
func exit_ride() -> void:
	print("EXIT RIDE")
	target_ride = null
	state = AgentState.Idle
