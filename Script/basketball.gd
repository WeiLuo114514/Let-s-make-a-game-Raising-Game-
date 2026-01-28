extends Node2D

# ========== 核心配置（修正+补充） ==========
# 预加载篮球场景（修正：从字符串改为PackedScene预加载）
@export var basketball_scene: PackedScene
# 动画播放器（绑定到场景中的AnimationPlayer节点）
@export var animation : AnimationPlayer
# 随机掉落间隔（秒）
@export var min_random_time: float = 1.0  
@export var max_random_time: float = 8.0  
# 篮球目标区域范围（固定：165,300 到 1700,700）
var target_area_min: Vector2 = Vector2(165, 300)
var target_area_max: Vector2 = Vector2(1700, 700)
var targer_position: Vector2 = Vector2.ZERO
var spawn_position: Vector2 = Vector2.ZERO

# 内部变量
var drop_timer: Timer  # 全局初始掉落定时器
var is_basketball_clickable: bool = false  

func _ready() -> void:
	targer_position = _get_random_target_pos()
	spawn_position = _get_spawn_pos(targer_position)
	self.global_position = spawn_position
	basketball_scene = load("res://item/basketball.tscn")
	# 初始化随机数种子（必须，否则随机值固定）
	randomize()
	# 1. 创建全局掉落定时器（控制第一个篮球的随机掉落时间）
	drop_timer = Timer.new()
	drop_timer.one_shot = true
	drop_timer.timeout.connect(_on_drop_timer_timeout)
	add_child(drop_timer)
	var random_delay = randf_range(min_random_time, max_random_time)
	drop_timer.wait_time = random_delay
	drop_timer.start()

# ========== 核心：生成随机目标位置 + 计算生成位置 ==========
func _get_random_target_pos() -> Vector2:
	# 在(165,300)~(1700,700)范围内生成随机目标坐标
	var random_x = randf_range(target_area_min.x, target_area_max.x)
	var random_y = randf_range(target_area_min.y, target_area_max.y)
	return Vector2(random_x, random_y)
func _get_spawn_pos(target_pos: Vector2) -> Vector2:
	# 生成位置 = 目标位置上方1000像素（屏幕外等待）
	return Vector2(target_pos.x, target_pos.y - 1000)

func _on_drop_timer_timeout() -> void:
	if basketball_scene == null:
		print("⚠️ 未配置篮球场景！请在编辑器绑定PackedScene")
		return
	# 标记篮球不可点击（动画完成前禁止交互）
	is_basketball_clickable = false
	# 方式1：用Tween实现平滑掉落（替代硬编码动画，可和你的预设动画结合）
	var move_tween = create_tween()
	# 掉落时长2秒（可调整），正弦缓动更自然
	move_tween.tween_property(self, "global_position", targer_position, 0.4)
	move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# 等待掉落完成后，播放你的预设动画 + 启用点击
	await move_tween.finished
	# 播放你预设的落地动画（替换为你的动画名）
	if animation:
		animation.play("start")
	# 等待动画完成（假设你的"start"动画时长1秒，可根据实际调整）
	await animation.animation_finished
	# 标记篮球可点击
	is_basketball_clickable = true

func __input_event(event: InputEvent) -> void:
	# 仅处理鼠标左键点击 + 篮球可点击状态
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and is_basketball_clickable :
		on_basketball_clicked()

func on_basketball_clicked() -> void:
	# 1. 标记当前篮球不可点击
	is_basketball_clickable = false
	AudioManager.play_SFX(GameData.cxk_sound)
	var parent = get_parent()
	for i in randi_range(10,40):
		parent.total_count.add_number(self.position)
		await get_tree().create_timer(0.1).timeout
	# 2. 生成新篮球（无需全局定时器，新篮球独立等待掉落）
	var new_ball = basketball_scene.instantiate()
	parent.add_child(new_ball)
	if animation:
		animation.play("fade")

func play_sfx():
	var chicken_audio_stream = load("res://audio/鸡叫.mp3")
	AudioManager.play_SFX(chicken_audio_stream)
