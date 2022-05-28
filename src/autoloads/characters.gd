extends Node

# this autoload manages character nodes and character resources

## HOW TO USE CHARACTER MANAGER
## Example: creating a character
## network id to use when creating a character (12345 is just an example id and
## most likely not what you will be using)
#	var networkId: int = 12345
#
## have the character manager create a character using that network id
#	Characters.createCharacter(networkId, name)
#	 > returns a CharacterResource corresponding to the character that was just
#		created


# --Public Variables--

# path to character scene
const CHARACTER_SCENE_PATH: String = "res://game/character/character.tscn"
var characterScene: PackedScene = preload(CHARACTER_SCENE_PATH)

# --Private Variables--

# _characterNodes and _characterResources are private variables because only this 
# 	script should be editing them

# stores character resources keyed by network id
# {<network id>: <character resource>}
var _characterResources: Dictionary = {}

# Stores data to be sent through the network during the next broadcast
var broadcastDataQueue: Array = []
var serverSendQueue: Array = []

var _positionSyncsPerSecond: int = 30
var _timeSincePositionSync: float = 0.0

# --Public Functions--

# create a new character for the given network id
# returns the character resource because I think it would be more useful than
# 	the character node - TheSecondReal0
func createCharacter(networkId: int, name: String) -> CharacterResource:
	## Create character resource
	var characterResource: CharacterResource = _createCharacterResource(networkId)
	## Assign character node to resource
	characterResource.createCharacterNode()
	## Register character node and resource
	_registerCharacterResource(networkId, characterResource)
	## Set the name of the character
	characterResource.setCharacterName(name)
	var myId: int = get_tree().get_network_unique_id()
	## If own character is added
	if networkId == myId:
		## Apply appearance to character
		characterResource.setAppearance(Appearance.currentOutfit, Appearance.currentColors)
		## Send my character data to server
		sendOwnCharacterData()
	## Return character resource
	return characterResource

# create a character node, this function is used when creating a new character
func createCharacterNode(networkId: int = -1) -> KinematicBody2D:
	## instance character scene
	var characterNode: KinematicBody2D = characterScene.instance()
	# set its network id
	characterNode.networkId = networkId
	# here is where we would set its player name, but that is not implemented yet
	return characterNode

# get character node for the input network id
func getCharacterNode(id: int) -> Node:
	return getCharacterResource(id).getNode()

# get character resource for the input network id
func getCharacterResource(id: int) -> CharacterResource:
	# if there is no character node corresponding to this network id
	if not id in _characterResources:
		# throw an error
		printerr("Trying to get a nonexistant character resource with network id ", id)
		# crash the game (if running in debug mode) to assist with debugging
		assert(false, "Should be unreachable")
		# if running in release mode, return null
		return null
	return _characterResources[id]
	
func removeCharacterResource(id: int) -> void:
	# if there is no character node corresponding to this network id
	if not id in _characterResources:
		# throw an error
		printerr("Trying to get a nonexistant character resource with network id ", id)
		# crash the game (if running in debug mode) to assist with debugging
		assert(false, "Should be unreachable")
		# if running in release mode, return
		return
	_characterResources.erase(id)

func getMyCharacterNode() -> Node:
	var id: int = get_tree().get_network_unique_id()
	if not id in _characterResources:
		return null
	return getMyCharacterResource().getNode()

func getMyCharacterResource() -> CharacterResource:
	var id: int = get_tree().get_network_unique_id()
	if not id in _characterResources:
		return null
	return _characterResources[id]

func getCharacterResources() -> Dictionary:
	return _characterResources

func getCharacterKeys() -> Array:
	return _characterResources.keys()

# --Private Functions--

# create a character resource, this function is used when creating a new character
func _createCharacterResource(networkId: int = -1) -> CharacterResource:
	## instance a new CharacterResource object
	var characterResource: CharacterResource = CharacterResource.new()
	# set its network id
	characterResource.networkId = networkId
	# here is where we would set its player name, but that is not implemented yet
	return characterResource

# add a character resource to the characterResources dictionary
func _registerCharacterResource(id: int, characterResource: CharacterResource) -> void:
	# if there is already a character node for this network id
	if id in _characterResources:
		# throw an error
		printerr("Registering a character resource that already exists, network id: ", id)
		assert(false, "Should be unreachable")
	## Register character resource for id
	_characterResources[id] = characterResource

# ----------- PLAYER DATA SYNCING-----------

# --Universal Functions--

func _process(delta: float) -> void:
	if not TransitionHandler.isPlaying():
		return
	_timeSincePositionSync += delta
	## Only proceed if enough time passed
	if _timeSincePositionSync < 1.0 / _positionSyncsPerSecond:
		return
	## Reset position sync timer
	_timeSincePositionSync = 0.0
	## If server
	if Connections.isClientServer() or Connections.isDedicatedServer():
		## Collect all character positions
		var positions: Dictionary = {}
		for characterId in _characterResources:
			positions[characterId] = _characterResources[characterId].getPosition()
		## Apply received character Data
		if len(serverSendQueue) > 0:
			receiveCharacterDataServer(1, serverSendQueue)
			serverSendQueue = []
		## Broadcast all character positions and data
		#if len(broadcastDataQueue) > 0:
			#print_debug(broadcastDataQueue)
		rpc("_updateAllCharacterData", positions, broadcastDataQueue)
		broadcastDataQueue = []
	## If client
	elif Connections.isClient():
		if not Connections.getMyId() in _characterResources:
			return
		## Send own character position to server
		_sendMyCharacterDataToServer()
	else:
		assert(false, "Unreachable")

## --Client functions

func requestCharacterData() -> void:
	## Call server to send all character data
	rpc_id(1, "sendAllCharacterData")

# puppet keyword means that when this function is used in an rpc call
# 	it will only be run on client
puppet func _updateAllCharacterData(positions: Dictionary, characterData: Array) -> void:
	var myId: int = get_tree().get_network_unique_id()
	## Loop through all characters
	for characterId in positions:
		# if this position is for this client's character
		if characterId == myId:
			# don't update its position
			continue
		## Set the position for the character
		getCharacterResource(characterId).setPosition(positions[characterId])
	## Decompose character data
	#if len(characterData) > 0:
	#	print_debug(characterData)
	for data in characterData:
		## If recipient is me
		if data["to"] == myId or data["to"] == -1:
			## Apply data
			receiveCharacterDataClient(data["id"], data["data"])

func sendOwnCharacterData() -> void:
	var id: int = get_tree().get_network_unique_id()
	## Get own character resource
	var characterRes: CharacterResource
	characterRes = Characters.getCharacterResource(id)
	## Get own character outfit data
	var characterData: Dictionary = {}
	characterData["outfit"] = characterRes.getOutfit()
	characterData["colors"] = characterRes.getColors()
	## Save data to be sent to the server
	serverSendQueue.append(characterData)

puppet func receiveCharacterDataClient(id: int, characterData: Dictionary) -> void:
	## Set character data on game scene
	var gameScene: Node = TransitionHandler.gameScene
	gameScene.setCharacterData(id, characterData)

## --Server Functions--

master func sendAllCharacterData() -> void:
	## Get all character resourcse
	var characterRes: Dictionary = {}
	characterRes = getCharacterResources()
	## For each character
	for player in characterRes:
		## Collect character outfit data
		## and prepare to send back to sender
		var characterData: Dictionary = {}
		var outfit: Dictionary = characterRes[player].getOutfit()
		var colors: Dictionary = characterRes[player].getColors()
		if len(outfit) > 0:
			characterData["outfit"] = outfit
		if len(colors) > 0:
			characterData["colors"] = colors
		if len(characterData) > 0:
			var senderId: int = get_tree().get_rpc_sender_id()
			var dataSend: Dictionary = {"to": senderId, "id": player, "data": characterData}
			broadcastDataQueue.append(dataSend)
	#print_debug(characterRes)
	#print_debug(broadcastDataQueue)

func receiveCharacterDataServer(senderId: int, characterData: Array) -> void:
	var gameScene: Node2D = TransitionHandler.gameScene
	## Decompose and compile received data
	if len(characterData) == 0:
		return
	var compiledData: Dictionary = {}
	for element in characterData:
		for key in element:
			compiledData[key] = element[key]
	# Here the server could check and modify the data if necessary
	## Sets character data for the character requested
	gameScene.setCharacterData(senderId, compiledData)
	## Save data for broadcast
	var dataSend: Dictionary = {"to": -1, "id": senderId, "data": compiledData}
	broadcastDataQueue.append(dataSend)
	#print_debug(broadcastDataQueue)

# receive a client's position
# master keyword means that this function will only be run on the server when RPCed
master func _receiveCharacterDataFromClient(newPos: Vector2, characterData: Array) -> void:
	var sender: int = get_tree().get_rpc_sender_id()
	## Set character position
	_updateCharacterPosition(sender, newPos)
	## Handle additional received data
	receiveCharacterDataServer(sender, characterData)

# update a character's position
func _updateCharacterPosition(networkId: int, characterPos: Vector2) -> void:
	#print("updating position of ", networkId, " to ", characterPos)
	## if position is for own character, exit
	if networkId == get_tree().get_network_unique_id():
		# don't update its position
		return
	## Set the position for character
	getCharacterResource(networkId).setPosition(characterPos)

# --Client Functions

# send the position if this client's character to the server
func _sendMyCharacterDataToServer() -> void:
	#print("sending my position to server")
	## Send own character position 
	## and custom data to server
	var myPosition: Vector2 = getMyCharacterResource().getPosition()
	rpc_id(1, "_receiveCharacterDataFromClient", myPosition, serverSendQueue)
	serverSendQueue = []
