extends CharacterBody2D
@onready var player: CharacterBody2D = $"../Player"
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# Default Movement Stuff
const SPEED = 300.0
const JUMP_VELOCITY = -550.0

# Finite State Machine states
enum State {IDLE, RUN, JUMP, ATTACK, DASH}
var current_state = State.IDLE

# Dash Settings
const DASH_SPEED = 650.0
const DASH_DURATION = 0.2
var dash_direction: float = 1.0
var can_dash: bool = true

#Starting health
var health: float = 500.0

# AI brain model
var brain = ONNXLoader.new() 

func _ready() -> void:
	# Loading the brain
	brain.load_model(ProjectSettings.globalize_path("res://models/bot_brain.onnx"))


func _physics_process(delta: float) -> void:
	
	if not player:
		return
	
	if not is_on_floor() and current_state != State.DASH:
		velocity += get_gravity() * delta;
	
	# x and y relaitve to the player
	var rel_x: float = global_position.x - player.global_position.x
	var rel_y: float = global_position.y - player.global_position.y
	
	#prediction 
	var pred = brain.predict([rel_x/500, rel_y/500])
	execute_actions(pred) # calling the execute_actions function

	move_and_slide()

func take_damage(amount: float, knockback_vector: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	
	velocity = knockback_vector
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if health < 0.0:
		queue_free()

# this function performs movement according to the ais prediction
func execute_actions(pred) -> void:
	
	var actions = decode_actions(pred)
	print("PREDICTIONS PLS BE NORMAL: "+str(actions))
	
	var move = actions[0]
	var jump = actions[1]
	var attack = actions[2]
	var dash = actions[3]
	
	match current_state:
		
		State.IDLE, State.RUN, State.JUMP:
			var direction: float = 0.0 # default is idle
			match move:
				0: direction = 0.0
				1: direction = -1.0
				2: direction = 1.0 # translating the movement into direction
				
			# running stuff
			if direction:
				velocity.x = direction * SPEED
				dash_direction = direction
				animated_sprite_2d.flip_h = (direction < 0)
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
			
			# jumping
			if jump and is_on_floor():
				velocity.y = JUMP_VELOCITY
	
			# Update animation and states
			if not is_on_floor():
				current_state = State.JUMP
				animated_sprite_2d.animation = "Jump"
			elif direction != 0:
				current_state = State.RUN
				animated_sprite_2d.animation = "Run"
			else:
				current_state = State.IDLE
				animated_sprite_2d.animation = "Idle"
				
			# Dashing and hitting things while mmoving
			if dash and can_dash:
				start_dash()
			elif attack:
				start_attack()
		
		State.DASH:
			velocity.x = dash_direction * DASH_SPEED
			velocity.y = 0
			
		State.ATTACK:
			velocity.x = 0
	
func decode_actions(pred) -> Array:
	
	var move_probs = [pred[0],pred[1], pred[2]] # movement probabilities
	var move = 0 # default state is idle
	var max_prob = move_probs[0]
	
	# this finds the actual best prob
	for i in range(1,3):
		if( move_probs[i] > max_prob ):
			move = i # movement becomes the index of the best prob
			max_prob = move_probs[i]
	
	# jumps if jump_prob is > 0.5
	var jump_prob = pred[3]
	var jump = jump_prob > 0.5
	
	# attacks if attack_prob is > 0.5
	var attack_prob = pred[4]
	print("ATTACKPROB: "+str(pred[4]))
	var attack = attack_prob > 0.0
	
	# dashes if dash_prob is > 0.5
	var dash_prob = pred[5]
	var dash = dash_prob > 0.5
	
	return [move, jump, attack, dash] # returns the results

func start_dash() -> void:
	current_state = State.DASH
	can_dash = false
	
	await get_tree().create_timer(DASH_DURATION).timeout
	current_state = State.IDLE
	
	await get_tree().create_timer(0.4).timeout
	can_dash = true
	
func start_attack() -> void:
	
	#var facing = 1
	#if animated_sprite_2d.flip_h: facing = -1
	
	current_state = State.ATTACK
	animated_sprite_2d.animation = "Hit"
	
	await get_tree().create_timer(0.3).timeout
	current_state = State.IDLE
	
