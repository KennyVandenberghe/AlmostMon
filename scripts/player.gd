extends CharacterBody2D

@export var speed: float = 120.0

# Encounter tuning
@export var encounter_chance: float = 0.08          # 8% per tile step
@export var encounter_cooldown_time: float = 1.5    # seconds after an encounter

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var encounters: TileMapLayer = $"../Encounters"

var _last_cell: Vector2i = Vector2i(999999, 999999)
var _encounter_cooldown: float = 0.0

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * speed
	move_and_slide()

	_update_animation(direction)

	_encounter_cooldown -= delta
	if direction == Vector2.ZERO:
		return

	_check_encounter_tile()

func _update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		sprite.stop()
		return

	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			sprite.play("walk_right")
		else:
			sprite.play("walk_left")
	else:
		if direction.y > 0:
			sprite.play("walk_down")
		else:
			sprite.play("walk_up")

func _check_encounter_tile() -> void:
	# Only roll when entering a new tile cell
	var cell := encounters.local_to_map(global_position)
	if cell == _last_cell:
		return
	_last_cell = cell

	# Cooldown prevents instant re-triggers
	if _encounter_cooldown > 0.0:
		return

	# If there is no tile painted in Encounters at this cell, no encounter roll
	var tile_data := encounters.get_cell_tile_data(cell)
	if tile_data == null:
		return

	# We stepped on an encounter tile: roll chance
	if randf() < encounter_chance:
		_encounter_cooldown = encounter_cooldown_time
		print("Encounter!")
		_start_battle()
		# Next step will be: call a function to start Battle scene
		
func _start_battle() -> void:
	# store where we were so we can restore after battle
	GameState.return_player_pos = global_position
	get_tree().change_scene_to_file("res://scenes/battle/Battle.tscn")
