extends CharacterBody2D

var health: float = 50.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta;
		
	velocity.x = move_toward(velocity.x, 0, 800.0 * delta)
	
	move_and_slide()

func take_damage(amount: float, knockback_vector: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	
	velocity = knockback_vector
	
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if health < 0.0:
		queue_free()
