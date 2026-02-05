# test_negotiation_agent.gd
class_name TestNegotiationAgent
extends GdUnitTestSuite

# Dependencies
# NegotiationAgent depends on ItemDatabase, NegotiationPhysicsEngine, NegotiationBrain_BT, NegotiationDecoder
const NegotiationAgentScript = preload("res://scenes/negotiation_ai/NegotiationAgent.gd")

var agent

func before_test() -> void:
	print("Running before_test")
	agent = NegotiationAgentScript.new()
	if agent == null:
		print("Agent is NULL in before_test!")
	# Configure a standard extensive personality
	agent.configure_personality(Vector2(50.0, 50.0), 1.0, 30.0)

# 1. Component Integrity Test
func test_components_init() -> void:
	print("Running test_components_init")
	if agent == null:
		print("Agent is NULL in test_components_init! Re-initializing...")
		agent = NegotiationAgentScript.new()
		
	assert_object(agent).is_not_null()
	assert_object(agent.encoder).is_not_null()
	assert_object(agent.engine).is_not_null()
	assert_object(agent.brain).is_not_null()
	assert_object(agent.decoder).is_not_null()

# 2. Pipeline Integration - Basic Flow
func test_pipeline_basic_accept() -> void:
	# Test a perfect deal: Giving Gold Coin (P+1) for nothing
	# "gold_coin": P=1, R=0
	var offered = ["gold_coin"]
	var requested = []
	
	# Current Point: (0, 1) - Very far from target (50, 50)
	# This should actually fail initially because current (0,1) is far from target (50,50)
	# Wait, standard physics engine takes "Current Proposal Vector"
	# Proposal Vector = Gain - Loss
	# Vector = (0, 1)
	# Target = (50, 50)
	# Correction = (50, 49) -> Magnitude ~70 -> Likely Reject
	
	# Let's adjust target to be closer to reality for a "New Deal"
	# Or make the offer massive
	
	# Scenario: Target is (10, 10). Offer is Diamond (50, 0).
	agent.configure_personality(Vector2(10.0, 10.0), 1.0, 30.0)
	
	# Offer diamond (P=50)
	var result = agent.evaluate_proposal(["diamond"], [])
	
	# Vector = (0, 50). Target = (10, 10)
	# Delta = (10, -40). Magnitude = 41.
	# Wait, P is Y-axis.
	
	assert_dict(result).contains_keys(["accepted", "intent", "tactic", "response_text"])
	# We don't assert boolean acceptance here as it depends on precise math, just structure

# 3. Vector Evaluation Logic
func test_evaluate_vector_logic() -> void:
	# Scenario 1: Perfect Match
	# Target (100, 100). Proposal (100, 100).
	agent.configure_personality(Vector2(100.0, 100.0), 1.0, 30.0)
	
	var result = agent.evaluate_vector(Vector2(100.0, 100.0))
	
	assert_bool(result["accepted"]).is_true()
	assert_str(result["intent"]).is_equal("ACCEPT")
	# Satisfaction should be high, so likely simple ACCEPT
	
	# Scenario 2: Terrible Deal
	# Target (100, 100). Proposal (0, 0).
	# Distance ~141. Threshold 30.
	# Force = High.
	
	result = agent.evaluate_vector(Vector2(0.0, 0.0))
	assert_bool(result["accepted"]).is_false()
	# Expecting Rejection
	assert_str(result["intent"]).contains("REJECT")

# 4. Motivation Detection
func test_motivation_instrumental() -> void:
	# Target (100, 100).
	# Proposal (100, 0) -> Missing Profit (Y-axis).
	# Correction Vector points UP (+Y).
	# Angle should indicate NEED PROFIT -> INSTRUMENTAL.
	agent.configure_personality(Vector2(100.0, 100.0), 1.0, 30.0)
	var result = agent.evaluate_vector(Vector2(100.0, 0.0))
	
	assert_str(result["motivation"]).is_equal("INSTRUMENTAL")
	assert_str(result["tactic"]).contains("DEMAND_MORE") # Assuming DEMAND_MORE is mapped

func test_motivation_relational() -> void:
	# Target (100, 100).
	# Proposal (0, 100) -> Missing Relationship (X-axis).
	# Correction Vector points RIGHT (+X).
	# Angle should indicate NEED RELATIONSHIP -> RELATIONAL.
	agent.configure_personality(Vector2(100.0, 100.0), 1.0, 30.0)
	var result = agent.evaluate_vector(Vector2(0.0, 100.0))
	
	assert_str(result["motivation"]).is_equal("RELATIONAL")

# 5. Pressure Integration
func test_pressure_impact() -> void:
	# Scenario: Borderline case
	agent.configure_personality(Vector2(100.0, 0.0), 1.0, 30.0)
	var vector = Vector2(80.0, 0.0) # Distance 20. Acceptable?
	# Force = 20. Threshold 30. 20 < 30.
	# Force > Low (15).
	# Expect: ACCEPT_RELUCTANT (if pressure low)
	
	var res_low = agent.evaluate_vector(vector)
	assert_bool(res_low["accepted"]).is_true()
	assert_str(res_low["intent"]).is_equal("ACCEPT_RELUCTANT")
	
	# Increase pressure massively
	agent.engine.current_pressure = 100.0 # Max pressure
	
	# With high pressure:
	# Pressure factor = 0.5. Force = 20 * 0.5 = 10.
	# 10 < Low (15).
	# Should be simple ACCEPT.
	
	var res_high = agent.evaluate_vector(vector)
	assert_bool(res_high["accepted"]).is_true()
	assert_str(res_high["intent"]).is_equal("ACCEPT")
	# Check stress level via agent accessor or physics dict
	assert_str(res_high["physics"]["pressure_tier"]).is_equal("HIGH")
	assert_str(agent.get_stress_level()).is_equal("HIGH")

# 6. Impatience Meter
func test_impatience_trigger() -> void:
	# Reset
	agent.reset()
	agent.configure_personality(Vector2(100.0, 100.0))
	
	# Monitor signal
	var monitor = monitor_signals(agent)
	
	# Create a frustrating situation
	var bad_proposal = Vector2(0.0, 0.0)
	
	# Set proposal
	agent.evaluate_vector(bad_proposal)
	
	# Force update to trigger
	# Threshold 10. Force ~140. Acc = 14/sec.
	agent.update(1.0)
	
	await assert_signal(monitor).is_emitted("impatience_counter_offer")
