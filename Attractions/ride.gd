extends Marker3D

class_name Ride

# popularity is defined in ride manager
@export_category("Configs")
## How long for one cart to complete a ride, in minutes
@export var run_time: int
## Hourly people throughput. The capacity will be automatically calculated
@export var hourly_throughput: int
## is fastpass available physically at the ride
@export var fastpass_available: bool
## is wait time checkable online
@export var online_waittimes: bool
## can fastpasses be obtained online. Fastpass_available is not required to be on.
@export var online_fastpass: bool
## fastpass queue ratio. What percentage of attraction capacity is given to fastpass members.
@export_range(0,1, 0.1) var fastpass_queue_ratio: float
## Agent is not allowed to redeem their fastpass if they're this many minutes early by their appointment
@export var fp_earlylimit: int = 60
## Ride will expire their fastpass if they're this many minutes late by their appointment
@export var fp_latelimit: int = 60

# how many people can be processed per run
@warning_ignore("integer_division")
@onready var capacity: int = int(hourly_throughput * (run_time/60.0))

# waiting in line
var queue: Array[Agent]
var fastpass_queue: Array[Agent]
var on_ride: Array[Agent]

var available_passes: int
var distributed_fastpasses: Array[FastPass]
var unredeemed_fastpass_queue: Array[FastPass] # queue of fastpasses that are not yet redeemd and NOT EXPIRED
var redeemed_fastpasses: Array[FastPass]

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var standby_wait_time: int

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY)
var fastpass_wait_time: int

# for timing each run
var run_time_remaining: int = run_time

@onready var time_manager: TimeManager = %TimeManager as TimeManager

func calc_standby_wait() -> int:
	if fastpass_available or online_fastpass:
		var queue_len: int = len(queue)
		var exp_queue_len: int = len(fastpass_queue)
		var exp_seats: int = int(capacity * fastpass_queue_ratio)
		var standby_seats: int = capacity - exp_seats

		var runs: int = 0
		# calculate standby wait time through simulating all runs until last person in line gets on ride
		while queue_len > 0:
			var avail_standby: int = 0
			
			if exp_queue_len > exp_seats:
				exp_queue_len -= exp_seats
				avail_standby = standby_seats
			else:
				avail_standby = capacity - exp_queue_len
				exp_queue_len = 0
			
			if queue_len > avail_standby:
				queue_len -= avail_standby
				runs += 1
			else:
				queue_len = 0

		return runs * run_time + run_time_remaining
	else:
		@warning_ignore("integer_division")
		return (max(0, len(queue)-1) / capacity) * run_time + run_time_remaining


func calc_fastpass_wait() -> int:
	if fastpass_available or online_fastpass:
		var queue_len: int = len(queue)
		var exp_queue_len: int = len(fastpass_queue)
		var exp_seats: int = int(capacity * fastpass_queue_ratio)
		var standby_seats: int = capacity - exp_seats

		var runs: int = 0
		# calculate standby wait time through simulating all runs until last person in line gets on ride
		while exp_queue_len > 0:
			var avail_standby: int = 0
			
			if exp_queue_len > exp_seats:
				exp_queue_len -= exp_seats
				avail_standby = standby_seats
			else:
				avail_standby = capacity - exp_queue_len
				exp_queue_len = 0
			
			if queue_len > avail_standby:
				queue_len -= avail_standby
				runs += 1
			else:
				queue_len = 0

		return runs * run_time + run_time_remaining
	else:
		return 0
		
		
func _ready() -> void:
	# initialize ride
	run_time_remaining = run_time
	
	(%TimeManager as TimeManager).tick.connect(_tick)
	


func _tick(minute, delta) -> void:	
	run_time_remaining -= 1
	
	# cleanup expired fastpasses
	for fastpass in unredeemed_fastpass_queue:
		if minute > fastpass.time:
			fastpass.expire()
	
	standby_wait_time = calc_standby_wait()
	fastpass_wait_time = calc_fastpass_wait()
	
	# calculate total fastpasses available
	if fastpass_available or online_fastpass:
		if minute < time_manager.time_close_min:
			var remaining_operating_hours: int = (time_manager.time_close_min - minute) / 60
			var passed_operating_hours: int = minute / 60
			available_passes = (
				(capacity * (60.0/run_time) * fastpass_queue_ratio * remaining_operating_hours) 
				- max(0, 
					(len(distributed_fastpasses) - 
					(capacity * (60.0/run_time) * fastpass_queue_ratio * passed_operating_hours))
				)
			)
		else:
			available_passes = 0 
	
	# cycle guests
	if run_time_remaining <= 0:
		run_ride()
		run_time_remaining = run_time
		

func run_ride():
	# cycle onride guests first
	for i in range(len(on_ride)):
		on_ride.pop_back().exit_ride()
		
	# on board guests
	var onboard_fast_guest_amount: int = min(capacity * fastpass_queue_ratio, len(fastpass_queue))
	var onboard_standby_guest_amount: int = max(0, min(capacity - onboard_fast_guest_amount, len(queue)))
	
	for i in range(onboard_fast_guest_amount):
		var g = fastpass_queue.pop_front()
		g.get_on_ride()
		on_ride.append(g)
	
	for i in range(onboard_standby_guest_amount):
		var g = queue.pop_front()
		g.get_on_ride()
		on_ride.append(g)
	

## Returns null if no fastpass available
func get_fastpass_if_possible(agent: Agent) -> FastPass:
	if can_get_fastpass():
		available_passes -= 1
		var fp: FastPass = FastPass.create(self, agent, time_manager.current_minute + standby_wait_time, fp_latelimit) # using standby wait times. See README.md#Warning about fastpass
		distributed_fastpasses.append(fp)
		unredeemed_fastpass_queue.append(fp)
		return fp
	else:
		return null

func redeem_fastpass(agent: Agent, fastpass: FastPass) -> bool:
	if time_manager.current_minute <= fastpass.time - fp_earlylimit: # agent arrived too early
		return false
	elif time_manager.current_minute <= fastpass.time + fastpass.late_limit: # ticket is valid
		agent.enter_fp_queue()
		fastpass.redeem()
		fastpass_queue.append(agent)
		redeemed_fastpasses.append(fastpass)
		return true
	else:
		# ticket is expired
		fastpass.expire()
		return false
			
func enter_queue(agent: Agent) -> int:
	queue.append(agent)
	agent.enter_standby_queue()
	return standby_wait_time
	
func can_get_fastpass() -> bool:
	return available_passes > 0 and (fastpass_available or online_fastpass)
	
