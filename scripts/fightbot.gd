extends CharacterBody2D
@onready var player: CharacterBody2D = $"../Player"
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D

# These are for fighting and to check if the onnx model is loaded
var is_fighting: bool = false
var is_brain_loaded: bool = false

# Default Movement Stuff
const SPEED = 300.0
const JUMP_VELOCITY = -950.0

# Finite State Machine states
enum State {IDLE, RUN, JUMP, ATTACK, DASH, HITSTUN, BLOCK}
var current_state = State.IDLE

# Hitstun stuff
var state_timer: float = 0.0 
const HITSTUN_DURATION = 0.25

# Dash Settings
const DASH_SPEED = 650.0
const DASH_DURATION = 0.2
var dash_direction: float = 1.0
var can_dash: bool = true

#Starting health
var health: float = 500.0

# Attack stuff
var can_attack: bool = true
const ATTACK_STARTUP = 0.13
const ATTACK_ACTIVE = 0.08
const ATTACK_RECOVERY = 0.22
const ATTACK_COOLDOWN = 0.35

# AI brain model
const ONNXInference = preload("res://addons/godot_rl_agents/onnx/csharp/ONNXInference.cs")
var brain

func _ready() -> void:
	# Loading the brain
	hitbox_collision.disabled = true
	brain = ONNXInference.new()
	if FileAccess.file_exists("res://models/bot_brain.onnx"):
		brain.Initialize("res://models/bot_brain.onnx", 1)
		is_brain_loaded = true

func _physics_process(delta: float) -> void:
	
	if not is_instance_valid(player) or not is_brain_loaded:
		current_state = State.IDLE
		animated_sprite_2d.animation = "Idle"
		return
	
	if not is_on_floor() and current_state != State.DASH:
		velocity += get_gravity() * delta;
		
	if(is_fighting):
		# x and y relaitve to the player
		var rel_x: float = (global_position.x - player.global_position.x) / 500.0
		var rel_y: float = (global_position.y - player.global_position.y) / 500.0

		var obs: Array[float] = [rel_x, rel_y]
		var pred = brain.Predict(obs)
		
		if state_timer > 0.0:
			state_timer -= delta 
			if state_timer <= 0.0:
				current_state = State.IDLE
		
		if pred != null:
			execute_actions(pred, delta) # calling the execute_actions function
		
	else:
		current_state = State.IDLE
		animated_sprite_2d.animation = "Idle"

	move_and_slide()

func take_damage(amount: float, knockback_vector: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	
	state_timer = HITSTUN_DURATION
	hitbox_collision.set_deferred("disabled", true)
	current_state = State.HITSTUN
	animated_sprite_2d.animation = "Idle"
	
	velocity = knockback_vector
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if health < 0.0:
		queue_free()

# this function performs movement according to the ais prediction
func execute_actions(pred, delta) -> void:
	
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
		State.HITSTUN:
			velocity.x = move_toward(velocity.x, 0, 800.0*delta)
	
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
	var attack = attack_prob > 0.0 and can_attack
	
	# dashes if dash_prob is > 0.5
	var dash_prob = pred[5]
	var dash = dash_prob > 0.5
	
	return [move, jump, attack, dash] # returns the results

func start_dash() -> void:
	current_state = State.DASH
	can_dash = false
	
	await get_tree().create_timer(DASH_DURATION).timeout
	if current_state == State.DASH:
		current_state = State.IDLE
	
	await get_tree().create_timer(0.4).timeout
	can_dash = true
	
func start_attack() -> void:
	
	can_attack = false
	
	var facing = -1
	if animated_sprite_2d.flip_h: facing = 1
	$Hitbox.scale.x = facing
	
	current_state = State.ATTACK
	animated_sprite_2d.animation = "Hit"
	
	await get_tree().create_timer(ATTACK_STARTUP).timeout
	if current_state != State.ATTACK:
		start_attack_cooldown()
		return
	
	hitbox_collision.disabled = false
	await get_tree().create_timer(ATTACK_ACTIVE).timeout
	hitbox_collision.disabled = true
	
	if current_state != State.ATTACK:
		start_attack_cooldown()
		return
		
	await get_tree().create_timer(ATTACK_RECOVERY).timeout
	if current_state == State.ATTACK:
		current_state = State.IDLE
	
	start_attack_cooldown()
	
func start_attack_cooldown() -> void:
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	can_attack = true
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("record"):
		is_fighting = !is_fighting
	

func _on_hitbox_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	if target and target.has_method("take_damage") and target != self:
		var hit_direction: float = 1.0 if target.global_position.x > global_position.x else -1.0
		var knockback: Vector2 = Vector2(hit_direction * 900.0, -200.0)
		target.take_damage(15.0, knockback)
		apply_hitstop()
		
func apply_hitstop(duration: float = 0.06) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	
func _exit_tree() -> void:
	if brain != null:
		brain.FreeDisposables()
