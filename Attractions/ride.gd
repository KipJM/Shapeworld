extends Marker3D

class_name Ride

# popularity is defined in ride manager
@export_category("Configs")
## How long for one cart to complete a ride
@export var run_time: int
## Hourly people throughput. The capacity will be automatically calculated
@export var hourly_throughput: int
## is fastpass available
@export var fastpass_available: bool
## is wait time checkable online
@export var online_waittimes: bool
## can fastpasses be obtained online
@export var online_fastpass: bool
## fastpass queue ratio. What percentage of attraction capacity is given to fastpass members.
@export_range(0,1, 0.1) var fastpass_queue_ratio: float


var queue: Array[Agent]
