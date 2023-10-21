extends KinematicBody2D

# --Private Variables--
# the item resource corresponding to this item node
var _itemResource: ItemResource

onready var _sprite: Sprite = $Sprite

# --Public Variables--

# returns the name of this item (for ex. "Wrench")
func getName() -> String:
	return _itemResource.getName()

func setItemResource(newItemResource: ItemResource):
	if _itemResource != null:
		assert(false, "Assigning an item resource to an item node that already has one")
	_itemResource = newItemResource
	if _itemResource.getTexture() != null:
		call_deferred("setSprite")

func setSprite():
	_sprite.texture = _itemResource.getTexture()
	_sprite.scale = _itemResource.getTextureScale()
	rotation_degrees = _itemResource.getRotationDegrees()

# returns the item resource corresponding to this item node
func getItemResource() -> ItemResource:
	return _itemResource

# returns which character resource is holding this item (null if dropped)
func getHolder() -> CharacterResource:
	return _itemResource.getHolder()

# returns whether or not the item is dropped
func isDropped() -> bool:
	return _itemResource.isDropped()
