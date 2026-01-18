## ProposalSynthesizer.gd
## 提案合成器 - 纯函数工具类
##
## 负责：
## 1. 合成 (craft): 议题卡 + 动作卡 -> 合成卡
## 2. 分解 (split): 合成卡 -> {议题卡, 动作卡}
##
## 设计理念：
## - 无状态，所有方法都是静态纯函数
## - 不持有任何节点引用
## - 可被 NegotiationTableUI 和 AI 共同使用
class_name ProposalSynthesizer
extends RefCounted


## ===== 合成方法 =====

## 将议题卡与动作卡合成为提案卡
## @param issue: IssueCardData 议题卡
## @param action: ActionCardData 动作卡
## @return: ProposalCardData 合成卡，如果输入无效则返回 null
static func craft(issue: Resource, action: Resource) -> Resource:
	# 验证输入
	if issue == null or action == null:
		push_error("[ProposalSynthesizer] craft() 失败：议题或动作为空")
		return null
	
	# 类型检查（通过脚本路径判断）
	var issue_script_path: String = issue.get_script().resource_path if issue.get_script() else ""
	var action_script_path: String = action.get_script().resource_path if action.get_script() else ""
	
	if not issue_script_path.ends_with("IssueCardData.gd"):
		push_error("[ProposalSynthesizer] craft() 失败：第一个参数不是 IssueCardData")
		return null
	
	if not action_script_path.ends_with("ActionCardData.gd"):
		push_error("[ProposalSynthesizer] craft() 失败：第二个参数不是 ActionCardData")
		return null
	
	# 加载 ProposalCardData 并调用其合成方法
	var ProposalClass: GDScript = load("res://scenes/negotiation/resources/ProposalCardData.gd")
	var proposal: Resource = ProposalClass.synthesize(issue, action)
	
	print("[ProposalSynthesizer] 合成成功: %s + %s = %s" % [
		issue.issue_name, action.action_name, proposal.display_name
	])
	
	return proposal


## ===== 分解方法 =====

## 将合成卡分解为原始的议题卡和动作卡
## @param proposal: ProposalCardData 合成卡
## @return: 字典 {"issue": IssueCardData, "action": ActionCardData}，如果无法分解则返回空字典
static func split(proposal: Resource) -> Dictionary:
	# 验证输入
	if proposal == null:
		push_error("[ProposalSynthesizer] split() 失败：合成卡为空")
		return {}
	
	# 类型检查
	var proposal_script_path: String = proposal.get_script().resource_path if proposal.get_script() else ""
	if not proposal_script_path.ends_with("ProposalCardData.gd"):
		push_error("[ProposalSynthesizer] split() 失败：参数不是 ProposalCardData")
		return {}
	
	# 检查是否可分解
	if not proposal.can_split():
		push_error("[ProposalSynthesizer] split() 失败：合成卡缺少源引用")
		return {}
	
	var result: Dictionary = {
		"issue": proposal.source_issue,
		"action": proposal.source_action
	}
	
	print("[ProposalSynthesizer] 分解成功: %s -> %s + %s" % [
		proposal.display_name,
		proposal.source_issue.issue_name,
		proposal.source_action.action_name
	])
	
	return result


## ===== 验证方法 =====

## 检查议题卡是否可以接收动作卡
## 用于拖拽判断
## @param issue: 议题卡
## @param action: 动作卡
## @return: 如果可以合成则返回 true
static func can_craft(issue: Resource, action: Resource) -> bool:
	if issue == null or action == null:
		return false
	
	var issue_script_path: String = issue.get_script().resource_path if issue.get_script() else ""
	var action_script_path: String = action.get_script().resource_path if action.get_script() else ""
	
	return issue_script_path.ends_with("IssueCardData.gd") and \
		   action_script_path.ends_with("ActionCardData.gd")


## ===== 批量操作 =====

## 从提案列表中提取所有动作卡数据
## 用于将合成卡列表转换为可被 GapLAI 评估的格式
## @param proposals: ProposalCardData 数组
## @return: 动作卡数据数组（用于 GAP-L 计算）
static func extract_action_values(proposals: Array) -> Array:
	var result: Array = []
	
	for proposal: Resource in proposals:
		if proposal == null:
			continue
		
		# 创建一个简化的数据对象用于 GAP-L 计算
		# 保持与原 GapLCardData 兼容
		var data: Dictionary = {
			"card_name": proposal.display_name,
			"g_value": proposal.g_value,
			"opp_value": proposal.opp_value,
			"stance": proposal.stance,
			"has_gapl_modifiers": proposal.has_gapl_modifiers,
			"gapl_modifiers": proposal.gapl_modifiers,
			"sentiment_impact": proposal.sentiment_impact
		}
		result.append(data)
	
	return result
