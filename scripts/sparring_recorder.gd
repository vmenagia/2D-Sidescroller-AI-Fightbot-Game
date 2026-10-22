extends Node2D

@export var player: CharacterBody2D
@export var bot: CharacterBody2D

var is_recording: bool = false
var recorded_frames: Array[Dictionary] = []
var timer: float = 0.0
const SAMPLE_RATE: float = 0.1 #10 snapshots per second

func _physics_process(delta: float) -> void:
	if not is_recording or not player or not bot:
		return
		
	timer += delta
	
	if timer >= SAMPLE_RATE:
		record_snapshot()
		
func record_snapshot() -> void:
	# Find the distance between bot and player
	var rel_x: float = (bot.global_position.x - player.global_position.x)/500
	var rel_y: float = (bot.global_position.y - player.global_position.y)/500

	# Movement - Idle, right or left
	var move_action: int = 0 # Idle
	var dir: float = Input.get_axis("right", "left")
	if dir < 0:
		move_action = 1 # Left
	elif dir > 0:
		move_action = 2 # Right

	# these represent whether an action was being performed or not
	var dash_action: int = 1 if Input.is_action_pressed("dash") else 0
	var jump_action: int = 1 if Input.is_action_pressed("jump") else 0
	var hit_action: int = 1 if Input.is_action_pressed("hit") else 0

	# creating the snapshot
	var snapshot = {
		"distance" = [rel_x, rel_y],
		"actions" = [move_action, dash_action, jump_action, hit_action]
	}
	
	recorded_frames.append(snapshot)
	
func start_recording() -> void:
	recorded_frames.clear()
	is_recording = true
	
func stop_recording() -> void:
	is_recording = false
	save_to_disk()
	
func save_to_disk() -> void:
	var file = FileAccess.open("C:/Users/valia/Desktop/Projects/Thesis/sparring_data.json", FileAccess.WRITE)
	
	if file:
		var json_string = JSON.stringify(recorded_frames)
		file.store_string(json_string)
		file.close()
