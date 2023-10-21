extends Control

onready var itemIcon: Sprite = $ItemSprite
onready var pickUpButton: TextureButton = $Button

var item: ItemResource setget setItemResource, getItemResource

func _ready():
	assert(item != null, "The item should be set right when this scene is instanced.")
	itemIcon.texture = item.getHudTexture()
	itemIcon.scale = item.getHudTextureScale()

func setItemResource(newItem: ItemResource) -> void:
	item = newItem

func getItemResource() -> ItemResource:
	return item

func _on_Button_button_down():
	item.attemptPickUp()
