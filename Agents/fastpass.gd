class_name FastPass

enum FPState {AWAITING, REDEEMED, EXPIRED}

var ride: Ride
var owner: Agent
var time: int # When to ride. In in-world minutes

var state: FPState = FPState.AWAITING

static func create(_ride: Ride, _owner: Agent, _time: int) -> FastPass:
	var o: FastPass = FastPass.new()
	o.ride = _ride
	o.owner = _owner
	o.time = _time
	return o

func redeem():
	owner.fastpasses.erase(self)
	state = FPState.REDEEMED
	
func expire():
	owner.fastpasses.erase(self)
	state = FPState.EXPIRED


func cleanup(current_minute: int):
	if current_minute > time:
		expire()
	if state == FPState.REDEEMED:
		redeem()
