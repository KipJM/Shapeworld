class_name FastPass

enum FPState {AWAITING, REDEEMED, EXPIRED}

var ride: Ride
var owner: Agent
var time: int # When to ride. In in-world minutes
var late_limit: int

var state: FPState = FPState.AWAITING

static func create(_ride: Ride, _owner: Agent, _time: int, _late_limit: int) -> FastPass:
	var o: FastPass = FastPass.new()
	o.ride = _ride
	o.owner = _owner
	o.time = _time
	o.late_limit = _late_limit
	return o

func redeem():
	if state == FPState.REDEEMED:
		# already redeemed, don't do cleanup again
		return
	
	if owner != null and is_instance_valid(owner):
		owner.fastpasses.erase(self)
	ride.unredeemed_fastpass_queue.erase(self)
	state = FPState.REDEEMED
	
func expire():
	if state == FPState.EXPIRED:
		# already expired, don't do cleanup again
		return
		
	if owner != null and is_instance_valid(owner):
		owner.fastpasses.erase(self)
	ride.unredeemed_fastpass_queue.erase(self)
	state = FPState.EXPIRED


func cleanup(current_minute: int):
	if current_minute > time:
		expire()
	if state == FPState.REDEEMED:
		redeem()
