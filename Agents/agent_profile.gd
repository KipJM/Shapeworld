extends Node

class_name AgentProfile

# Parameters describing behavior of Agent Archetypes
# Parameters
	# stay_time_preference: mean total park stay time, actual value will be draw from a 
	#   normal distribution. 
	# allow_repeats: dictates whether agent will repeat an attraction or only visit an
	#   an attraction once
	# attraction_preference: value between 0 and 1, larger values influence agents decision to
	#   vists attractions, smaller values influence agents decision to vist attractions
	# wait_threshold: how many minutes agent is willing to wait in a queue, if a wait time is
	#   longer than this the agent will seek and expedited pass
	# percent_children: percent of agents with this archetype that will be children
	# percent_adults: percent of agents with this archetype that will be adults

## mean total park stay time, actual value will be draw from a normal distribution. 
@export var stay_time_preference: int
## dictates whether agent will repeat an attraction or only visit an attraction once
@export var allow_repeats: bool
## value between 0 and 1, larger: guest want to go on rides more; smaller: guest want to do activities more
@export_range(0,1, 0.1) var attraction_preference: float
## how many minutes agent is willing to wait in a queue, if a wait time is
## longer than this the agent will seek an expedited pass
@export var wait_threshold: int
