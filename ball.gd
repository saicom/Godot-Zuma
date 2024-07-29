extends Area2D
class_name Ball

enum BallType {
	Chick,
	Bear,
	Cow,
	Duck,
	Chicken,
	Max
}

var ball_res = {
	BallType.Chick: preload("res://assets/Ball/chick.png"),
	BallType.Bear: preload("res://assets/Ball/bear.png"),
	BallType.Cow: preload("res://assets/Ball/cow.png"),
	BallType.Duck: preload("res://assets/Ball/duck.png"),
	BallType.Chicken: preload("res://assets/Ball/chicken.png"),
}

var direction: Vector2 = Vector2.ZERO
var speed: float = 800
var type: int
var has_collide: bool = false

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	type = randi() %  BallType.Max
	sprite_2d.texture = ball_res[type]
	
func shoot(dir: Vector2, _rotation: float):
	direction = dir
	var canon = get_parent()
	var old_pos = global_position
	canon.remove_child(self)
	canon.get_parent().add_child(self)
	global_position = old_pos
	rotation = _rotation


func _process(delta: float) -> void:
	if direction != Vector2.ZERO:
		position += direction * speed * delta
	if position.x < -100 || position.x > 1920 || position.y < -100 || position.y > 1080:
		queue_free()


func explode():
	sprite_2d.hide()
	animated_sprite_2d.show()
	animated_sprite_2d.play("explode")
	await animated_sprite_2d.animation_finished
	get_parent().queue_free()
