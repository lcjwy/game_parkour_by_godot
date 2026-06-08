class_name PricingPolicy
extends Resource
## 买断制价格策略。实际商店定价仍以 Steam/平台后台配置为准。

@export var china_region_codes: Array[String] = ["CN", "CHN"]
@export var china_price_text: String = "1 RMB"
@export var default_price_text: String = "1 USD"

func price_for_region(region_code: String) -> String:
	var normalized_code := region_code.strip_edges().to_upper()
	if china_region_codes.has(normalized_code):
		return china_price_text
	return default_price_text

