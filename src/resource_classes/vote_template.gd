extends Resource
class_name VoteMechanicsTemplate

var active: bool = false
var voteTally: Dictionary = {}

func getVoteTime() -> float:
	return 0.0

func voteOptions() -> Array:
	return Characters.getCharacterKeys()

func votees() -> Array:
	return Characters.getCharacterKeys()

func receiveVote(voterId: int, voteeId: int) -> void:
	voteTally[voterId] = voteeId

func initialize() -> void:
	voteTally = {}
	active = true

func allVoted() -> bool:
	return true

func voteStop() -> void:
	active = false
