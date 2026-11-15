class_name Num
## The one way every player-facing number is printed (round 2, point 1). The callers add the sign
## ($, ¶) in front. Exceptions with their own look: the coin tally machine's drums, the Findings
## counter and the chute's stock drums. Small counts (seconds, staff, "7/24", percentages) stay plain.


## `n` as the game prints it, in every language:
## - whole millions "3M", a million that isn't whole one decimal, cut not rounded ("1.5M",
##   1.234.567 is "1.2M", 1.040.000 is "1.0M": never more than there is, never mistaken for whole);
## - under a million, whole thousands "40K", anything else with dots ("12.345", "999", "1.500");
## - negatives with "-" in front ("-40K").
static func text(n: int) -> String:
	var minus := "-" if n < 0 else ""
	var digits := str(absi(n))
	if digits.length() > 6:
		var millions := digits.left(-6)
		return minus + millions + ("" if digits.right(6) == "000000" else "." + digits[-6]) + "M"
	if digits.length() > 3 and digits.ends_with("000"):
		return minus + digits.left(-3) + "K"
	var out := ""
	while digits.length() > 3:
		out = "." + digits.right(3) + out
		digits = digits.left(-3)
	return minus + digits + out
