extends Node2D

const BALL_SCENE = preload("res://ball.tscn")

var cur_ball: Ball

signal shoot_ball(ball: Ball)

func _ready() -> void:
	load_new_ball()

func _process(delta: float) -> void:
	var mouse_position = get_global_mouse_position()
	look_at(mouse_position)
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		shoot()
		
func shoot():
	if cur_ball == null:
		return
	var dir = (get_global_mouse_position() - cur_ball.global_position).normalized()
	cur_ball.shoot(dir, rotation)
	shoot_ball.emit(cur_ball)	
	cur_ball = null
	await get_tree().create_timer(0.3).timeout
	load_new_ball()


func load_new_ball():
	print("new ball")
	cur_ball = BALL_SCENE.instantiate()
	add_child(cur_ball)
	cur_ball.global_position = to_global(Vector2(35, 0))
