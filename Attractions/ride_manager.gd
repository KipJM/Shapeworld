extends Node
class_name RideManager

@export var ride_popularity: Dictionary[Ride, float]


func get_random_ride() -> Ride:
	return WeightedRandom.get_weighted_random(ride_popularity)
	
