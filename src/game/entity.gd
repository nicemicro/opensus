extends KinematicBody2D

# this script acts as the frontend for the characters/controls the character node

# --Public Variables--

# network id corresponding to this character
var networkId: int setget setNetworkId, getNetworkId

var mainCharacter: bool = false
enum LookDirections {LEFT, RIGHT, UP, DOWN}
var lookDirection: int = LookDirections.RIGHT
var shouldBeVisible: bool = true
var fading: bool = false
const fadingSpeed: int = 5

onready var characterElements = $CharacterElements
onready var nameLabel = $Name
onready var skeleton = $CharacterElements/Skeleton

# --Private variables--
var _maxSpeed: float = 5
var _acceleration: float = 1
var _speed: float = 0
var _direction: Vector2 = Vector2(0, 0)

# the CharacterResource corresponding to this character node
var _characterResource: CharacterResource

func _ready() -> void:
	nameLabel.text = _characterResource.characterName

func _process(delta: float) -> void:
	if fading:
		_modulate_fade(delta)

func _modulate_fade(delta: float) -> void:
	var alpha: float
	alpha = modulate[3]
	if shouldBeVisible:
		if alpha == 0:
			visible = true
		alpha += fadingSpeed * delta
	else:
		alpha -= fadingSpeed * delta
	alpha = max(min(1, alpha), 0)
	modulate = Color(1, 1, 1, alpha)
	if alpha == 0 and not shouldBeVisible:
		visible = false
		fading = false
	if alpha == 1 and shouldBeVisible:
		fading = false

func setNetworkId(newId: int) -> void:
	networkId = newId

func getNetworkId() -> int:
	return networkId

func getCharacterName() -> String:
	return _characterResource.characterName

# get the character node that corresponds to this CharacterResource
func getCharacterResource() -> CharacterResource:
	return _characterResource

# set the character node that corresponds to this CharacterResource
func setCharacterResource(newCharacterResource: CharacterResource) -> void:
	# if there is already a character node assigned to this resource
	if _characterResource != null:
		printerr("Assigning a new CharacterResource to a character node that already has one")
		assert(false, "Should be unreachable")
	_characterResource = newCharacterResource

func setMainCharacter(main: bool = true) -> void:
	mainCharacter = main

func setMovementParams(newMaxSpeed: float, newAcceleration: float):
	_maxSpeed = newMaxSpeed
	_acceleration =  newAcceleration

func _moveCommand(delta: float, movementVec: Vector2) -> Vector2:
	# set lookDirection to match the movementVec
	# using the look direction setter here to make it easier to react to
	# 	a changing look direction
	## Sets look direction
	setLookDirection(_getLookDirFromVec(movementVec))
	# multiply the movement vec by speed
	if movementVec.length() > 0:
		_direction = movementVec.normalized()
		_speed += _acceleration * delta
		_speed = min(_speed, _maxSpeed)
		skeleton.stateMachine.travel("Walk")
	else:
		_speed -= _acceleration * delta
		_speed = max(0, _speed)
		skeleton.stateMachine.travel("Idle")
	# move_and_slide() returns the actual motion that happened, store it
	# 	in amountMoved
	## Calculate and execute actual motion
	var amountMoved: Vector2 = move_and_slide(_direction * _speed)
	# return the actual movement that happened
	return amountMoved

# set the position of the player
func setPosition(newPos: Vector2) -> void:
	## If movement occured
	if newPos != position:
		## Update look direction based on movement
		setLookDirection(_getLookDirFromVec(newPos - position))
	## Set new position
	position = newPos

# set the direction the character is looking
func setLookDirection(newLookDirection: int) -> void:
	lookDirection = newLookDirection
	# very placeholder code just to display the look direction by
	# 	changing where the placeholder triangle is pointing
	# this should eventually be moved into a separate script that handles
	# 	animations and stuff
	# the angle to set the rotation of the triangle to
	var xScale: int = 0
	match lookDirection:
		LookDirections.LEFT:
			xScale = -1
		LookDirections.RIGHT:
			xScale = 1
	if characterElements != null and xScale != 0:
		characterElements.scale.x = xScale

func fadeInOut(fadeIn: bool):
	if fadeIn == shouldBeVisible:
		return
	shouldBeVisible = fadeIn
	fading = true

func _getLookDirFromVec(vec: Vector2) -> int:
	# this prioritizes looking left and right over up and down (like in
	# 	among us and other games)
	if vec.x == 0 and vec.y == 0:
		return lookDirection
	var newlookDirection: int = LookDirections.RIGHT
	if vec.y < 0:
		newlookDirection = LookDirections.UP
	if vec.y > 0:
		newlookDirection = LookDirections.DOWN
	if vec.x < 0:
		newlookDirection = LookDirections.LEFT
	if vec.x > 0:
		newlookDirection = LookDirections.RIGHT
	return newlookDirection

# set the outfit of the character
func setAppearance(outfit: Dictionary, colors: Dictionary) -> void:
	if outfit.empty() or colors.empty():
		return
	var outfitPaths: Dictionary = {}
	for partGroup in outfit: ## For each customizable group
		var selectedLook: String = outfit[partGroup]
		for part in Appearance.groupCustomization[partGroup]: ## For each custom sprite
			var filePath: String = Appearance.customSpritePaths[part][selectedLook]
			## Saves sprite file path
			outfitPaths[part] = filePath
	
	## Applies appearance to its skeleton
	skeleton.applyAppearance(outfitPaths, colors)
