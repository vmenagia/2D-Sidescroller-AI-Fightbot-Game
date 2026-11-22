extends TextureProgressBar

@export var bot: CharacterBody2D
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	bot.healthChanged.connect(update)
	update()

func update() -> void:
	value = bot.health 

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
