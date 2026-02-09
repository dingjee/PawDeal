## SynthesisCalculator.gd
## 合成计算器 - 动态公式计算引擎
##
## 使用 Godot Expression 类解析和执行公式字符串。
## 替代硬编码的 match/case 计算逻辑。
##
## 设计理念：
## - 数据驱动：公式存储在资源文件中
## - 无状态：所有方法都是静态纯函数
## - 安全：Expression 沙盒执行，无法调用危险函数
class_name SynthesisCalculator
extends RefCounted


## ===== 公式计算 =====

## 执行公式字符串，返回计算结果
## @param formula: 公式字符串，如 "dep_oppo * 1.5 + 10"
## @param environment: 变量字典，如 {"dep_oppo": 0.8, "dep_self": 0.3}
## @return: 计算结果，失败返回 0.0
static func evaluate(formula: String, environment: Dictionary) -> float:
	if formula.is_empty():
		return 0.0
	
	# 创建 Expression 实例
	var expression: Expression = Expression.new()
	
	# 提取变量名和值
	var var_names: PackedStringArray = PackedStringArray()
	var var_values: Array = []
	
	for key: String in environment.keys():
		var_names.append(key)
		var_values.append(environment[key])
	
	# 解析公式
	var parse_error: Error = expression.parse(formula, var_names)
	if parse_error != OK:
		push_error("[SynthesisCalculator] 公式解析失败: %s | 错误: %s" % [
			formula, expression.get_error_text()
		])
		return 0.0
	
	# 执行计算
	var result: Variant = expression.execute(var_values)
	
	if expression.has_execute_failed():
		push_error("[SynthesisCalculator] 公式执行失败: %s | 错误: %s" % [
			formula, expression.get_error_text()
		])
		return 0.0
	
	# 确保返回浮点数
	if result is float:
		return result
	elif result is int:
		return float(result)
	else:
		push_warning("[SynthesisCalculator] 公式返回非数值: %s -> %s" % [formula, str(result)])
		return 0.0


## 批量计算多个公式
## @param formulas: 公式名称 -> 公式字符串 的字典
## @param environment: 变量字典
## @return: 公式名称 -> 计算结果 的字典
static func evaluate_batch(formulas: Dictionary, environment: Dictionary) -> Dictionary:
	var results: Dictionary = {}
	
	for name: String in formulas.keys():
		var formula: String = formulas[name]
		results[name] = evaluate(formula, environment)
	
	return results


## ===== 环境变量管理 =====

## 从 InfoCard 提取变量贡献
## @param info_card: InfoCardData 实例
## @return: 变量字典
static func extract_variables_from_info(info_card: Resource) -> Dictionary:
	if info_card == null:
		return {}
	
	if "variable_contributions" in info_card:
		return info_card.variable_contributions.duplicate()
	
	return {}


## 合并多个变量字典
## 后面的字典会覆盖前面同名变量
## @param var_dicts: 变量字典数组
## @return: 合并后的字典
static func merge_environments(var_dicts: Array) -> Dictionary:
	var merged: Dictionary = {}
	
	for dict: Dictionary in var_dicts:
		for key: String in dict.keys():
			merged[key] = dict[key]
	
	return merged


## 创建默认环境变量
## 包含一些常用的基础变量
## @return: 默认环境字典
static func create_default_environment() -> Dictionary:
	return {
		# 贸易相关
		"trade_vol_export": 100.0,
		"trade_vol_import": 100.0,
		"trade_deficit": 0.0,
		
		# 依赖度
		"dep_self": 0.5,
		"dep_oppo": 0.5,
		
		# BATNA
		"batna_val": 10.0,
		"batna_efficiency": 1.0,
		
		# 基础系数
		"base_multiplier": 1.0,
		"round_number": 1,
	}


## ===== Leverage 合成 =====

## 执行 Info + Power 合成，计算 Leverage 数值
## @param info: InfoCardData
## @param power: PowerTemplateData
## @param global_env: 全局环境变量（可选）
## @return: LeverageData 或 null
static func synthesize_leverage(
	info: Resource,
	power: Resource,
	global_env: Dictionary = {}
) -> Resource:
	# 验证输入
	if info == null or power == null:
		push_error("[SynthesisCalculator] synthesize_leverage 失败：参数为空")
		return null
	
	# 检查兼容性
	if power.has_method("is_compatible_with"):
		if not power.is_compatible_with(info):
			push_warning("[SynthesisCalculator] Info 与 Power 不兼容")
			return null
	
	# 构建环境变量
	var env: Dictionary = create_default_environment()
	
	# 合并全局环境
	for key: String in global_env.keys():
		env[key] = global_env[key]
	
	# 合并 Info 贡献的变量
	var info_vars: Dictionary = extract_variables_from_info(info)
	for key: String in info_vars.keys():
		env[key] = info_vars[key]
	
	# 计算威力值
	var power_formula: String = power.formula_power if "formula_power" in power else "0.0"
	var power_value: float = evaluate(power_formula, env)
	
	# 计算代价值
	var cost_formula: String = power.formula_cost if "formula_cost" in power else "0.0"
	var cost_value: float = evaluate(cost_formula, env)
	
	# 获取情绪
	var sentiment: String = "Neutral"
	if power.has_method("get_sentiment_string"):
		sentiment = power.get_sentiment_string()
	
	# 生成描述
	var desc_template: String = power.description_template if "description_template" in power else ""
	var description: String = desc_template
	if "info_name" in info:
		description = description.replace("{info_name}", info.info_name)
	description = description.replace("{power}", "%.1f" % power_value)
	description = description.replace("{cost}", "%.1f" % cost_value)
	
	# 创建 Leverage
	var LeverageClass: GDScript = load("res://scenes/negotiation/resources/LeverageData.gd")
	var leverage: Resource = LeverageClass.create(
		info, power,
		power_value, cost_value,
		sentiment, description,
		env
	)
	
	print("[SynthesisCalculator] 合成 Leverage: %s | Power=%.2f, Cost=%.2f, Sentiment=%s" % [
		leverage.get_display_name(), power_value, cost_value, sentiment
	])
	
	return leverage


## ===== Offer 合成 =====

## 执行 Leverage + Action 合成，创建最终 Offer
## @param leverages: LeverageData 数组
## @param action: ActionTemplateData
## @return: OfferData 或 null
static func synthesize_offer(
	leverages: Array,
	action: Resource
) -> Resource:
	# 验证输入
	if leverages.is_empty():
		push_error("[SynthesisCalculator] synthesize_offer 失败：无 Leverage")
		return null
	
	if action == null:
		push_error("[SynthesisCalculator] synthesize_offer 失败：Action 为空")
		return null
	
	# 检查插槽限制
	if "socket_count" in action:
		if leverages.size() > action.socket_count:
			push_warning("[SynthesisCalculator] Leverage 数量 (%d) 超过插槽限制 (%d)" % [
				leverages.size(), action.socket_count
			])
			# 只取前 N 个
			leverages = leverages.slice(0, action.socket_count)
	
	# 使用 OfferData 工厂方法创建
	var OfferClass: GDScript = load("res://scenes/negotiation/resources/OfferData.gd")
	var offer: Resource = OfferClass.create_from_synthesis(leverages, action)
	
	print("[SynthesisCalculator] 合成 Offer: %s" % offer.get_summary())
	
	return offer


## ===== 公式验证 =====

## 验证公式是否有效（不执行，只检查语法）
## @param formula: 公式字符串
## @param available_vars: 可用变量名数组
## @return: 如果有效返回 true
static func validate_formula(formula: String, available_vars: Array[String]) -> bool:
	if formula.is_empty():
		return true # 空公式是有效的（返回 0）
	
	var expression: Expression = Expression.new()
	var var_names: PackedStringArray = PackedStringArray()
	
	for v: String in available_vars:
		var_names.append(v)
	
	var error: Error = expression.parse(formula, var_names)
	return error == OK


## 获取公式中使用的变量名
## @param formula: 公式字符串
## @return: 变量名数组（可能包含误判）
static func extract_variable_names(formula: String) -> Array[String]:
	var result: Array[String] = []
	
	# 简单正则匹配：字母开头，后跟字母/数字/下划线
	var regex: RegEx = RegEx.new()
	regex.compile("[a-zA-Z_][a-zA-Z0-9_]*")
	
	var matches: Array[RegExMatch] = regex.search_all(formula)
	for m: RegExMatch in matches:
		var name: String = m.get_string()
		# 过滤掉数学函数名
		if name not in ["sin", "cos", "tan", "sqrt", "abs", "min", "max", "pow", "log", "exp"]:
			if not result.has(name):
				result.append(name)
	
	return result
