extends Control

func _ready():
	print("Battle started")

func _on_attack_btn_pressed():
	print("You attacked")
	_return_to_world()

func _on_run_btn_pressed():
	print("You ran away")
	_return_to_world()

func _return_to_world():
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")
