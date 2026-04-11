extends Node3D
class_name Agent

enum AgentState {Idle, GoingToRide, GoingToActivity, Queuing, FastPassQueuing, OnRide, InActivity, Leaving, Left}

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var id: int

var profile: AgentProfile
var stay_time_preference: int
var exit_time: int

var fastpass_aware: bool
var onlinewait_aware: bool

var state: AgentState
var state_details: String
var state_history: Dictionary[int, Array]

var fastpasses: Array[FastPass]

@onready var agent_manager: AgentManager = get_tree().current_scene.get_node("%AgentManager")
@onready var time_manager: TimeManager = get_tree().current_scene.get_node("%TimeManager")
@onready var ride_manager: RideManager = get_tree().current_scene.get_node("%Rides")
@onready var activity_manager: ActivityManager = get_tree().current_scene.get_node("%Activities")
@onready var profile_manager: AgentProfileManager = get_tree().current_scene.get_node("%AgentProfiles")

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
var safe_vel: Vector3
var walk_vel: float


var cached_travel_path: PackedVector3Array
var cached_travel_dist: float

var travel_duration: float # in delta real-world seconds.
var travel_timer: float

var target_ride: Ride
var ride_history: Dictionary[int, Ride]

var target_activity: Activity
var activity_timer: int

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
	self.walk_vel = profile_manager.get_walk_speed() * randf_range(1.05,1.4) # variation in walking speed, also make it faster to prevent teleporting
	nav_agent.velocity_computed.connect(on_velocity_computed)


## Returns [walktime (inworld): float, walk_distance: float]
func get_walktime_to_ride(ride: Ride) -> Array:
	return get_walktime(global_position, ride.global_position)

## Returns [walktime (inworld): float, walk_distance: float]
func get_walktime(pos_a: Vector3, pos_b: Vector3) -> Array:
	var path: PackedVector3Array = NavigationServer3D.map_get_path(
		nav_agent.get_navigation_map(),
		pos_a,
		pos_b,
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
	
	var a: Array = get_walktime_to_ride(ride)
	
	
	var walktime: float = a[0]
	
	# decoupled from minute
	self.travel_duration = walktime
	self.travel_timer = 0
	
	if walktime == 0: # we're already here :) the vel calculation will likely break so we just skip it
		return
	
	#print(self.walk_vel)
	#nav_agent.max_speed = self.walk_vel
	
	# Start walk
	cached_travel_dist = 0
	cached_travel_path = []
	
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
	
	#print(self.walk_vel)
	#nav_agent.max_speed = self.walk_vel
	
	# Start walk
	cached_travel_dist = 0
	cached_travel_path = []
	
	nav_agent.target_position = Vector3.ZERO # exit is at (0,0,0). yes hardcoded is bad. no i dont care

	travel_timer = 0
	travel_duration = nav_agent.get_path_length() / self.walk_vel # how many real-world seconds to leave


# automatically switch between obstacle avoidance and path sampling based on time simulation speed
func go_along_path(delta: float) -> void:
	if time_manager.minute_delta >= time_manager.navagent_limit:
		# use normal obstacle avoidance
		# Calculate velocity
		var vel: Vector3 = global_position.direction_to(nav_agent.get_next_path_position()) * self.walk_vel
		vel.y = 0
		
		nav_agent.velocity = vel
		global_position += self.safe_vel * delta
			
	else:
		if cached_travel_path == null or len(cached_travel_path) == 0:
			nav_agent.get_next_path_position() # this is required to trigger navagent to build path
			cached_travel_path = nav_agent.get_current_navigation_path()
			cached_travel_dist = nav_agent.get_path_length()
		
		# path sampling
		# percentage is calculated by time
		var percentage: float = travel_timer / travel_duration
		
		var sampled_length: float = cached_travel_dist * percentage
		
		var sample_pos: Vector3 = global_position # just incase it's broken, stay at the same place
		var sample_dist: float = 0
		
		if len(cached_travel_path) == 0: # apparently this can happen
			return
		
		var last_path_point: Vector3 = cached_travel_path[0]
		for path_point in cached_travel_path.slice(1):
			var dist: float = last_path_point.distance_to(path_point)
			if sample_dist + dist >= sampled_length:
				# either inbetween or right on the next one
				sample_pos = last_path_point.lerp(path_point, (sampled_length - sample_dist) / dist)
				break
			else:
				sample_dist += dist
				last_path_point = path_point
		
		global_position = sample_pos


func _physics_process(delta: float) -> void:
	if state == AgentState.GoingToRide:
		go_along_path(delta)
		travel_timer += delta

		if travel_timer >= travel_duration or nav_agent.is_target_reached():
			# Arrived
			arrive_at_ride()
	
	elif state == AgentState.GoingToActivity:
		go_along_path(delta)
		travel_timer += delta
		
		if travel_timer >= travel_duration or nav_agent.is_target_reached():
			# can't be bothered to make a separate function for this lol
			# just some basic cleanup that's probably not even needed
			travel_timer = 0
			travel_duration = 0
			
			state = AgentState.InActivity # this is important though
			
	
	elif state == AgentState.InActivity:
		var vel: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, randf_range(0, 2*PI)) # let agent move randomly
		vel *= profile_manager.get_activity_speed() # move only a tiny bit :)
		global_position += vel * delta
	
	elif state == AgentState.Leaving:
		go_along_path(delta)
		travel_timer += delta
	
		if travel_timer >= travel_duration or nav_agent.is_target_reached():
			# arrived
			state = AgentState.Left
			
			# destroy self
			agent_manager.in_park_agents.erase(self)
			queue_free()
		


func _tick(minute: int, _delta: float) -> void:
	state_history[minute] = [state, state_details]
	
	if state == AgentState.Idle:
		if check_if_go_home():
			go_home()
			return
		
		decide_attraction()
	
	elif state == AgentState.InActivity:
		activity_timer -= 1
		if activity_timer <= 0:
			activity_finished()

func on_velocity_computed(_safe_vel: Vector3) -> void:
	self.safe_vel = _safe_vel


## Called when idle, decide what to do next.
func decide_attraction() -> void:
	# 1. If there's a fastpass with a very close expiry time (<=10 min till expiry considering walking time), go to that ride.
	# 2 (else). Decide whether to do an activity or ride. If ride and no rides are applicable, fall back to activity.

	# fastpass cleanup :)
	for i in range(len(fastpasses)-1, -1, -1):
		fastpasses[i].cleanup(time_manager.current_minute)
	
	fastpasses.sort_custom(func(a, b): return a.time <= b.time)

	var upcoming_fp: FastPass = null
	if len(fastpasses) > 0:
		var candidate_fp: FastPass = fastpasses[0]
		if candidate_fp.time <= time_manager.current_minute + ceili(get_walktime_to_ride(candidate_fp.ride)[0] / 60) + 10:
			walk_to_ride(candidate_fp.ride)
			return	
	
		# there are fastpasses some time away. Our decision have to be time-aware so we can make it to this fastpass later
		upcoming_fp = fastpasses[0]
	
	var tries: int = 0
	while true:
		tries += 1
		
		if tries >= 15: # CUSTOMIZE. 15 tries and still cant find a valid place to go to -> fully give up
			# okay this is ridiculous
			state = AgentState.Idle
			return
		
		# decide if activity or ride
		var do_select_ride = randf() <= profile.attraction_preference
		
		if do_select_ride:
			var sel_ride: Ride = ride_manager.get_random_ride()
			if check_ride_decision_validity(sel_ride, upcoming_fp):
				walk_to_ride(sel_ride)
				return
			
		else:
			# Activity
			var sel_activity: Activity = activity_manager.get_random_activity()
			if upcoming_fp != null and upcoming_fp.time	< (time_manager.current_minute + sel_activity.mean_time
				+ ceili(get_walktime_to_ride(upcoming_fp.ride)[0] / 60.0)):
				# Not enough time. Try again
				continue
			else:
				do_activity(sel_activity, upcoming_fp != null)
				return
			
			
func check_ride_decision_validity(ride: Ride, upcoming_fp: FastPass) -> bool:
	# time limit is checked if upcoming_fp is not null. The time is calculated by: time walking to ride + queue time +
	# time walking to fastpass ride. Getting fastpasses is disabled if upcoming_fp is not null.
	# if ride support online checking, check if time limit is okay. (else -> assume okay)
	# if time is above balking point (and upcoming_fp is null), if ride supports online fp, get one.
	# Also check if the agent already has a fastpass for this ride, if so, give up immediately.
	# if all else fails, give up and choose another ride.
	
	if not profile.allow_repeats:
		# ensure agent haven't ridden this yet since repeats are disabled
		if ride in ride_history.values():
			return false

	if upcoming_fp != null:
		if ride.standby_wait_time > profile.wait_threshold:
			return false
		
		var opportunity_time: int
		if ride.online_waittimes and onlinewait_aware:
			opportunity_time = (ceili(get_walktime_to_ride(ride)[0]/60.0) 
				+ ride.standby_wait_time + ride.run_time
					+ ceili(get_walktime(ride.global_position, upcoming_fp.ride.global_position)[0] / 60.0) + 3) # add some minutes just in case
		else:
			opportunity_time = (ceili(get_walktime_to_ride(ride)[0]/60.0) 
				+ ride.run_time # cant get wait time :O
					+ ceili(get_walktime(ride.global_position, upcoming_fp.ride.global_position)[0] / 60.0) + 10) # add MORE minutes since agent have to guess queue times
				
		if time_manager.current_minute + opportunity_time > upcoming_fp.time:
			return false
		else:
			return true
		
	else:
		# no upcoming fastpasses, we can do whatever
		
		if not (ride.online_waittimes and onlinewait_aware):
			# can't check wait times, assume okay
			return true
		
		if ride.standby_wait_time <= profile.wait_threshold:
			return true
			# else:	Wait time is over balking time
			# failover
			
		# if we already have fastpass, don't bother
		if fastpasses.any(func(obj): return obj.ride == ride):
			return false
			
		if (ride.online_fastpass and fastpass_aware and onlinewait_aware 
				and len(fastpasses) < profile_manager.max_fastpasses): # we assume online fp is enabled when fp and onlinewait aware is both on
			var fp: FastPass = ride.get_fastpass_if_possible(self)
			
			if fp != null:
				fastpasses.append(fp)
				return false # we want the agent to find another attraction to go to right now
			
			# else failover
		
	return false


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
	
	var fp_failover: bool = false
	
	if not fastpasses.is_empty():
		var match_fp = fastpasses.filter(func(obj): return obj.ride == target_ride).front()
		if match_fp != null:
			if target_ride.redeem_fastpass(self, match_fp):
				return true
			# else: failover
		
		# Special checks are done if the agent has fastpasses for other rides,
		# ensure waittime + ride time + walk time to fastpass does not exceed time requirement
		if not fastpasses.is_empty(): # check again since last one might be only one and is expired
			var closest_fp: FastPass = fastpasses[0]
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
	elif (fastpass_aware and target_ride.fastpass_available and 
			len(fastpasses) < profile_manager.max_fastpasses and 
				not fastpasses.any(func(obj): return obj.ride == target_ride)):
		# Last if: the agent cannot hold another fastpass if they still have one that's not redeemed.
		# Technically we don't need this but having multiple fastpasses for one ride seems unfair especially when online is on.
		
		# fp available. Get fastpass if possible
		var possible_fp: FastPass = target_ride.get_fastpass_if_possible(self)
		if possible_fp != null:
			fastpasses.append(possible_fp)
			state = AgentState.Idle
	
	state = AgentState.Idle
	return false
	

func do_activity(activity: Activity, time_restricted: bool) -> void:
	# when not time restricted, agent will go to a random place on navmesh, similar to how a guest might go to a specific
	# restaurant or POI.
	# if time restricted, agent will just do the activity near where they are.

	target_ride	= null
	
	target_activity = activity
	state = AgentState.GoingToActivity
	state_details = activity.name
	
	
	if time_restricted or !profile_manager.enable_activity_roaming:
		cached_travel_dist = 0
		cached_travel_path = []
		
		nav_agent.target_position = global_position
		travel_duration = 0
		travel_timer = 0
	else:
		cached_travel_dist = 0
		cached_travel_path = []
		
		var target: Vector3 = NavigationServer3D.map_get_random_point(nav_agent.get_navigation_map(), nav_agent.navigation_layers, true)
		nav_agent.target_position = target
		travel_duration = get_walktime(global_position, target)[0]
		travel_timer = 0
	
	activity_timer = int(randfn(activity.mean_time, activity.mean_time/2.0))

func activity_finished() -> void:
	target_activity = null
	state = AgentState.Idle
	activity_timer = 0 

# Ride called functions

func enter_fp_queue() -> void:
	state = AgentState.FastPassQueuing
	
func enter_standby_queue() -> void:
	state = AgentState.Queuing

func get_on_ride() -> void:
	state = AgentState.OnRide
	ride_history[time_manager.current_minute] = target_ride
	
func exit_ride() -> void:
	#print("EXIT RIDE")
	target_ride = null
	state = AgentState.Idle
