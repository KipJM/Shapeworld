extends MultiMeshInstance3D


@onready var agent_manager: AgentManager = %AgentManager
@onready var fastpass_renderer: MultiMeshInstance3D = $renderer_fastpass

@export_category("Colors")
@export var color_idle: Color
@export var color_going_to_ride: Color
@export var color_queuing: Color
@export var color_on_ride: Color
@export var color_activity: Color
@export var color_leaving: Color

func _ready() -> void:
	multimesh.instance_count = agent_manager.total_daily_agents
	fastpass_renderer.multimesh.instance_count = agent_manager.total_daily_agents

func _process(delta: float) -> void:
	multimesh.visible_instance_count = len(agent_manager.in_park_agents)
	
	var fastpass_agents = []
	
	for i in range(len(agent_manager.in_park_agents)):
		var agent: Agent = agent_manager.in_park_agents[i]
		# Draw agent
		multimesh.set_instance_transform(i, 
		Transform3D(Basis.IDENTITY, Vector3(agent.global_position.x, 0, agent.global_position.z))
		)
		
		match agent.state:
			Agent.AgentState.Idle:
				multimesh.set_instance_color(i, color_idle)
			Agent.AgentState.GoingToRide:
				multimesh.set_instance_color(i, color_going_to_ride)
			Agent.AgentState.Queuing:
				multimesh.set_instance_color(i, color_queuing)
			Agent.AgentState.OnRide:
				multimesh.set_instance_color(i, color_on_ride)
			Agent.AgentState.Activity:
				multimesh.set_instance_color(i, color_activity)
			Agent.AgentState.Leaving:
				multimesh.set_instance_color(i, color_leaving)
			Agent.AgentState.Left:
				multimesh.set_instance_color(i, color_leaving)
				
		if len(agent.fastpasses) > 0:
			fastpass_agents.append(agent)

	# fastpass ball
	fastpass_renderer.multimesh.visible_instance_count = len(fastpass_agents)
	for i in range(len(fastpass_agents)):
		var agent: Agent = agent_manager.in_park_agents[i]
		fastpass_renderer.multimesh.set_instance_transform(i, 
			Transform3D(Basis.IDENTITY, Vector3(agent.global_position.x, 0, agent.global_position.z))
		)
