## PRModelLab.gd
## PR (Profit-Relationship) 模型交易实验室
## 
## 功能：可视化调试 AI 的 PR 效用计算逻辑
## - 全滑条控制：无需键盘输入
## - 实时预览：参数变化立即反映到公式显示
## - 提交执行：触发真正的情绪演化

class_name PRModelLab
extends Control


## ===== 节点引用 =====

# 左面板：AI 脑图
@onready var sf_slider: HSlider = $HSplitContainer/LeftPanel/StrategyFactorGroup/SFSlider
@onready var sf_value_label: Label = $HSplitContainer/LeftPanel/StrategyFactorGroup/SFValueLabel
@onready var batna_slider: HSlider = $HSplitContainer/LeftPanel/BATNAGroup/BATNASlider
@onready var batna_value_label: Label = $HSplitContainer/LeftPanel/BATNAGroup/BATNAValueLabel
@onready var sentiment_slider: HSlider = $HSplitContainer/LeftPanel/SentimentGroup/SentimentSlider
@onready var sentiment_value_label: Label = $HSplitContainer/LeftPanel/SentimentGroup/SentimentValueLabel
@onready var volatility_slider: HSlider = $HSplitContainer/LeftPanel/VolatilityGroup/VolatilitySlider
@onready var volatility_value_label: Label = $HSplitContainer/LeftPanel/VolatilityGroup/VolatilityValueLabel

# 中面板：提案构造器
@onready var p_slider: VSlider = $HSplitContainer/CenterPanel/SliderContainer/ProfitGroup/PSlider
@onready var p_value_label: Label = $HSplitContainer/CenterPanel/SliderContainer/ProfitGroup/PValueLabel
@onready var r_slider: VSlider = $HSplitContainer/CenterPanel/SliderContainer/RelationshipGroup/RSlider
@onready var r_value_label: Label = $HSplitContainer/CenterPanel/SliderContainer/RelationshipGroup/RValueLabel
@onready var formula_display: RichTextLabel = $HSplitContainer/CenterPanel/FormulaDisplay
@onready var submit_button: Button = $HSplitContainer/CenterPanel/SubmitButton

# 右面板：历史日志
@onready var history_log: RichTextLabel = $HSplitContainer/RightPanel/HistoryLog

# 屏幕闪烁反馈
@onready var screen_flash: ColorRect = $ScreenFlash


## ===== 内部状态 =====

## AI 大脑实例 (独立于游戏主循环)
var ai_brain: RefCounted = null

## 当前回合数
var current_round: int = 0

## GapLCardData 脚本引用
var GapLCardDataScript: GDScript = null


## ===== 生命周期 =====

func _ready() -> void:
	_init_ai_brain()
	_connect_signals()
	_sync_ui_from_ai()
	_update_preview()


## 初始化独立的 AI 大脑实例
func _init_ai_brain() -> void:
	# 动态加载脚本以避免循环依赖
	var GapLAI: GDScript = load("res://scenes/gap_l_mvp/scripts/GapLAI.gd")
	GapLCardDataScript = load("res://scenes/gap_l_mvp/resources/GapLCardData.gd")
	
	ai_brain = GapLAI.new()
	
	# 设置默认值
	ai_brain.strategy_factor = 0.5
	ai_brain.base_batna = 0.0
	ai_brain.current_sentiment = 0.0
	ai_brain.emotional_volatility = 0.5
	
	# 监听情绪变化信号
	ai_brain.sentiment_changed.connect(_on_ai_sentiment_changed)
	
	print("[PRModelLab] AI 大脑初始化完成")


## 连接所有 UI 信号
func _connect_signals() -> void:
	# 左面板滑条
	sf_slider.value_changed.connect(_on_sf_slider_changed)
	batna_slider.value_changed.connect(_on_batna_slider_changed)
	sentiment_slider.value_changed.connect(_on_sentiment_slider_changed)
	volatility_slider.value_changed.connect(_on_volatility_slider_changed)
	
	# 中面板滑条
	p_slider.value_changed.connect(_on_p_slider_changed)
	r_slider.value_changed.connect(_on_r_slider_changed)
	
	# 提交按钮
	submit_button.pressed.connect(_on_submit_pressed)


## 从 AI 状态同步 UI 显示
func _sync_ui_from_ai() -> void:
	# 阻止信号触发以避免循环更新
	sf_slider.set_block_signals(true)
	batna_slider.set_block_signals(true)
	sentiment_slider.set_block_signals(true)
	volatility_slider.set_block_signals(true)
	
	sf_slider.value = ai_brain.strategy_factor
	batna_slider.value = ai_brain.base_batna
	sentiment_slider.value = ai_brain.current_sentiment
	volatility_slider.value = ai_brain.emotional_volatility
	
	sf_slider.set_block_signals(false)
	batna_slider.set_block_signals(false)
	sentiment_slider.set_block_signals(false)
	volatility_slider.set_block_signals(false)
	
	_update_sf_label()
	_update_batna_label()
	_update_sentiment_label()
	_update_volatility_label()


## ===== 左面板：AI 参数控制 =====

func _on_sf_slider_changed(value: float) -> void:
	ai_brain.strategy_factor = value
	_update_sf_label()
	_update_preview()


func _update_sf_label() -> void:
	var sf: float = ai_brain.strategy_factor
	var personality: String = ""
	
	if sf <= -0.5:
		personality = "恶霸型 😈"
	elif sf <= -0.1:
		personality = "嫉妒型 😒"
	elif sf < 0.1:
		personality = "冷漠型 😐"
	elif sf < 0.5:
		personality = "合作型 🤝"
	else:
		personality = "圣人型 😇"
	
	sf_value_label.text = "%.2f: %s" % [sf, personality]


func _on_batna_slider_changed(value: float) -> void:
	ai_brain.base_batna = value
	_update_batna_label()
	_update_preview()


func _update_batna_label() -> void:
	batna_value_label.text = "底线: %.1f" % ai_brain.base_batna


func _on_sentiment_slider_changed(value: float) -> void:
	# 手动覆盖情绪值（不调用 update_sentiment 避免触发信号）
	ai_brain.current_sentiment = value
	_update_sentiment_label()
	_update_preview()


func _update_sentiment_label() -> void:
	var sent: float = ai_brain.current_sentiment
	var emoji: String = ai_brain.get_sentiment_emoji()
	var label: String = ai_brain.get_sentiment_label()
	sentiment_value_label.text = "%s %.2f (%s)" % [emoji, sent, label]


func _on_volatility_slider_changed(value: float) -> void:
	ai_brain.emotional_volatility = value
	_update_volatility_label()
	_update_preview()


func _update_volatility_label() -> void:
	volatility_value_label.text = "敏感度: %.2f" % ai_brain.emotional_volatility


## ===== 中面板：提案构造 =====

func _on_p_slider_changed(value: float) -> void:
	_update_p_label()
	_update_preview()


func _update_p_label() -> void:
	var p_val: float = p_slider.value
	var color: String = "green" if p_val >= 0 else "red"
	p_value_label.text = "P: %.1f" % p_val
	# 注：Label 不支持 BBCode，使用主题色替代
	if p_val >= 0:
		p_value_label.add_theme_color_override("font_color", Color("#00cc66"))
	else:
		p_value_label.add_theme_color_override("font_color", Color("#ff4444"))


func _on_r_slider_changed(value: float) -> void:
	_update_r_label()
	_update_preview()


func _update_r_label() -> void:
	var r_val: float = r_slider.value
	r_value_label.text = "R: %.1f" % r_val
	if r_val >= 0:
		r_value_label.add_theme_color_override("font_color", Color("#00cc66"))
	else:
		r_value_label.add_theme_color_override("font_color", Color("#ff4444"))


## ===== 核心循环 A：实时预览 =====

## 实时预览计算（不修改 AI 状态）
func _update_preview() -> void:
	# 构造虚拟卡牌
	var mock_card: Resource = _create_mock_card(p_slider.value, r_slider.value)
	
	# 调用 AI 计算
	var result: Dictionary = ai_brain.calculate_utility([mock_card])
	
	# 更新公式显示
	_render_formula(result)


## 创建用于预览的虚拟卡牌
func _create_mock_card(profit: float, relationship: float) -> Resource:
	var card: Resource = GapLCardDataScript.new()
	card.card_name = "PreviewCard"
	card.g_value = profit # P = 我方收益
	card.opp_value = relationship # R = 对方收益
	return card


## 渲染公式显示
func _render_formula(result: Dictionary) -> void:
	var bd: Dictionary = result["breakdown"]
	var p: float = bd["v_self"]
	var r: float = bd["v_opp"]
	var sf: float = bd["strategy_factor"]
	var rel_util: float = bd["relationship_utility"]
	var total: float = result["total_score"]
	var batna: float = bd["base_batna"]
	var accepted: bool = result["accepted"]
	
	# 构建 BBCode 公式
	var p_color: String = "green" if p >= 0 else "red"
	var r_color: String = "cyan" if r >= 0 else "orange"
	var sf_color: String = "yellow"
	var rel_color: String = "lime" if rel_util >= 0 else "salmon"
	var total_color: String = "white"
	var status_icon: String = "✅" if accepted else "❌"
	var status_color: String = "green" if accepted else "red"
	
	var formula_text: String = """[center][b]═══ PR 效用公式 ═══[/b][/center]

[code]Utility = P + (R × SF)[/code]

[color=%s]P[/color] = [color=%s]%.1f[/color]
[color=%s]R[/color] = [color=%s]%.1f[/color]
[color=%s]SF[/color] = [color=%s]%.2f[/color] (有效值，含情绪修正)

[color=%s]关系效用[/color] = R × SF = [color=%s]%.1f[/color]

[b]总效用[/b] = %.1f + %.1f = [color=%s][b]%.1f[/b][/color]
BATNA = %.1f

[center][font_size=24][color=%s]%s %s[/color][/font_size][/center]
""" % [
		p_color, p_color, p,
		r_color, r_color, r,
		sf_color, sf_color, sf,
		rel_color, rel_color, rel_util,
		p, rel_util, total_color, total,
		batna,
		status_color, status_icon, "接受" if accepted else "拒绝"
	]
	
	formula_display.text = formula_text


## ===== 核心循环 B：提交执行 =====

func _on_submit_pressed() -> void:
	current_round += 1
	
	# 构造卡牌并执行真正计算
	var p_val: float = p_slider.value
	var r_val: float = r_slider.value
	var mock_card: Resource = _create_mock_card(p_val, r_val)
	var result: Dictionary = ai_brain.calculate_utility([mock_card])
	
	# ===== 情绪演化 =====
	# 根据 R 值（对方收益）更新 AI 情绪
	var emotion_delta: float = 0.0
	var emotion_reason: String = ""
	
	if r_val > 0:
		# AI 获利 -> 情绪变好
		emotion_delta = clampf(r_val / 100.0, 0.05, 0.3)
		emotion_reason = "获利 %.1f，心情变好" % r_val
	elif r_val < 0:
		# AI 受损 -> 情绪变差
		emotion_delta = clampf(r_val / 100.0, -0.3, -0.05)
		emotion_reason = "受损 %.1f，心情变差" % r_val
	
	if emotion_delta != 0.0:
		ai_brain.update_sentiment(emotion_delta, emotion_reason)
		# UI 会通过信号自动更新
	
	# ===== 记录日志 =====
	_append_history_log(p_val, r_val, result)
	
	# ===== 屏幕反馈 =====
	_play_screen_flash(result["accepted"])


## AI 情绪变化回调 -> 同步滑条显示
func _on_ai_sentiment_changed(new_value: float, reason: String) -> void:
	# 阻止触发 value_changed 信号避免循环
	sentiment_slider.set_block_signals(true)
	sentiment_slider.value = new_value
	sentiment_slider.set_block_signals(false)
	
	_update_sentiment_label()
	_update_preview()
	
	print("[PRModelLab] 情绪更新: %.2f | %s" % [new_value, reason])


## 追加历史日志
func _append_history_log(p_val: float, r_val: float, result: Dictionary) -> void:
	var bd: Dictionary = result["breakdown"]
	var sf: float = bd["strategy_factor"]
	var total: float = result["total_score"]
	var accepted: bool = result["accepted"]
	var reason: String = result["reason"]
	
	var status_icon: String = "✅" if accepted else "❌"
	var status_color: String = "green" if accepted else "red"
	
	var log_entry: String = """[color=gray]━━━━━━━━━━━━━━━━━━━━[/color]
[b][Round #%d][/b] P:[color=green]%.0f[/color] R:[color=cyan]%.0f[/color] SF:[color=yellow]%.2f[/color]
→ Utility: [b]%.1f[/b] [color=%s]%s[/color]
[i][color=silver]%s[/color][/i]

""" % [
		current_round, p_val, r_val, sf,
		total, status_color, status_icon,
		reason
	]
	
	# 倒序插入（新的在最上面）
	history_log.text = log_entry + history_log.text


## 播放屏幕闪烁动画
func _play_screen_flash(accepted: bool) -> void:
	var flash_color: Color
	if accepted:
		flash_color = Color(0.0, 0.8, 0.3, 0.4) # 绿色
	else:
		flash_color = Color(0.9, 0.2, 0.2, 0.4) # 红色
	
	screen_flash.color = flash_color
	screen_flash.visible = true
	
	# 创建渐隐动画
	var tween: Tween = create_tween()
	tween.tween_property(screen_flash, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: screen_flash.visible = false)
