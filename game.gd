extends Node2D

const BALL_SCENE = preload("res://ball.tscn")

@onready var canon: Node2D = $Canon
@onready var path: Path2D = $Path
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


var spawn_timer: Timer = Timer.new()

var ball_chain: Array[PathFollow2D] = []

var speed: float = 1.0
const BALL_SPACING = 45

var chain_moving = true
var fill_gaps_tween_count = 0
var combo = 0
var combo_timer = 0

signal all_tween_finished

func get_insert_position(area):
	if ball_chain.size() == 0:
		return 0
	for i in range(ball_chain.size()):
		if ball_chain[i].get_child(0) == area:
			return i
	return -1

func insert_ball_into_chain(ball:Ball, insert_pos: int):
	var new_path_follow = PathFollow2D.new()
	ball.direction = Vector2.ZERO
	ball.position = Vector2.ZERO
	ball.rotation = 0
	ball.get_parent().remove_child(ball)
	new_path_follow.add_child(ball)
	path.add_child(new_path_follow)
	new_path_follow.set_progress(ball_chain[insert_pos].progress)
	
	ball_chain.insert(insert_pos, new_path_follow)
	for i in range(insert_pos, -1, -1):
		var cur_ball = ball_chain[i]
		cur_ball.progress += BALL_SPACING
		if i > 0:
			var pre_ball = ball_chain[i - 1]
			if pre_ball.progress - cur_ball.progress > BALL_SPACING:
				break
	
	#检测是否消除
	check_and_remove_matches(insert_pos)
	
func check_and_remove_matches(insert_pos: int):
	var ball_type = ball_chain[insert_pos].get_child(0).type
	var matches = [insert_pos]
	
	#检测前边
	var pre = insert_pos - 1
	while pre >= 0 and ball_chain[pre].get_child(0).type == ball_type:
		matches.append(pre)
		pre -= 1
	#检测后边
	var post = insert_pos + 1
	while post < ball_chain.size() and ball_chain[post].get_child(0).type == ball_type:
		matches.append(post)
		post += 1
	print(matches)	
	if matches.size() >= 3:	#三个以及三个以上消除
		matches.sort()
		matches.reverse()	#从后往前删除，避免索引错误
		var tick = Time.get_ticks_msec()
		if tick - combo_timer < 800:
			combo += 1
		else:
			combo = 1
		combo_timer = tick
		combo = clampi(combo, 1, 7)
		var res = "res://assets/c%d.mp3"%[combo]
		audio_stream_player.stream = load(res)
		audio_stream_player.play()
		for index in matches:
			var ball = ball_chain[index]
			ball_chain.remove_at(index)
			#播放爆炸特效
			ball.get_child(0).explode()
		#判断是否需要快速填补空缺
		fill_gaps(pre)
		return true #返回true表示有球移除
	return false

func fill_gaps(start):
	if ball_chain.size() <= 1:
		return
	var end = start + 1
	chain_moving = false
	var left_color = ball_chain[start].get_child(0).type if start >= 0 and start < ball_chain.size() else null
	var right_color = ball_chain[end].get_child(0).type if end >= 0 and end < ball_chain.size() else null
	if left_color == right_color:	#空隙两端颜色相同就快速靠近
		var target_progress = ball_chain[end].progress + BALL_SPACING
		for i in range(start, -1, -1):
			move_ball_smoothly(ball_chain[i], target_progress)
			target_progress += BALL_SPACING
	#要等待空缺填补动画播放完毕后，再次检测是否有可消除的小球
	if fill_gaps_tween_count > 0:
		await  all_tween_finished
		if check_and_remove_matches(start) == false:	#没有小球消除立即开始移动列
			chain_moving = true
	else:
		chain_moving = true
		
		
func move_ball_smoothly(ball, target_progress):
	fill_gaps_tween_count += 1
	var tween = create_tween()
	tween.tween_property(ball, "progress", target_progress, 0.5).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	await tween.finished
	fill_gaps_tween_count -= 1
	if fill_gaps_tween_count == 0:
		all_tween_finished.emit()

func _on_area_entered(area: Area2D, ball: Ball):
	if ball.has_collide:
		return
	ball.has_collide = true
	#插入球链 1，计算插入的位置 2, 插入并调整其他球的位置
	print("hit ", area)
	var pos = get_insert_position(area)
	if pos == -1:
		return
	call_deferred("insert_ball_into_chain", ball, pos)

func _on_canon_shoot_ball(ball: Ball):
	ball.area_entered.connect(_on_area_entered.bind(ball))

#炮台初始动画
func init_canon():
	canon.shoot_ball.connect(_on_canon_shoot_ball)
	canon.scale = Vector2.ONE * 1.5
	var tween = create_tween()
	tween.tween_property(canon, "scale", Vector2.ONE, 0.5).set_ease(Tween.EASE_IN_OUT)
	
#初始化球链的定时器
func init_spawn_timer():
	spawn_timer.timeout.connect(_on_spawn_timeout)
	spawn_timer.set_one_shot(false)
	spawn_timer.set_wait_time(1.0/speed)
	add_child(spawn_timer)
	spawn_timer.start()

func _on_spawn_timeout():
	#生成新的球体加入球链
	var new_ball = BALL_SCENE.instantiate()
	var path_follow = PathFollow2D.new()
	path.add_child(path_follow)
	path_follow.add_child(new_ball)
	ball_chain.append(path_follow)


func _ready() -> void:
	init_canon()
	init_spawn_timer()
	
	
func _process(delta: float) -> void:
	if ball_chain.size() == 0:
		return
	if chain_moving:
		#消除后有空隙的话，队首的要等后面的球跟上以后再继续移动
		var first_ball_progress = ball_chain[0].progress if ball_chain.size() > 0 else 0
		var last_ball_progress = ball_chain[-1].progress if ball_chain.size() > 0 else 0
		var len = (first_ball_progress - last_ball_progress) / BALL_SPACING
		move_last_ball(delta)		
		if len > ball_chain.size() - 1: #存在空隙
			for i in range(ball_chain.size() - 2, 0, -1):
				var cur_ball = ball_chain[i]
				var pre_ball = ball_chain[i -1]
				cur_ball.progress = ball_chain[i + 1].progress + BALL_SPACING
				if pre_ball.progress - cur_ball.progress > BALL_SPACING:
					break
		else:
			for i in range(ball_chain.size() - 2, -1, -1):
				ball_chain[i].progress = ball_chain[i + 1].progress + BALL_SPACING
	
	if ball_chain.size() > 0 and ball_chain[0].progress_ratio >= 0.99:
		var ball = ball_chain.pop_front()
		ball.queue_free()	
				

func move_last_ball(delta: float):
	if ball_chain.size() > 0:
		var last_ball = ball_chain[-1]
		last_ball.set_progress(last_ball.progress + speed * BALL_SPACING * delta)
