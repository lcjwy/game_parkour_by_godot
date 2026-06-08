extends Node
## Steam/商店服务占位。Web 和未接 SDK 阶段只暴露定价策略。

const PRICING_POLICY_PATH: String = "res://resources/economy/pricing_policy.tres"

var _pricing_policy: PricingPolicy

func _ready() -> void:
	_pricing_policy = load(PRICING_POLICY_PATH) as PricingPolicy

func price_for_region(region_code: String) -> String:
	if _pricing_policy == null:
		return "1 USD"
	return _pricing_policy.price_for_region(region_code)

func is_steam_available() -> bool:
	return false

