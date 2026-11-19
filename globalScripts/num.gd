class_name Num
## The one way every player-facing number is printed (round 2, point 1). The callers add the sign
## ($, ¶) in front. Exceptions with their own look: the coin tally machine's drums, the Findings
## counter and the chute's stock drums (until PRINT LARGER NUMBERS turns them digital: DigitalReadout). Small counts (seconds, staff, "7/24", percentages) stay plain.

## The short scale past a million, each a thousand times the last (game shorthand in every language).
const SUFFIXES := "MBTQ"


## `n` as the game prints it, in every language:
## - whole millions "3M" (billions B, trillions T, quadrillions Q and up, the same way: "4.5B",
##   "12T", "3.1Q"), a million that isn't whole one decimal, cut not rounded ("1.5M",
##   1.234.567 is "1.2M", 1.040.000 is "1.0M": never more than there is, never mistaken for whole);
## - under a million, whole thousands "40K", anything else with dots ("12.345", "999", "1.500");
## - negatives with "-" in front ("-40K").
static func text(n: int) -> String:
	var minus := "-" if n < 0 else ""
	var digits := str(absi(n))
	for step in range(SUFFIXES.length() - 1, -1, -1):
		var zeros := 6 + step * 3
		if digits.length() > zeros:
			var whole := digits.left(-zeros)
			var rest := digits.right(zeros)
			return minus + whole + ("" if rest == "0".repeat(zeros) else "." + rest[0]) + SUFFIXES[step]
	if digits.length() > 3 and digits.ends_with("000"):
		return minus + digits.left(-3) + "K"
	var out := ""
	while digits.length() > 3:
		out = "." + digits.right(3) + out
		digits = digits.left(-3)
	return minus + digits + out
