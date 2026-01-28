extends RichTextLabel

# 预加载浮动数字场景
var floating_number_screen := preload("res://floating_number.tscn")
# 持续点击定时器（控制0.1秒触发一次点数增加）
var click_timer: Timer
# ========== 新增：升级按钮相关定时器 ==========
var buy_exp_timer: Timer  # 控制每0.2秒尝试购买经验
var long_press_timer: Timer  # 检测是否持续按压满2秒（防短按误触发）

@export var rate_label : RichTextLabel
@export var buy_EXP_need_label : Label
@export var exp_progress_label : Label
@export var exp_progress_bar : ProgressBar  # 经验进度条

# 初始化随机数种子 + 定时器
func _ready() -> void:
	randomize()
	# 初始化持续点击定时器（加点数）
	click_timer = Timer.new()
	click_timer.wait_time = 0.2  # 0.2秒触发一次
	click_timer.one_shot = false  # 循环触发（非一次性）
	click_timer.timeout.connect(_on_click_timer_timeout)  # 绑定超时回调
	add_child(click_timer)  # 将定时器加入节点树
	
	# ========== 初始化购买经验定时器 ==========
	buy_exp_timer = Timer.new()
	buy_exp_timer.wait_time = 0.2  # 每0.2秒尝试购买一次
	buy_exp_timer.one_shot = false  # 循环触发
	buy_exp_timer.timeout.connect(_on_buy_exp_timer_timeout)  # 绑定购买回调
	add_child(buy_exp_timer)  # 加入节点树
	
	# ========== 新增：初始化长按检测定时器（2秒） ==========
	long_press_timer = Timer.new()
	long_press_timer.wait_time = 0.8  # 需持续按压2秒才触发
	long_press_timer.one_shot = true  # 一次性定时器（仅触发一次）
	long_press_timer.timeout.connect(_on_long_press_timeout)  # 长按超时回调
	add_child(long_press_timer)
	
	# 初始化显示
	update_buy_need_label()
	update_rate_label()
	update_exp_progress_label()

# ========== 定时器回调（每0.1秒触发一次点数增加） ==========
func _on_click_timer_timeout() -> void:
	# 获取当前鼠标相对于本节点的位置（适配Control节点坐标）
	var current_mouse_pos = get_local_mouse_position()
	AudioManager.play_SFX(GameData.clicked_sound)
	# 调用点数增加逻辑
	add_number(current_mouse_pos)

# ========== 购买经验定时器回调（每0.2秒尝试购买） ==========
func _on_buy_exp_timer_timeout() -> void:
	# 直接调用购买经验函数
	buy_EXP()

# ========== 新增：长按2秒超时回调（触发连续购买） ==========
func _on_long_press_timeout() -> void:
	# 长按满2秒：先执行一次购买，再启动连续购买定时器
	buy_EXP()
	buy_exp_timer.start()
	print("🔄 已持续按压2秒，开始自动升级（每0.2秒一次）")

# ========== 核心：动态计算当前奖励概率（随经验/等级变化） ==========
func _get_current_reward_rates() -> Dictionary:
	# 1. 获取当前等级的基础概率
	var level = min(GameData.player_level, len(GameData.level_base_rates) - 1)
	var base_rates = GameData.level_base_rates[level]
	var rate_1 = base_rates[0]
	var rate_2 = base_rates[1]
	var rate_max = base_rates[2]
	# 2. 根据当前经验值提升概率（小幅）
	var Exp = GameData.player_EXP
	# 每1点经验，+2概率+0.05%，+max概率+0.03%，+1概率等额减少
	var rate_2_add = Exp * 0.0005  # 0.05% = 0.0005
	var rate_max_add = Exp * 0.0003 # 0.03% = 0.0003
	rate_2 += rate_2_add
	rate_max += rate_max_add
	rate_1 -= (rate_2_add + rate_max_add)
	# 3. 概率边界保护（避免+1概率过低，游戏体验差）
	rate_1 = max(rate_1, 0.5)  # +1概率最低50%
	# 重新归一化（防止概率总和超出1）
	var total = rate_1 + rate_2 + rate_max
	rate_1 /= total
	rate_2 /= total
	rate_max /= total
	# 4. 获取当前等级的最大奖励值
	var max_reward = GameData.reward_max_values[level]
	
	return {
		"1": rate_1,
		"2": rate_2,
		str(max_reward): rate_max,
		"max_value": max_reward
	}

# ========== 随机获取奖励（替代原固定列表） ==========
func _get_random_reward() -> Dictionary:
	var rates = _get_current_reward_rates()
	var max_value = rates["max_value"]
	var total_prob = 0.0
	
	# 构建奖励列表（动态）
	var reward_list = [
		{"value": 1, "prob": rates["1"], "color": "#FFFFFF"},
		{"value": 2, "prob": rates["2"], "color": "green"},
		{"value": max_value, "prob": rates[str(max_value)], "color": "cyan"}
	]
	
	# 概率随机选择（逻辑同之前）
	for reward in reward_list:
		total_prob += reward.prob
	var random_num = randf() * total_prob
	var current_prob = 0.0
	
	for reward in reward_list:
		current_prob += reward.prob
		if random_num <= current_prob:
			return reward
	# 兜底
	return {"value": 1, "color": "#FFFFFF"}

# ========== 点击/持续按压添加数字（修复核心错误） ==========
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# 修复：用is_pressed()判断按下，而非event.pressed
		if event.is_pressed():
			AudioManager.play_SFX(GameData.clicked_sound)
			add_number(event.position)
			click_timer.start()  # 启动0.1秒循环定时器
		# 修复：用is_released()判断释放，而非event.released
		elif event.is_released():
			click_timer.stop()  # 停止自动加点数

func add_number(pos:Vector2)->void:
	var reward = _get_random_reward()
	var reward_value = reward.value
	var reward_color = reward.color
	
	# 更新总计数
	GameData.total_count += reward_value
	self.text = str(GameData.total_count)
	
	# 创建浮动数字（新增自动销毁，避免内存泄漏）
	var float_number = floating_number_screen.instantiate()
	float_number.text = "[color=%s]+%d[/color]" % [reward_color, reward_value]
	float_number.bbcode_enabled = true
	float_number.position = pos
	var target_position = pos + Vector2(0, -250)  # 向上飘
	add_child(float_number)
	
	# 动画补间
	var move_tween = create_tween()
	move_tween.parallel()
	move_tween.tween_property(float_number, "position", target_position, 0.5)
	move_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	move_tween.tween_property(float_number,"modulate:a",0,0.2)
	move_tween.finished.connect(func():
		float_number.queue_free()  # 动画结束销毁节点
	)

# ========== 生成消耗数值的浮动动画 ==========
func create_cost_float_number(cost: int) -> void:
	# 固定生成位置：屏幕中间(960,540)
	var spawn_pos = Vector2(960, 540)
	# 目标位置：向下飘150像素
	var target_pos = spawn_pos + Vector2(0, 150)
	
	# 创建浮动数字节点
	var cost_float = floating_number_screen.instantiate()
	# 红色减号文本，BBcode设置颜色
	cost_float.text = "[color=#FF4444]-%d[/color]" % cost
	cost_float.bbcode_enabled = true
	cost_float.position = spawn_pos
	add_child(cost_float)
	
	# 向下飘动+渐隐动画（和奖励数字动画风格统一）
	var cost_tween = create_tween()
	cost_tween.parallel()
	cost_tween.tween_property(cost_float, "position", target_pos, 0.5)
	cost_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	cost_tween.tween_property(cost_float, "modulate:a", 0, 0.2)
	cost_tween.finished.connect(func():
		cost_float.queue_free()  # 动画结束销毁，避免内存泄漏
	)

# ========== 升级系统核心功能 ==========
# 更新购买经验所需点数显示
func update_buy_need_label()->void:
	var cost = GameData.get_buy_exp_cost()
	buy_EXP_need_label.text = "需要: %d 点数" % cost

# 更新经验进度显示（含进度条）
func update_exp_progress_label()->void:
	var current_exp = GameData.player_EXP
	var exp_cap = GameData.get_current_exp_cap()
	# 更新文本
	exp_progress_label.text = "经验进度：%d/%d（等级%d）" % [current_exp, exp_cap, GameData.player_level]
	# 更新进度条（关键：设置最大值和当前值）
	exp_progress_bar.max_value = exp_cap
	exp_progress_bar.value = current_exp

# 更新概率显示（动态展示当前概率）
func update_rate_label()->void:
	var rates = _get_current_reward_rates()
	var max_value = rates["max_value"]
	# 概率转百分比，保留1位小数
	var rate_2 = round(rates["2"] * 1000) / 10
	var rate_max = round(rates[str(max_value)] * 1000) / 10
	rate_label.text = "🎲 [color=green]%.1f%% +2 [/color]| [color=cyan]%.1f%% +%d[/color]" % [rate_2, rate_max, max_value]

# 购买经验（核心逻辑：新增消耗数值动画）
func buy_EXP() -> void:
	# 1. 获取消耗点数
	var cost = GameData.get_buy_exp_cost()
	# 2. 检查点数是否足够
	if GameData.total_count < cost:
		print("❌ 点数不足！需要", cost, "点数")
		return
	# 3. 生成消耗数值浮动动画（核心新增）
	create_cost_float_number(cost)
	# 4. 消耗点数，增加经验
	GameData.total_count -= cost
	GameData.player_EXP += 1
	AudioManager.play_SFX(GameData.buy_EXP_sound)
	self.text = str(GameData.total_count)  # 更新总点数显示
	# 5. 检查是否升级
	if GameData.player_EXP >= GameData.get_current_exp_cap():
		GameData.level_up()
	# 6. 更新所有显示（含进度条）
	update_buy_need_label()
	update_exp_progress_label()
	update_rate_label()

func _on_mouse_entered() -> void:
	pass

func _on_mouse_exited() -> void:
	# 停止加点数定时器
	click_timer.stop()
	# 停止升级相关所有定时器（防误触发）
	buy_exp_timer.stop()
	long_press_timer.stop()
	print("🚫 鼠标移出，已停止所有自动操作")
	pass

# ========== 修改：升级按钮按压/释放逻辑（防短按误触发） ==========
func _on_level_up_button_down() -> void:
	# 按钮按下：仅启动长按检测定时器（无立即购买）
	long_press_timer.start()
	print("⏳ 长按检测中（需2秒触发自动升级）")

func _on_level_up_button_button_up() -> void:
	# 按钮释放：停止所有升级相关定时器
	long_press_timer.stop()
	buy_exp_timer.stop()
	print("🛑 已释放按钮，停止自动升级")
