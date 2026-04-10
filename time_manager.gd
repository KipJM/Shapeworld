extends Node
class_name TimeManager

## When does a day start, in hour
@export var time_start: int
## When does the park close, in hour. Agents will not be allowed to do new attractions after this time.
@export var time_close: int
## When does a day end, in hour. Simulation stops here.
@export var time_end: int

@onready var time_start_min: int = time_start * 60
@onready var time_close_min: int = time_close * 60
@onready var time_end_min: int = time_end * 60

## how many realtime seconds for a minute to pass
@export var minute_delta: float
## When the minute delta is below this limit, agents' walking behavior will be switched to path sampling instead of obstacle avoidance for higher accuracy.
@export var navagent_limit: float

## mapping of how many in-world second is one real world second
var time_scale: float


@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY) var current_minute: int

@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY) var current_hour: int

var park_open: bool

signal tick(time: int, delta: float)

func _ready() -> void:
	var timer: Timer = $Timer
	timer.timeout.connect(on_timer_expired)
	current_minute = time_start * 60
	current_hour = int(current_minute / 60.0)
	timer.start(minute_delta)
	
	# calculate time scale
	time_scale = 1.0 / (minute_delta / 60.0)
	
	park_open = true

func on_timer_expired() -> void:
	#print(current_minute)
	current_minute+=1
	current_hour = int(current_minute / 60.0)
	
	if current_minute > time_end * 60:
		print("Day is over.")
		return
		
	tick.emit(current_minute, minute_delta)
	
	if current_minute > time_close * 60:
		print("Park is closed.")
		park_open = false
	
