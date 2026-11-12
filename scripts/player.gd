extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var jump_sound: AudioStreamPlayer2D = $jumpSound
@onready var hitbox_collision: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var sparring_recorder: Node2D = $"../SparringRecorder"

# Finite State Machine states
enum State {IDLE, RUN, JUMP, ATTACK, DASH}
var current_state = State.IDLE

# Default Movement Stuff
const SPEED = 300.0
const JUMP_VELOCITY = -550.0

# Dash Settings
const DASH_SPEED = 650.0
const DASH_DURATION = 0.2
var dash_direction: float = 1.0
var can_dash: bool = true

#Starting health
var health: float = 500.0

func _physics_process(delta: float) -> void:
	
	# Add the gravity.
	if not is_on_floor() and current_state != State.DASH:
		velocity += get_gravity() * delta;

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
			elif Input.is_action_just_pressed("hit"):
				start_attack()
		
		State.DASH:
			velocity.x = dash_direction * DASH_SPEED
			velocity.y = 0
			
		State.ATTACK:
			velocity.x = 0

	move_and_slide()

func start_dash() -> void:
	current_state = State.DASH
	can_dash = false
	
	await get_tree().create_timer(DASH_DURATION).timeout
	current_state = State.IDLE
	
	await get_tree().create_timer(0.4).timeout
	can_dash = true
	
func start_attack() -> void:
	
	var facing = 1
	if animated_sprite_2d.flip_h: facing = -1
	$Hitbox.scale.x = facing
	
	hitbox_collision.disabled = false
	
	current_state = State.ATTACK
	animated_sprite_2d.animation = "Hit"
	await get_tree().create_timer(0.3).timeout
	
	hitbox_collision.disabled = true
	current_state = State.IDLE

func _on_hitbox_area_entered(area: Area2D) -> void:
	var target = area.get_parent()
	if target and target.has_method("take_damage") and target != self:
		var hit_direction: float = 1.0 if target.global_position.x > global_position.x else -1.0
		var knockback: Vector2 = Vector2(hit_direction * 400.0, -200.0)
		target.take_damage(15.0, knockback)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("record"):
		if sparring_recorder.is_recording:
			sparring_recorder.stop_recording()
		else:
			sparring_recorder.start_recording()
			
func take_damage(amount: float, knockback_vector: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	
	velocity = knockback_vector
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if health < 0.0:
		queue_free()
