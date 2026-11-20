extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $jumpSound
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var sparring_recorder: Node2D = $"../SparringRecorder"

# Finite State Machine states
enum State {IDLE, RUN, JUMP, ATTACK, DASH, HITSTUN, BLOCK}
var current_state = State.IDLE

# Hitstun stuff
var state_timer: float = 0.0 
const HITSTUN_DURATION = 0.25

# Default Movement Stuff
const SPEED = 300.0
const JUMP_VELOCITY = -950.0

# Dash Settings
const DASH_SPEED = 650.0
const DASH_DURATION = 0.2
var dash_direction: float = 1.0
var can_dash: bool = true

#Starting health
var health: float = 500.0

# Attack stuff
var can_attack: bool = true
const ATTACK_STARTUP = 0.08
const ATTACK_ACTIVE = 0.08
const ATTACK_RECOVERY = 0.22
const ATTACK_COOLDOWN = 0.35

func _ready() -> void:
	hitbox_collision.disabled = true

func _physics_process(delta: float) -> void:
	
	# Add the gravity.
	if not is_on_floor() and current_state != State.DASH:
		velocity += get_gravity() * delta;

	if state_timer > 0.0:
		state_timer -= delta 
		if state_timer <= 0.0:
			current_state = State.IDLE

	# Managing movement depending on the state we are in
	match current_state:
		# These three consist the basic movement
		State.IDLE, State.RUN, State.JUMP:
			var direction = Input.get_axis("left", "right")
			
			# Moving left and right
			if direction:
				velocity.x = direction * SPEED
				dash_direction = direction
				animated_sprite_2d.flip_h = (direction < 0)
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				
				# Handle jump.
			if Input.is_action_just_pressed("jump") and is_on_floor():
				velocity.y = JUMP_VELOCITY
				jump_sound.play()
				
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
			if Input.is_action_just_pressed("dash") and can_dash:
				start_dash()
			elif Input.is_action_just_pressed("hit") and can_attack:
				start_attack()
			elif Input.is_action_pressed("block"):
				current_state = State.BLOCK	
				animated_sprite_2d.animation = "Block"
				
		
		State.DASH:
			velocity.x = dash_direction * DASH_SPEED
			velocity.y = 0
			
		State.ATTACK:
			velocity.x = 0
			
		State.HITSTUN:
			velocity.x = move_toward(velocity.x, 0, 800.0*delta)
		State.BLOCK:
			velocity.x = 0 
			if not Input.is_action_pressed("block"):
				current_state = State.IDLE

	move_and_slide()

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
	
	var facing = 1
	if animated_sprite_2d.flip_h: facing = -1
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

func _on_hitbox_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	if target and target.has_method("take_damage") and target != self:
		var hit_direction: float = 1.0 if target.global_position.x > global_position.x else -1.0
		var knockback: Vector2 = Vector2(hit_direction * 900.0, -200.0)
		target.take_damage(15.0, knockback)
		apply_hitstop()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("record"):
		if sparring_recorder.is_recording:
			sparring_recorder.stop_recording()
		else:
			sparring_recorder.start_recording()
			
func take_damage(amount: float, knockback_vector: Vector2 = Vector2.ZERO) -> void:
	
	if current_state == State.BLOCK:
		
		modulate = Color.CYAN
		get_tree().create_timer(0.1).timeout.connect(func(): modulate = Color.WHITE)
		
	else:
		health -= amount
	
		velocity = knockback_vector
	
		state_timer = HITSTUN_DURATION
		hitbox_collision.set_deferred("disabled", true)
		current_state = State.HITSTUN
		animated_sprite_2d.animation = "Idle"
	
		modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		modulate = Color.WHITE
	
	if health < 0.0:
		queue_free()

func apply_hitstop(duration: float = 0.06) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
