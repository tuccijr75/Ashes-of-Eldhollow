class_name QuestNode
extends Resource

@export var node_id: String = ""
@export var title: String = ""
@export var mode: String = "" # e.g., clause_heist, witness_trial, debt_labyrinth...
@export_multiline var description: String = ""

@export var is_terminal: bool = false

# Conditions for this node to become available.
# Condition DSL handled by ConditionEvaluator.
@export var availability_conditions: Array = []

# Conditions that must be true to complete the node.
@export var completion_conditions: Array = []

# Mutually exclusive locks: when this node completes, set these locks.
# Nodes may specify lock requirements/forbids inside availability_conditions.
@export var locks_add: Array = []

# Outcomes are small effect dictionaries applied to WorldFlags.
# Supported by QuestDirector._apply_effect().
@export var outcomes: Array = []

# Edges: Array of { to: String, when: <cond>, kind: String }
@export var edges: Array = []

func is_valid() -> bool:
	return not node_id.is_empty()
