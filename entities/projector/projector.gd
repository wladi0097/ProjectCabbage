class_name Projector
extends Control
## The projector screen (coin upgrades), there once the "projector" desk card is stamped. Rolled up
## it is out of sight: only its pull shows, a PULL pennant dangling on a cord from the top of the
## view (a real 3D object, a pendulum, that the hand pinches). Pulled down, a sheet 70% of the view
## wide unrolls under the hand; past LET_GO it unrolls the rest by itself, the pull goes, and the
## projector lamp warms up, showing the upgrade tree (NODES) over a grey overlay. The X in its corner,
## a click on the overlay, or Esc rolls it away. The game keeps running behind it.
## Round the hub sit the departments (`dept`): info only, never bought, so drawn as rounded label
## plates in the hub's green (no price, no hold) rather than circles; faded until their own `needs` /
## `research` are stamped. Every upgrade hangs under one of them.
## Each node: a circle with a glyph and its name above; hovered, a block with name, description and
## cost; held for HOLD_TIME, it is bought with coins. A feature's whole branch stays hidden until
## the feature is unlocked: a node shows once every desk card it and its ancestors `need` is stamped
## (is_shown), a theme's heading with its first node. Then the whole branch shows, the part not yet
## reachable (parent not bought, department closed) greyed with dashed edges, its popup naming what it
## waits for, so the path ahead can be seen. One that becomes reachable for the first time is marked
## NEW (a pulsing ring) until the screen is rolled up (save.tree_seen); on the very first open
## everything showing counts as seen already (mark_first_open), so the first look doesn't all blink. A node with `research` (a
## research card on the desk) is reachable but locked until that card is stamped: a padlock, and a
## hold is refused. Like a phone map, a held
## press dragged across the slide pans the tree (kept on the slide) and the wheel zooms it; a
## double-click recentres.
##
## The sheet is drawn in 2D on a full-screen Control rather than a 3D quad: the camera looks steeply
## down on the desk, so a hanging 3D screen would shrink to a thin strip, and a 2D overlay gets mouse
## hover and hold for free. _has_point lets the pull and the rest of the desk click through.

const Events := preload("res://globalScripts/game_events.gd")

## Every node, in one list for retuning (prices from reports/economy_rework_2026-10-31.md). A bought
## node multiplies each save number in `mul`, raises each in `add`, and `hire` adds one hand.
## `research` names the desk card that unlocks it (see locked_by).
## `at` is the spot on the wheel (centre 0,0; x is drawn 1.6 times wider than y): marketing up, QA
## down (research, lab hands), manual handling right (procurement and desk space, minis, sales events,
## management fanning out), automation left (consultancy, supply chain, coin units, associates,
## headcount); THEMES names the fans. Generated, with no overlaps or crossing edges, by tools/projector_layout/layout.py from its
## sectors.json.
## The mat allowance (MAT): bought once per extra unit on the mat, up to MAT_MAX; the step to the
## mat's next unit costs MAT_BASE × MAT_GROWTH per unit already past 2 (mat_price).
const MAT := "mat_space"
const MAT_MAX := 20
const MAT_BASE := 1500
const MAT_GROWTH := 1.4
const NODES := [
	# Departments: free sub-hubs around the hub, one per direction, never bought (`dept`). Greyed until
	# their own `needs` / `research` are met; every upgrade hangs under exactly one of them.
	{id = "dept_marketing", parent = "", at = Vector2(0.12, -0.60), icon = "megaphone", price = 0,
		dept = true, needs = ["street_posters"], title = "MARKETING",
		body = "The street is told what it wants.\nSlogans and campaigns: each raises the price the\nstreet pays before it starts refusing units."},
	{id = "dept_manual", parent = "", at = Vector2(0.84, 0.00), icon = "hand", price = 0,
		dept = true, title = "MANUAL HANDLING",
		body = "Work you still do yourself.\nPacks, desk space, minis, catches, the bin,\ntargets, the lamp and the manager's quotas."},
	{id = "dept_qa", parent = "", at = Vector2(0.00, 0.77), icon = "lens", price = 0,
		dept = true, needs = ["quality_assurance"], research = "research_inspection", title = "RESEARCH LAB",
		body = "Every unit is a lesson.\nFaster analysis, more Findings (¶) per unit, more\nbenches, research units and lab hands."},
	{id = "dept_automation", parent = "", at = Vector2(-0.61, 0.00), icon = "belt", price = 0,
		dept = true, needs = ["junior_associate"], title = "AUTOMATION",
		body = "Work that no longer needs you.\nHired hands, conveyors, auto-buy, coin robots,\nthe consultant and the waste protocol."},
	{id = "slogan_1", parent = "dept_marketing", at = Vector2(0.12, -1.03), icon = "megaphone", price = 35,
		mul = {marketing = 1.25}, title = "SLOGAN I",
		body = "\"Cabbage. Because you have to eat.\"\nThe street pays 25% more before it refuses units."},
	{id = "slogan_2", parent = "slogan_1", at = Vector2(0.12, -1.46), icon = "megaphone", price = 120,
		mul = {marketing = 1.25}, title = "SLOGAN II",
		body = "\"Cabbage. Compliance tastes green.\"\nThe street pays 25% more before it refuses units."},
	{id = "slogan_3", parent = "slogan_2", at = Vector2(-0.24, -1.89), icon = "megaphone", price = 900,
		mul = {marketing = 1.25}, title = "SLOGAN III",
		body = "\"Cabbage. You were expecting something else?\"\nThe street pays 25% more before it refuses units."},
	{id = "slogan_4", parent = "slogan_3", at = Vector2(-0.49, -2.32), icon = "megaphone", price = 5500,
		research = "research_sentiment", mul = {marketing = 1.25}, title = "SLOGAN IV",
		body = "\"Cabbage. It has been decided.\"\nThe street pays 25% more before it refuses units."},
	{id = "slogan_5", parent = "slogan_4", at = Vector2(-0.49, -2.75), icon = "megaphone", price = 22500,
		mul = {marketing = 1.25}, title = "SLOGAN V",
		body = "\"Cabbage. Your household quota is attached.\"\nThe street pays 25% more before it refuses units."},
	{id = "slogan_6", parent = "slogan_5", at = Vector2(-0.49, -3.18), icon = "megaphone", price = 105000,
		mul = {marketing = 1.25}, title = "SLOGAN VI",
		body = "\"Cabbage.\"\nThe street pays 25% more before it refuses units."},
	{id = "pack_1", parent = "dept_manual", at = Vector2(1.54, -0.18), icon = "crate", price = 400,
		add = {pack_size = 3}, title = "BULK PROCUREMENT",
		body = "Volume is policy.\nEvery pack from the supply console holds 3 more\nunits: 13 instead of 10."},
	{id = "pack_2", parent = "pack_1", at = Vector2(1.98, -0.52), icon = "crate", price = 875,
		research = "research_materials", add = {pack_size = 40}, title = "CONTAINER ORDERS",
		body = "A container is parked in the street.\nEvery pack holds 40 more units: 53 instead of 13."},
	{id = "conveyor_1", parent = "dept_automation", at = Vector2(-0.99, -0.87), icon = "belt", price = 775,
		research = "research_materials", mul = {dispense_interval = 0.5}, title = "CONVEYOR RETROFIT",
		body = "The ramp is motorised.\nThe chute rolls a unit down every 0.5 s, not 1 s."},
	{id = "conveyor_2", parent = "conveyor_1", at = Vector2(-1.47, -1.51), icon = "belt", price = 13500,
		mul = {dispense_interval = 0.67}, title = "CONVEYOR II",
		body = "A second motor, same belt.\nThe chute rolls a unit down every 0.33 s, not 0.5 s."},
	{id = "conveyor_3", parent = "conveyor_2", at = Vector2(-1.95, -2.15), icon = "belt", price = 67500,
		mul = {dispense_interval = 0.67}, title = "CONVEYOR III",
		body = "Safety guards removed.\nThe chute rolls a unit down every 0.22 s, not 0.33 s."},
	{id = "associate_1", parent = "dept_automation", at = Vector2(-1.50, 0.75), icon = "clock", price = 180,
		needs = ["junior_associate"], mul = {associate_speed = 1.5}, title = "BRISK WALK I",
		body = "A stopwatch on every associate's desk.\nHired hands and lab hands move 50% faster."},
	{id = "associate_2", parent = "associate_1", at = Vector2(-2.03, 0.94), icon = "clock", price = 525,
		research = "performance_review", mul = {associate_speed = 1.5}, title = "BRISK WALK II",
		body = "Lunch is now a standing meeting.\nHired hands and lab hands move 50% faster again\n(2.25× the start speed)."},
	{id = "hire_associate_2", parent = "dept_automation", at = Vector2(-1.10, 0.58), icon = "hand", price = 150,
		needs = ["junior_associate"], hire = true, title = "HIRE ASSOCIATE II",
		body = "Headcount approved.\nOne more hired hand throwing units out of the\nwindow: 1 to 2 hands."},
	{id = "hire_associate_3", parent = "hire_associate_2", at = Vector2(-1.19, 0.97), icon = "hand", price = 400,
		hire = true, title = "HIRE ASSOCIATE III",
		body = "Another sleeve, same grey.\nOne more hired hand throwing units out of the\nwindow: 2 to 3 hands."},
	{id = "hire_associate_4", parent = "hire_associate_3", at = Vector2(-1.29, 1.36), icon = "hand", price = 1100,
		hire = true, title = "HIRE ASSOCIATE IV",
		body = "Interviews were waived.\nOne more hired hand throwing units out of the\nwindow: 3 to 4 hands."},
	{id = "hire_associate_5", parent = "hire_associate_4", at = Vector2(-1.39, 1.75), icon = "hand", price = 3000,
		research = "performance_review", hire = true, title = "HIRE ASSOCIATE V",
		body = "The desk is now a department.\nOne more hired hand throwing units out of the\nwindow: 4 to 5 hands."},
	{id = "hire_associate_6", parent = "hire_associate_5", at = Vector2(-1.49, 2.14), icon = "hand", price = 12000,
		hire = true, title = "HIRE ASSOCIATE VI",
		body = "Names are no longer collected.\nOne more hired hand throwing units out of the\nwindow: 5 to 6 hands."},
	{id = "hire_associate_7", parent = "hire_associate_6", at = Vector2(-1.59, 2.53), icon = "hand", price = 35000,
		hire = true, title = "HIRE ASSOCIATE VII",
		body = "A second coat rack is requisitioned.\nOne more hired hand throwing units out of the\nwindow: 6 to 7 hands."},
	{id = "hire_associate_8", parent = "hire_associate_7", at = Vector2(-1.69, 2.92), icon = "hand", price = 100000,
		hire = true, title = "HIRE ASSOCIATE VIII",
		body = "Full complement. Morale is not tracked.\nOne more hired hand throwing units out of the\nwindow: 7 to 8 hands."},
	{id = "qa_time", parent = "dept_qa", at = Vector2(0.00, 1.33), icon = "lens", price = 150,
		needs = ["quality_assurance"], research = "research_inspection", mul = {qa_time = 0.75}, title = "FASTER ANALYSIS",
		body = "The scan line is told to hurry.\nThe research lab analyses a unit in 3.75 s, not 5 s."},
	{id = "qa_findings", parent = "qa_time", at = Vector2(0.15, 1.89), icon = "pilcrow", price = 575,
		add = {findings_per_cabbage = 1}, title = "MORE FINDINGS",
		body = "Standards are revised.\nEach unit analysed gives 1 more Finding:
1 to 2, or 2 to 3 after the 100-units memo."},
	{id = "qa_fast_track", parent = "qa_findings", at = Vector2(0.15, 2.45), icon = "lens", price = 5000,
		mul = {qa_time = 0.5}, title = "LAB FAST TRACK",
		body = "Analysis is now a formality.\nThe research lab analyses a unit in 1.9 s, not 3.75 s."},
	{id = "double_findings", parent = "qa_fast_track", at = Vector2(0.15, 3.01), icon = "pilcrow", price = 20000,
		mul = {findings_per_cabbage = 2}, title = "DOUBLE FINDINGS",
		body = "Every finding is filed twice.\nEach unit analysed gives twice the Findings."},
	# Supply + automation (desk space, packs, auto-buy, hands, seating, campaigns, vacuums, QA rest):
	# entities/supply_console/, entities/associate/, entities/vacuum/, entities/qa_bay/.
	# The one upgrade bought again and again (MAT): each buy fits one more unit, up to MAT_MAX, at
	# mat_price. Its `price` is the first step's.
	{id = "mat_space", parent = "dept_manual", at = Vector2(2.26, -1.57), icon = "desk", price = MAT_BASE,
		needs = ["mat_allowance"], add = {desk_capacity = 1}, title = "MAT ALLOWANCE",
		body = "Floor space is leased by the unit.\nOne more unit fits on the mat (the chute keeps it full),\nup to 20. Each allowance costs more than the last."},
	{id = "discount_1", parent = "pack_1", at = Vector2(2.03, -0.07), icon = "crate", price = 400,
		mul = {pack_discount = 0.85}, title = "SUPPLIER REVIEW",
		body = "The supplier is reminded of alternatives.\nPacks cost 15% less. The ticker shows the cut price."},
	{id = "discount_2", parent = "discount_1", at = Vector2(2.49, -0.18), icon = "crate", price = 2500,
		mul = {pack_discount = 0.68}, title = "EXCLUSIVITY CLAUSE",
		body = "The supplier has no other customers now.\nPacks cost 32% less again: 58% of the full price,\nnot 85%."},
	{id = "auto_reserve_1", parent = "dept_automation", at = Vector2(-1.21, -0.44), icon = "clock", price = 1500,
		needs = ["auto_procurement"], add = {auto_reserve = 7}, title = "SAFETY STOCK",
		body = "The order is placed earlier.\nAuto-buy orders a pack at 10 units left, not 3."},
	{id = "auto_reserve_2", parent = "auto_smart_1", at = Vector2(-2.17, -1.73), icon = "clock", price = 17500,
		add = {auto_reserve = 15, auto_max_factor = -0.2}, title = "STRATEGIC PROCUREMENT",
		body = "A second shelf is approved.\nAuto-buy orders at 25 units left, not 10, and waits\nfor 20% below base pack price unless stock is out."},
	{id = "auto_smart_1", parent = "auto_reserve_1", at = Vector2(-1.69, -1.09), icon = "lens", price = 3000,
		add = {auto_max_factor = -0.5}, title = "PRICE DISCIPLINE",
		body = "The order waits for a fair price.\nAuto-buy waits for the base pack price or lower\n(it used to pay up to 150%), unless stock runs out."},
	{id = "hire_associate_9", parent = "hire_associate_8", at = Vector2(-1.78, 3.31), icon = "hand", price = 250000,
		hire = true, title = "HIRE ASSOCIATE IX",
		body = "Desks are now shared in shifts.\nOne more hired hand throwing units out of the\nwindow: 8 to 9 hands."},
	{id = "hire_associate_10", parent = "hire_associate_9", at = Vector2(-1.88, 3.70), icon = "hand", price = 400000,
		hire = true, title = "HIRE ASSOCIATE X",
		body = "Headcount is final. For now.\nOne more hired hand throwing units out of the\nwindow: 9 to 10 hands."},
	{id = "seating_1", parent = "associate_1", at = Vector2(-1.89, 1.36), icon = "chair", price = 500,
		mul = {hand_output = 1.5}, title = "OPEN-PLAN SEATING I",
		body = "The walls between associates come down.\nHired hands and lab hands set off 50% more often:\nevery 5.3 s, not 8 s (2.7 s, not 4 s, after the study)."},
	{id = "seating_2", parent = "seating_1", at = Vector2(-2.36, 1.76), icon = "chair", price = 13500,
		mul = {hand_output = 1.5}, title = "OPEN-PLAN SEATING II",
		body = "Chairs are replaced with a bench.\nHired hands and lab hands set off 50% more often\nagain (e.g. every 1.8 s, not 2.7 s)."},
	{id = "campaign_1", parent = "slogan_2", at = Vector2(0.49, -1.89), icon = "megaphone", price = 220,
		mul = {marketing = 1.25}, title = "SYNERGY JINGLE",
		body = "Four notes. Staff are asked to hum them.\nThe street pays 25% more before it refuses units."},
	{id = "campaign_2", parent = "campaign_1", at = Vector2(0.49, -2.32), icon = "megaphone", price = 1500,
		mul = {marketing = 1.25}, title = "LEAF IT TO US",
		body = "Legal approved the pun.\nThe street pays 25% more before it refuses units."},
	{id = "campaign_3", parent = "campaign_2", at = Vector2(0.49, -2.75), icon = "megaphone", price = 2500,
		mul = {marketing = 1.25}, title = "CRUCIFEROUS EXCELLENCE",
		body = "Nobody knows the word. Everyone trusts it.\nThe street pays 25% more before it refuses units."},
	{id = "campaign_4", parent = "slogan_3", at = Vector2(0.00, -2.32), icon = "megaphone", price = 2500,
		research = "research_sentiment", mul = {marketing = 1.25}, title = "BRASSICA FOR THE MASSES",
		body = "Posters in every stairwell.\nThe street pays 25% more before it refuses units."},
	{id = "campaign_5", parent = "campaign_4", at = Vector2(0.00, -2.75), icon = "megaphone", price = 20000,
		mul = {marketing = 1.25}, title = "TRUSTED BY THE MINISTRY",
		body = "The Ministry has not denied it.\nThe street pays 25% more before it refuses units."},
	{id = "campaign_6", parent = "campaign_5", at = Vector2(0.00, -3.18), icon = "megaphone", price = 67500,
		mul = {marketing = 1.25}, title = "THE ONLY VEGETABLE",
		body = "Other vegetables are under review.\nThe street pays 25% more before it refuses units."},
	{id = "vacuum_speed_1", parent = "dept_automation", at = Vector2(-1.20, 0.05), icon = "puck", price = 900,
		needs = ["coin_collector"], mul = {vacuum_speed = 1.5}, title = "FIRMWARE UPDATE",
		body = "The unit is told to hurry.\nCoin robots drive 50% faster."},
	{id = "vacuum_2", parent = "vacuum_speed_1", at = Vector2(-1.75, 0.10), icon = "puck", price = 5500,
		add = {vacuums = 1, vacuum_capacity = 12}, title = "SECOND UNIT",
		body = "A second unit is unboxed, with a bigger bag.\nA second coin robot docks on the mat.\nEach robot carries 20 coins per trip, not 8."},
	{id = "vacuum_speed_2", parent = "vacuum_2", at = Vector2(-2.31, 0.14), icon = "puck", price = 20000,
		mul = {vacuum_speed = 1.5, vacuum_reach = 1.5}, title = "FIRMWARE UPDATE II",
		body = "Obstacle detection is disabled. The unit is louder.\nCoin robots drive 50% faster again and suck up\ncoins from 50% further away."},
	{id = "vacuum_3", parent = "vacuum_speed_2", at = Vector2(-2.87, 0.19), icon = "puck", price = 87500,
		add = {vacuums = 1, vacuum_capacity = 30}, title = "THIRD UNIT",
		body = "The units have formed a department.\nA third coin robot docks on the mat.\nEach robot carries 50 coins per trip, not 20."},
	# No number: entities/vacuum/ reads tree_bought (CoinVacuums.STABILISER).
	{id = "vacuum_gyro", parent = "vacuum_speed_1", at = Vector2(-1.78, -0.33), icon = "puck", price = 1000,
		title = "GYROSCOPIC STABILISER",
		body = "A lead plate is bolted underneath. Falling over\nis now a disciplinary matter.\nCoin robots no longer tip onto their backs."},
	{id = "qa_slot_2", parent = "qa_time", at = Vector2(-0.15, 1.89), icon = "lens", price = 900,
		add = {qa_slots = 1}, title = "SECOND BENCH",
		body = "A second bench in the lab.\nThe research lab analyses 2 units at once, not 1."},
	{id = "qa_slot_3", parent = "qa_slot_2", at = Vector2(-0.15, 2.45), icon = "lens", price = 35000,
		add = {qa_slots = 1}, title = "THIRD BENCH",
		body = "The lab is now an institute.\nThe research lab analyses 3 units at once, not 2."},
	# Manager (down-right) and pricing consultant (up-right): entities/manager/, entities/consultant/.
	{id = "manager_time", parent = "dept_manual", at = Vector2(1.01, 0.92), icon = "clock", price = 200,
		needs = ["managerial_oversight"], add = {manager_time = 15.0}, title = "EXTENDED DEADLINES",
		body = "The manager is shown a calendar.\nQuotas give you 60 s instead of 45 s."},
	{id = "manager_reward_1", parent = "manager_time", at = Vector2(1.11, 1.48), icon = "crate", price = 875,
		mul = {manager_reward = 1.5}, title = "PERFORMANCE BONUS",
		body = "Bonuses are now discussed openly.\nMet quotas pay quota × price × 1.5, not × 1."},
	{id = "manager_raise", parent = "manager_reward_1", at = Vector2(1.21, 2.04), icon = "lens", price = 2000,
		add = {manager_raise = -0.1}, title = "REALISTIC TARGETS",
		body = "Ambition is capped by memo.\nQuotas ask 115% of your recent pace, not 125%."},
	{id = "manager_reward_2", parent = "manager_raise", at = Vector2(1.31, 2.60), icon = "crate", price = 6250,
		mul = {manager_reward = 1.5}, title = "EMPLOYEE OF THE QUARTER",
		body = "A frame is purchased. It stays empty.\nMet quotas pay quota × price × 2.25, not × 1.5."},
	{id = "consultant_speed_1", parent = "dept_automation", at = Vector2(-0.86, -1.47), icon = "clock", price = 200,
		needs = ["pricing_consultant"], mul = {consultant_interval = 0.5}, title = "BILLABLE HOURS",
		body = "The consultant bills by the tap.\nIt taps the slate every 2 s instead of 4 s."},
	{id = "consultant_mood", parent = "consultant_speed_1", at = Vector2(-0.94, -1.96), icon = "lens", price = 725,
		add = {consultant_skill = 1}, title = "READS THE ROOM",
		body = "The consultant looks out of the window.\nIt reads the street's mood (it drifts up to ±25%),\nso ~90% of units still sell when the mood turns."},
	{id = "consultant_smart", parent = "consultant_mood", at = Vector2(-1.02, -2.45), icon = "crate", price = 2000,
		add = {consultant_skill = 1}, title = "YIELD OPTIMISATION",
		body = "Some units may now be refused.\nIt aims for the most coins per unit after pack costs.\nWhile hired hands find no unit, it asks $1 more a tap\n(up to 1.6× the price at which every unit sells)."},
	{id = "consultant_speed_2", parent = "consultant_smart", at = Vector2(-1.11, -2.95), icon = "clock", price = 18000,
		mul = {consultant_interval = 0.5}, title = "RETAINER",
		body = "The consultant no longer leaves.\nIt taps the slate every 1 s instead of 2 s."},
	# Sales events (golden lamp up-left, catch combo far up-left, waste bin down, window targets far
	# right): entities/golden_lamp/, catch_combo/, rotten_bin/, window_targets/.
	{id = "lamp_mult", parent = "dept_manual", at = Vector2(1.90, 0.38), icon = "crate", price = 32500,
		needs = ["golden_lamp"], add = {lamp_mult = 3.0}, title = "GILDED FILAMENT",
		body = "The bulb is replaced with a better bulb.\nWhile the lamp glows, sales pay 8× instead of 5×."},
	{id = "lamp_time", parent = "lamp_mult", at = Vector2(2.37, 0.90), icon = "clock", price = 42500,
		mul = {lamp_time = 1.5}, title = "EXTENDED BURN",
		body = "The lamp's timer is taped down.\nIt glows for 30 s instead of 20 s."},
	{id = "lamp_every", parent = "lamp_time", at = Vector2(2.83, 1.42), icon = "clock", price = 67500,
		mul = {lamp_every = 0.6}, title = "LOOSE WIRING",
		body = "Maintenance has been told not to look.\nIt glows about every 90 s instead of 150 s."},
	{id = "combo_window", parent = "dept_manual", at = Vector2(1.74, 0.74), icon = "clock", price = 150,
		needs = ["catch_combo"], mul = {combo_window = 1.5}, title = "GRACE PERIOD",
		body = "Interceptions are counted generously.\nThe combo holds 6 s after a catch, not 4 s."},
	{id = "combo_cap", parent = "combo_window", at = Vector2(2.21, 1.26), icon = "crate", price = 725,
		add = {combo_cap = 0.5}, title = "UNCAPPED ENTHUSIASM",
		body = "The ceiling is raised by memo.\nThe combo tops out at +100% instead of +50%."},
	{id = "combo_step", parent = "combo_cap", at = Vector2(2.67, 1.78), icon = "hand", price = 4250,
		mul = {combo_step = 2.0}, title = "REFLEX TRAINING",
		body = "A mandatory seminar on catching things.\nEach catch adds +20% to sales instead of +10%."},
	{id = "bin_mouth", parent = "dept_manual", at = Vector2(1.43, 1.46), icon = "lens", price = 120,
		needs = ["catch_combo"], mul = {bin_mouth = 1.35}, title = "WIDER RECEPTACLE",
		body = "A larger bin is requisitioned.\nThe bin's mouth is 35% wider: units let go nearby\ndrop in from further away."},
	{id = "bin_rebate", parent = "bin_mouth", at = Vector2(1.89, 1.98), icon = "crate", price = 575,
		add = {bin_rebate = 0.2}, title = "DISPOSAL REBATE",
		body = "Waste is now a revenue stream.\nA binned rotten unit pays 20% of your price\n(nothing before)."},
	{id = "bin_rebate_2", parent = "bin_rebate", at = Vector2(2.36, 2.50), icon = "crate", price = 775,
		add = {bin_rebate = 0.25}, title = "SALVAGE CREDIT",
		body = "Rot is reclassified as inventory.\nA binned rotten unit pays 45% of your price\n(20% before)."},
	{id = "bin_rebate_3", parent = "bin_rebate_2", at = Vector2(2.82, 3.02), icon = "crate", price = 3500,
		add = {bin_rebate = 0.25}, title = "COMPOST CONTRACT",
		body = "The Ministry buys it by the tonne.\nA binned rotten unit pays 70% of your price\n(45% before)."},
	{id = "bin_rebate_4", parent = "bin_rebate_3", at = Vector2(3.29, 3.55), icon = "crate", price = 13000,
		add = {bin_rebate = 0.25}, title = "WASTE MONETISATION",
		body = "Spoilage now has its own quarterly target.\nA binned rotten unit pays 95% of your price\n(70% before)."},
	{id = "bin_rebate_5", parent = "bin_rebate_4", at = Vector2(3.76, 4.07), icon = "crate", price = 40000,
		add = {bin_rebate = 0.25}, title = "SPOILAGE PREMIUM",
		body = "A rotten unit is worth more than a fresh one. Fine.\nA binned rotten unit pays 120% of your price\n(95% before)."},
	{id = "hands_bin", parent = "dept_automation", at = Vector2(-0.52, 0.96), icon = "hand", price = 400,
		needs = ["junior_associate", "catch_combo"], add = {hands_bin = 1}, title = "WASTE HANDLING PROTOCOL",
		body = "Associates are shown where the bin is.\nHired hands throw rotten units into the bin\ninstead of selling them or leaving them."},
	{id = "target_size", parent = "dept_manual", at = Vector2(1.58, 1.10), icon = "lens", price = 575,
		needs = ["window_targets"], mul = {target_size = 1.5}, title = "BROADER FLOODLIGHT",
		body = "The street lamp is pointed less carefully.\nLit crates are 50% wider: more sales land in them."},
	{id = "target_every", parent = "target_size", at = Vector2(2.05, 1.62), icon = "clock", price = 575,
		mul = {target_every = 0.6}, title = "STREET COOPERATION",
		body = "The street has been asked to stand still.\nA crate lights about every 36 s, not 60 s."},
	{id = "target_shower", parent = "target_every", at = Vector2(2.52, 2.14), icon = "crate", price = 5500,
		mul = {target_shower = 2}, title = "PRIZE CRATES",
		body = "The crates are lined with coin.\nA hit adds 20× the sale's coins instead of 10×."},
	# Minis and the tube (right, between procurement and sales events): entities/mini_drop/.
	{id = "mini_rate_1", parent = "dept_manual", at = Vector2(0.96, -0.68), icon = "clock", price = 90,
		needs = ["mini_cabbages"], mul = {mini_every = 0.7}, title = "MINIATURISATION I",
		body = "The units are asked to be smaller, sooner.\nMinis drop 43% more often (every 14 s, not 20 s)."},
	{id = "mini_rate_2", parent = "mini_rate_1", at = Vector2(0.70, -1.46), icon = "clock", price = 500,
		mul = {mini_every = 0.7}, title = "MINIATURISATION II",
		body = "Nobody measured the old ones.\nMinis drop 43% more often (wait between drops\n×0.7, e.g. every 9.8 s, not 14 s)."},
	{id = "mini_rate_3", parent = "mini_rate_2", at = Vector2(0.81, -2.09), icon = "clock", price = 2000,
		mul = {mini_every = 0.7}, title = "MINIATURISATION III",
		body = "The units are now a rounding error.\nMinis drop 43% more often (wait between drops\n×0.7, e.g. every 6.9 s, not 9.8 s)."},
	{id = "mini_value_1", parent = "mini_rate_1", at = Vector2(1.06, -1.30), icon = "crate", price = 180,
		add = {mini_value = 0.08}, title = "PORTION REVIEW",
		body = "A mini is reclassified as a third.\nMinis sell for 1/3 of your price, not 1/4."},
	{id = "mini_value_2", parent = "mini_value_1", at = Vector2(1.17, -1.93), icon = "crate", price = 900,
		add = {mini_value = 0.17}, title = "HALF-UNIT STANDARD",
		body = "The street is told it is half a cabbage.\nMinis sell for 1/2 of your price, not 1/3."},
	{id = "tube_speed_1", parent = "mini_rate_1", at = Vector2(1.42, -1.15), icon = "belt", price = 300,
		needs = ["mini_tube"], mul = {tube_speed = 1.5, mini_every = 0.8}, title = "PNEUMATIC PRESSURE",
		body = "The compressor is set past its label.\nMinis roll through the tube 50% faster and drop\n25% more often (the wait between drops ×0.8)."},
	# Research units and lab hands (QA, down): Cabbage.research, entities/associate/ (research hands).
	{id = "research_mult_1", parent = "dept_qa", at = Vector2(-0.44, 1.61), icon = "pilcrow", price = 350,
		needs = ["research_cabbage"], add = {research_mult = 2.0}, title = "PEER REVIEW",
		body = "Each research unit is read by two people.\nBlue research units give 5× the Findings, not 3×."},
	{id = "research_mult_2", parent = "research_mult_1", at = Vector2(-0.50, 2.19), icon = "pilcrow", price = 1600,
		add = {research_mult = 3.0}, title = "LONGITUDINAL STUDY",
		body = "The study is extended indefinitely.\nBlue research units give 8× the Findings, not 5×."},
	{id = "research_mult_3", parent = "research_mult_2", at = Vector2(-0.70, 2.57), icon = "pilcrow", price = 7500,
		add = {research_mult = 4.0}, title = "CONTROL GROUP",
		body = "Half the units are told nothing.\nBlue research units give 12× the Findings, not 8×."},
	{id = "research_mult_4", parent = "research_mult_3", at = Vector2(-0.90, 2.95), icon = "pilcrow", price = 35000,
		add = {research_mult = 8.0}, title = "PUBLISH OR PERISH",
		body = "The findings are published internally.\nBlue research units give 20× the Findings, not 12×."},
	{id = "research_chance_1", parent = "research_mult_1", at = Vector2(-0.79, 1.80), icon = "lens", price = 800,
		add = {research_chance = 0.05}, title = "SAMPLING QUOTA",
		body = "More units are selected at random.\n1 unit in ~7 off the chute is blue, not 1 in 10."},
	{id = "research_chance_2", parent = "research_chance_1", at = Vector2(-0.99, 2.19), icon = "lens", price = 4500,
		add = {research_chance = 0.05}, title = "SAMPLING QUOTA II",
		body = "Random is redefined.\n1 unit in 5 off the chute is blue, not 1 in ~7."},
	{id = "research_chance_3", parent = "research_chance_2", at = Vector2(-1.19, 2.57), icon = "lens", price = 22000,
		add = {research_chance = 0.05}, title = "SAMPLING QUOTA III",
		body = "Every unit is now a candidate.\n1 unit in 4 off the chute is blue, not 1 in 5."},
	{id = "lab_hand_2", parent = "dept_qa", at = Vector2(0.50, 1.92), icon = "hand", price = 900,
		needs = ["research_assistant"], add = {research_hands = 1}, title = "SECOND LAB ASSISTANT",
		body = "A second coat, a smaller size.\nOne more lab hand tossing units into the research lab:\n1 to 2 lab hands."},
	{id = "lab_hand_3", parent = "lab_hand_2", at = Vector2(0.72, 2.41), icon = "hand", price = 9000,
		add = {research_hands = 1}, title = "THIRD LAB ASSISTANT",
		body = "The lab has a waiting list now.\nOne more lab hand tossing units into the research lab:\n2 to 3 lab hands."},
]
## Each theme's faint heading on the slide, where its branch ends (same units as a node's `at`).
const THEMES := [
	["PROCUREMENT", Vector2(3.26, -0.51)],
	["DESK SPACE", Vector2(2.26, -2.05)],
	["SALES EVENTS", Vector2(4.34, 4.02)],
	["MANAGEMENT", Vector2(1.53, 3.91)],
	["CONSULTANCY", Vector2(-1.33, -4.18)],
	["SUPPLY CHAIN", Vector2(-2.40, -2.30)],
	["COIN UNITS", Vector2(-3.10, 0.31)],
	["ASSOCIATES", Vector2(-3.10, 2.21)],
	["HEADCOUNT", Vector2(-1.66, 4.26)],
	["MINI UNITS", Vector2(1.25, -2.31)],
	["RESEARCH", Vector2(-1.21, 3.17)],
	["LAB HANDS", Vector2(0.82, 2.75)],
]
## The screen's rect as fractions of the view: centred, 70% wide, unrolled down to 88% of the height.
const SCREEN := Rect2(0.15, 0.0, 0.7, 0.88)
const HOLD_TIME := 0.6
## Zoomed right out, the whole tree with its theme headings fits on the slide.
const ZOOM_MIN := 0.27
const ZOOM_MAX := 2.5
## One wheel notch zooms by this factor, about the cursor.
const ZOOM_STEP := 1.15
const WIDEN := 1.6
## Pulled this far (of the whole drop) from where it rested, the screen goes the rest of the way itself.
const LET_GO := 0.3
## A press on the pull that moves less than this (px) is a click: it rolls the screen down.
const CLICK_PX := 8.0
const ROLLER_H := 26.0
const BAR_H := 12.0
## The close button in the open sheet's top-right corner (px).
const CLOSE := 40.0
## Where the cord is tied along the bottom bar (0 left .. 1 right): the middle, where it is seen.
const TAB_AT := 0.5
## The pull, a pendulum: cord length (m), gravity (stylised, stiffer than real), the velocity kept
## per STEP, and the height (m) the cord is tied at, so the tab hangs at about the hand's height.
const CORD := 0.15
const GRAVITY := 20.0
const DAMP := 0.98
const STEP := 1.0 / 120.0
const TIE_HEIGHT := 1.6
## A faint draught keeps it dangling: a sideways push (m/s², x and z) that drifts in slow,
## overlapping waves (wind_at).
const WIND := Vector2(1.1, 0.6)
## Tugs to draw the eye (tug_at): a push at the pull's own swing rate, so it swings hard. Until the
## screen has been opened once it swings at TUG_FIRST (~25°); after that, for TUG_TIME whenever an
## upgrade becomes affordable for the first time, at TUG_OFFER (~15°): coins dipping under a price
## and back don't tug again. Offers are checked every OFFER_CHECK seconds.
const TUG_FIRST := 3.0
const TUG_OFFER := 2.0
const TUG_TIME := 3.0
const OFFER_CHECK := 0.5
## With the tug, the pennant lights up bright for FLASH_TIME seconds (emission energy FLASH_GLOW).
const FLASH_TIME := 0.5
const FLASH_GLOW := 4.0
## Seconds per beat of a NEW node's pulsing ring.
const NEW_PULSE := 1.4
## The pennant's width and height (m), and how far its face is tipped back toward the camera (rad):
## at rest, and lifted nearly flat while the hand pinches it.
const TAB := Vector2(0.13, 0.11)
const TAB_TILT := -0.7
const TAB_PINCHED := -1.3
## The tab's collision layer: nothing masks it, only the hand's pick ray (all layers) sees it.
const PULL_LAYER := 1 << 19
const FONT := preload("res://assets/fonts/Oswald.ttf")
const FABRIC := Color(0.36, 0.39, 0.36)
const BEAM := Color(0.78, 0.84, 0.84)
const INK := Color(0.13, 0.15, 0.14)
const STEEL := Color(0.16, 0.17, 0.17)
const TUBE := Color(0.3, 0.32, 0.31)
const DENIED := Color(0.55, 0.12, 0.1)
const CABBAGE := Color(0.42, 0.72, 0.24)
const SHADE := Color(0.07, 0.08, 0.08, 0.62)

@export var roll_down_sound: AudioStream
@export var roll_up_sound: AudioStream
@export var approve_sound: AudioStream
@export var denied_sound: AudioStream

## How far the screen is unrolled, 0 (up) to 1 (down), and how far the projector lamp is on.
var _drop := 0.0
var _lamp := 0.0
## The hand holds the pull and the screen follows it; where the press started.
var _dragging := false
var _press_y := 0.0
var _press_drop := 0.0
## Where the screen is headed: down (open) or up.
var _down := false
var _settling: Tween
var _hovered := ""
var _holding := ""
var _hold := 0.0
var _denied := 0.0
var _close_hot := false
## The pull's slide down from above when the projector first turns up (px of offset).
var _arrive := 0.0
## The bottom bar's sideways lag behind the swinging pull while it rolls (px).
var _sway := 0.0
var _sfx := AudioStreamPlayer.new()
var _beam := GradientTexture2D.new()
var _overlay := ColorRect.new()
## The tree's pan (px) and zoom; a press on the slide pans once it moves past CLICK_PX.
var _pan := Vector2.ZERO
var _zoom := 1.0
var _panning := false
var _panned := false
var _pan_press := Vector2.ZERO
var _pan_start := Vector2.ZERO
## The tree, clipped to the slide below the heading. Its nodes and edges are drawn once on _layer,
## around its own origin, and only redrawn when they change (_layer_key); panning just moves it.
## Hover, hold and the popup go on _top, redrawn each frame (a few calls), and the lamp's pulse dims
## _layer only. _layer is a Node2D, not a Control: a Control is culled by its own (here empty) rect,
## so the whole tree vanished once the hub was panned out of the slide.
var _tree := Control.new()
var _layer := Node2D.new()
var _top := Control.new()
var _layer_key := []
## Nodes showing for the first time since the screen came down (marked NEW until it rolls up).
var _fresh: Array[String] = []
## THEMES that have a node showing (headings drawn), by index, and the ids showing (is_shown),
## both worked out when the layer is.
var _themes_shown: Array[bool] = []
var _shown := {}
## The sheet was down at the last redraw (rolled up, _draw is empty and needs no redraw).
var _sheet_drawn := true
## Node prices sorted, to count the affordable ones cheaply (they change the drawing).
static var _prices := PackedInt32Array()
## The pull in the 3D world: its body, the tipping tab, the cord, its handle and material.
var _grip: StaticBody3D
var _tab := Node3D.new()
var _cord := MeshInstance3D.new()
var _handle: Interactable
var _enamel := StandardMaterial3D.new()
var _tab_hot := false
var _tilt := TAB_TILT
## Where the cord is tied (under the bar) and the tab's Verlet point, now and one STEP ago.
var _tie := Vector3.ZERO
var _bob := Vector3.ZERO
var _bob_last := Vector3.ZERO
## Seconds of draught so far (wind_at).
var _wind_time := 0.0
## Seconds of offer tug left, seconds to the next offer count, and the last count (upgrades that can
## be held, ones that can be bought; -1 before the first count, which never tugs).
var _tug_left := 0.0
var _offer_in := 0.0
## Ids of the upgrades the pull has already tugged for (affordable once); null until the first check.
var _announced: Variant = null
## Seconds of the pennant's flash left, and the count of buyable upgrades stamped at its tip.
var _flash := 0.0
var _count := Label3D.new()
## The dark plate riveted under the tip that carries the count; hidden while nothing is buyable.
var _badge := Node3D.new()
var _step_left := 0.0
## While dragged, the tab keeps this offset from the mouse's point under it (no lag, no jump).
var _grab_offset := Vector3.ZERO
## The tab on screen (px) and its reach there, for the click-through.
var _grip_px := Vector2(-1000.0, -1000.0)
var _grip_r := 40.0


func _ready() -> void:
	# Before the Hand autoload, so the hand sits on where the tab is this frame, not the last.
	process_priority = -1
	set_anchors_preset(PRESET_FULL_RECT)
	_overlay.set_anchors_preset(PRESET_FULL_RECT)
	_overlay.show_behind_parent = true
	_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	_overlay.color = Color(SHADE, 0.0)
	add_child(_overlay)
	_tree.clip_contents = true
	_tree.mouse_filter = MOUSE_FILTER_IGNORE
	_top.mouse_filter = MOUSE_FILTER_IGNORE
	_tree.add_child(_layer)
	_tree.add_child(_top)
	_layer.draw.connect(_draw_layer)
	_top.draw.connect(_draw_top)
	add_child(_tree)
	_sfx.bus = &"SFX"
	# The projector's hot spot: a soft cold wash, fading out toward the screen's edges.
	_beam.fill = GradientTexture2D.FILL_RADIAL
	_beam.fill_from = Vector2(0.5, 0.45)
	_beam.fill_to = Vector2(1.05, 1.0)
	_beam.gradient = Gradient.new()
	_beam.gradient.set_color(0, Color(BEAM, 0.42))
	_beam.gradient.set_color(1, Color(BEAM, 0.04))
	add_child(_sfx)
	visible = false
	if unlocked(SaveManager.save):
		_show(false)
	# A save from before nodes were marked NEW: everything showing now counts as seen.
	var save: SaveGame = SaveManager.save
	if save.tree_seen.is_empty() and not save.tree_bought.is_empty():
		save.tree_seen = PackedStringArray(fresh(save))


func _process(delta: float) -> void:
	var save: SaveGame = SaveManager.save
	if not visible:
		if unlocked(save):
			_show(true)
		return
	if _dragging:
		# The sheet follows the hand exactly.
		_drop = clampf(_press_drop + (get_local_mouse_position().y - _press_y) / _span(), 0.0, 1.0)
		if absf(_drop - _press_drop) >= LET_GO:
			# Far enough: the roller spring takes over, the hand may keep hold of the tab.
			_dragging = false
			_settle(_press_drop < 0.5)
	_denied = maxf(_denied - delta, 0.0)
	if _holding != "" and _lamp > 0.9:
		if can_buy(_holding, save):
			_hold += delta / HOLD_TIME
			if _hold >= 1.0:
				var paid := price_of(_holding, save)
				buy(_holding, save)
				SaveManager.log_event("node", _holding, paid, "coins")
				_play(approve_sound)
				_holding = ""
				_hold = 0.0
		elif _denied == 0.0:
			_denied = 0.5
			_play(denied_sound)
	_offer_in -= delta
	if _offer_in <= 0.0:
		_offer_in = OFFER_CHECK
		var first: bool = _announced == null
		if first:
			_announced = {}
		if announce(save, _announced) and not first:
			_tug_left = TUG_TIME
			_flash = FLASH_TIME
		_count.text = count_text(offers(save).y)
		_badge.visible = _count.text != ""
	_tug_left = maxf(_tug_left - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	_enamel.emission_energy_multiplier = maxf(0.35 if _tab_hot else 0.0, FLASH_GLOW * _flash / FLASH_TIME)
	_move_pull(delta)
	# The bar trails the swinging pull a little while the sheet is loose; lit, the sheet hangs flat.
	_sway = lerpf(_sway, clampf((_grip_px.x - _tie_px().x) * 0.4, -24.0, 24.0) * (1.0 - _lamp) * minf(_drop * 4.0, 1.0),
			1.0 - exp(-8.0 * delta))
	_overlay.color = Color(SHADE, SHADE.a * smoothstep(0.55, 1.0, _drop))
	var area := _tree_rect()
	_tree.position = area.position
	_tree.size = area.size
	_tree.visible = _lamp > 0.0
	if _tree.visible:
		var wheel := _wheel()
		_layer.position = wheel[0] - area.position
		_layer.modulate.a = _lamp * pulse(Time.get_ticks_msec() / 1000.0)
		_top.size = area.size
		var key := [_zoom, area.size, save.get_instance_id(), save.stamped.size(), save.tree_bought.size(), save.desk_capacity, affordable(save.coins)]
		if key != _layer_key:
			_layer_key = key
			_themes_shown = themes_shown(save)
			_shown.clear()
			for node: Dictionary in NODES:
				if is_shown(node.id, save):
					_shown[node.id] = true
			if _lamp > 0.0:
				for id in fresh(save):
					if not _fresh.has(id):
						_fresh.append(id)
			_layer.queue_redraw()
		_top.queue_redraw()
	# Rolled up, _draw draws nothing: one last redraw clears the sheet, then none.
	if _drop > 0.0 or _sheet_drawn:
		queue_redraw()
	_sheet_drawn = _drop > 0.0


## The pull: while dragged it sits under the mouse; otherwise it swings on its cord, in fixed STEPs.
## Shown only while the screen is not fully down (open, the overlay, X and Esc close it), and not
## while the camera is at the farm TV.
func _move_pull(delta: float) -> void:
	if _grip == null:
		return
	var shown := (_drop < 1.0 or _dragging) and not FarmTv.away
	_grip.visible = shown
	_cord.visible = shown
	_handle.enabled = shown
	_grip.collision_layer = PULL_LAYER if shown else 0
	_tie = _on_plane(_tie_px(), TIE_HEIGHT)
	if _bob == Vector3.ZERO:
		# First frame: hanging straight, with a small nudge so it is seen to dangle.
		_bob = _tie + Vector3.DOWN * CORD
		_bob_last = _bob + Vector3(0.012, 0.0, 0.0)
	if _dragging:
		var before := _bob
		_bob = rope(_tie, _on_plane(get_local_mouse_position(), TIE_HEIGHT - CORD) + _grab_offset, CORD)
		# Its last STEP's worth of the drag's motion, so a let-go flings it on.
		_bob_last = _bob - (_bob - before) * (STEP / maxf(delta, STEP))
	else:
		_step_left = minf(_step_left + delta, 0.1)
		while _step_left >= STEP:
			_step_left -= STEP
			_wind_time += STEP
			var next := swing(_bob, _bob_last, _tie, STEP, wind_at(_wind_time) + tug_at(_wind_time, _tug()))
			_bob_last = _bob
			_bob = next
	var up := _bob.direction_to(_tie)
	var turn := Basis(Quaternion(Vector3.UP, up)) if up.dot(Vector3.UP) > -0.99 else Basis()
	_grip.global_transform = Transform3D(turn, _bob)
	_cord.global_transform = Transform3D(turn * Basis.from_scale(Vector3(1.0, _bob.distance_to(_tie), 1.0)), (_bob + _tie) / 2.0)
	# Touched, the tab lifts nearly flat, the way a pinched pull tab does, and the hand pinches its tip.
	var touched := _tab_hot or _dragging
	_tilt = lerpf(_tilt, TAB_PINCHED if touched else TAB_TILT, 1.0 - exp(-14.0 * delta))
	_tab.rotation.x = _tilt
	var tip := _tab.global_transform * Vector3(0.0, -TAB.y * 0.95, 0.0)
	_handle.carry_offset = tip - _bob
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var middle := _tab.global_transform * Vector3(0.0, -TAB.y / 2.0, 0.0)
		_grip_px = camera.unproject_position(middle)
		_grip_r = _grip_px.distance_to(camera.unproject_position(middle + camera.global_basis.x * TAB.x * 0.6))


## The lamp's slow, gentle shimmer (about 0.95..1): two slow waves, never a per-frame flicker.
static func pulse(time: float) -> float:
	return 1.0 - 0.03 * (0.5 + 0.5 * sin(time * 1.3)) - 0.02 * (0.5 + 0.5 * sin(time * 3.1 + 1.0))


## How many upgrades (not departments) cost `coins` or less (the drawing greys the rest).
static func affordable(coins: int) -> int:
	if _prices.is_empty():
		for node: Dictionary in NODES:
			if not node.get("dept", false):
				_prices.append(node.price)
		_prices.sort()
	return _prices.bsearch(coins, false)


## Whether the projector has been bought (desk card "projector").
static func unlocked(save: SaveGame) -> bool:
	return save.stamped.has("projector")


## NODES by id, built on the first lookup.
static var _by_id := {}


static func node_data(id: String) -> Dictionary:
	if _by_id.is_empty():
		for node: Dictionary in NODES:
			_by_id[node.id] = node
	return _by_id.get(id, {})


## Shown on the tree: its feature is unlocked, i.e. every desk card it and its ancestors need is stamped.
static func is_shown(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	return not node.is_empty() and node.get("needs", []).all(func(card: String) -> bool: return save.stamped.has(card)) \
			and (node.parent == "" or is_shown(node.parent, save))


## The nodes reachable in `save` that it has not seen reachable yet (save.tree_seen), in NODES order.
static func fresh(save: SaveGame) -> Array[String]:
	var out: Array[String] = []
	for node: Dictionary in NODES:
		if not save.tree_seen.has(node.id) and is_reachable(node.id, save):
			out.append(node.id)
	return out


## The first time the screen comes down, everything reachable counts as seen: nothing blinks NEW.
## Only what turns up after that is marked NEW.
static func mark_first_open(save: SaveGame) -> void:
	if not save.projector_opened:
		save.tree_seen.append_array(fresh(save))
	save.projector_opened = true


## Which THEMES have a node showing: each node counts for the theme heading nearest it.
static func themes_shown(save: SaveGame) -> Array[bool]:
	var out: Array[bool] = []
	out.resize(THEMES.size())
	out.fill(false)
	for node: Dictionary in NODES:
		if node.get("dept", false) or not is_shown(node.id, save):
			continue
		var best := 0
		for i in THEMES.size():
			if node.at.distance_to(THEMES[i][1]) < node.at.distance_to(THEMES[best][1]):
				best = i
		out[best] = true
	return out


## Reachable: the parent is open and every desk card it needs is stamped.
static func is_reachable(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	return not node.is_empty() and (node.parent == "" or is_open(node.parent, save)) \
			and node.get("needs", []).all(func(card: String) -> bool: return save.stamped.has(card))


static func is_dept(id: String) -> bool:
	return node_data(id).get("dept", false)


## Its children may show: a bought node, or a department whose cards and research are stamped.
static func is_open(id: String, save: SaveGame) -> bool:
	if is_dept(id):
		return is_reachable(id, save) and locked_by(id, save) == ""
	return save.tree_bought.has(id)


## The research card node `id` still waits for, "demo" if the demo locks it (dearer than
## Demo.NODE_PRICE_CAP), or "" (none, stamped, or the node already bought).
static func locked_by(id: String, save: SaveGame) -> String:
	if Events.Demo.active() and price_of(id, save) > Events.Demo.NODE_PRICE_CAP and not save.tree_bought.has(id):
		return "demo"
	var card: String = node_data(id).get("research", "")
	return "" if card == "" or save.stamped.has(card) or save.tree_bought.has(id) else card


## Bought for good: in tree_bought, or for the mat allowance (MAT), the mat at MAT_MAX.
static func is_bought(id: String, save: SaveGame) -> bool:
	return save.tree_bought.has(id) or (id == MAT and save.desk_capacity >= MAT_MAX)


## What node `id` costs now: its price, or for the mat allowance the next unit's (mat_price).
static func price_of(id: String, save: SaveGame) -> int:
	return mat_price(save.desk_capacity) if id == MAT else node_data(id).get("price", 0)


## The mat allowance's price with `capacity` units fitting on the mat now: MAT_BASE for the third
## unit, MAT_GROWTH times more for each after it, rounded to $50.
static func mat_price(capacity: int) -> int:
	return roundi(MAT_BASE * pow(MAT_GROWTH, maxi(capacity - 2, 0)) / 50.0) * 50


## Reachable, not bought and not waiting for research: a hold on it buys it (if the coins are there).
## Departments are never bought.
static func can_hold(id: String, save: SaveGame) -> bool:
	return not is_dept(id) and is_reachable(id, save) and not is_bought(id, save) and locked_by(id, save) == ""


static func can_buy(id: String, save: SaveGame) -> bool:
	return can_hold(id, save) and save.coins >= price_of(id, save)


## What node `id` waits for, as [heading, name] for its popup, or [] if nothing: its parent, then a
## desk card it needs, then its research. Under a closed department: what the department waits for.
static func requirement(id: String, save: SaveGame) -> Array:
	var node := node_data(id)
	if node.parent != "" and not is_open(node.parent, save):
		return requirement(node.parent, save) if is_dept(node.parent) else ["REQUIRES:", node_data(node.parent).title]
	for card: String in node.get("needs", []):
		if not save.stamped.has(card):
			return ["REQUIRES DESK CARD:", UpgradeDesk.card_data(card).get("title", card)]
	var research := locked_by(id, save)
	if research == "demo":
		return ["FULL GAME ONLY:", "Wishlist it on Steam"]
	if research != "":
		return ["REQUIRES RESEARCH:", UpgradeDesk.card_data(research).get("title", research).trim_prefix("RESEARCH: ")]
	return []


## Pays for node `id` and applies it; false (and nothing changes) if it can't be bought. The mat
## allowance is never filed in tree_bought: it is bought again until the mat is full (is_bought).
static func buy(id: String, save: SaveGame) -> bool:
	if not can_buy(id, save):
		return false
	save.coins -= price_of(id, save)
	if id != MAT:
		save.tree_bought.append(id)
	apply(id, save)
	return true


## What node `id` does to the save. The mat never holds more than MAT_MAX.
static func apply(id: String, save: SaveGame) -> void:
	var node := node_data(id)
	for stat in node.get("mul", {}):
		var value: Variant = save.get(stat) * node.mul[stat]
		save.set(stat, roundi(value) if save.get(stat) is int else value)
	for stat in node.get("add", {}):
		save.set(stat, save.get(stat) + node.add[stat])
	if node.get("hire", false):
		Associate.add_hand(save)
	if id == MAT:
		save.desk_capacity = mini(save.desk_capacity, MAT_MAX)


## What the merged chains' nodes did before the merge (save.migration 2): per chain, each old id's
## effect. Removed ids stay in an old save's tree_bought (nothing reads them) with their numbers.
const MERGED := [
	{desk_1 = {add = {desk_capacity = 2}}, desk_2 = {add = {desk_capacity = 2}}, desk_3 = {add = {desk_capacity = 2}},
		desk_4 = {add = {desk_capacity = 2}}, desk_5 = {add = {desk_capacity = 2}}, desk_6 = {add = {desk_capacity = 2}}},
	{pack_2 = {add = {pack_size = 5}}, pack_3 = {add = {pack_size = 10}}, pack_4 = {add = {pack_size = 25}}},
	{discount_2 = {mul = {pack_discount = 0.85}}, discount_3 = {mul = {pack_discount = 0.8}}},
	{vacuum_2 = {add = {vacuums = 1}}, vacuum_bag_1 = {add = {vacuum_capacity = 12}}, vacuum_suction = {mul = {vacuum_reach = 1.5}},
		vacuum_speed_2 = {mul = {vacuum_speed = 1.5}}, vacuum_bag_2 = {add = {vacuum_capacity = 30}}, vacuum_3 = {add = {vacuums = 1}}},
	{auto_reserve_2 = {add = {auto_reserve = 15}}, auto_smart_2 = {add = {auto_max_factor = -0.2}}},
	{associate_3 = {mul = {associate_speed = 1.5}}, associate_4 = {mul = {associate_speed = 1.3}}, associate_5 = {mul = {associate_speed = 1.3}}},
]


## An old save's merged chains: where the nodes it kept now do more than what it got from the old
## ones it bought (an old Hot-Desking alone: +2, now +4), the difference is added. Never takes away.
static func migrate_merged(save: SaveGame) -> void:
	for chain: Dictionary in MERGED:
		var had := {}
		var now := {}
		for id: String in chain:
			if not save.tree_bought.has(id):
				continue
			_sum(had, chain[id])
			if not node_data(id).is_empty():
				_sum(now, node_data(id))
		for stat: String in now:
			var old: float = had.get(stat, 0.0 if stat.begins_with("+") else 1.0)
			var key := stat.substr(1)
			if stat.begins_with("+") and absf(now[stat]) > absf(old):
				var sum: Variant = save.get(key) + (now[stat] - old)
				save.set(key, roundi(sum) if save.get(key) is int else sum)
			elif stat.begins_with("*") and absf(log(now[stat])) > absf(log(old)):
				var value: Variant = save.get(key) * now[stat] / old
				save.set(key, roundi(value) if save.get(key) is int else value)


## Adds an effect ({mul, add}) into a running total keyed "+stat" / "*stat".
static func _sum(into: Dictionary, effect: Dictionary) -> void:
	for stat: String in effect.get("add", {}):
		into["+" + stat] = into.get("+" + stat, 0.0) + effect.add[stat]
	for stat: String in effect.get("mul", {}):
		into["*" + stat] = into.get("*" + stat, 1.0) * effect.mul[stat]


## One STEP of the pull's tab, a Verlet point on a rope of CORD from `tie`: it keeps DAMP of its
## velocity (`bob` - `last`), falls, and the rope stops it going further than CORD.
static func swing(bob: Vector3, last: Vector3, tie: Vector3, delta: float, push := Vector3.ZERO) -> Vector3:
	return rope(tie, bob + (bob - last) * DAMP + (Vector3.DOWN * GRAVITY + push) * delta * delta, CORD)


## The tug's push `time` seconds in at `strength` (m/s²): sideways, at the pendulum's own rate.
static func tug_at(time: float, strength: float) -> Vector3:
	return Vector3.RIGHT * strength * sin(time * sqrt(GRAVITY / CORD))


## How many upgrades can be held (reachable, not bought, not locked) and how many of those `save`
## can pay for.
static func offers(save: SaveGame) -> Vector2i:
	var out := Vector2i.ZERO
	for node: Dictionary in NODES:
		if can_hold(node.id, save):
			out.x += 1
			out.y += int(save.coins >= price_of(node.id, save))
	return out


## The number stamped at the pennant's tip: how many upgrades can be bought now ("" for none).
static func count_text(buyable: int) -> String:
	return str(buyable) if buyable > 0 else ""


## Adds every upgrade `save` can hold and pay for now to `announced` (id -> true); true if any was
## new, so the pull tugs once per upgrade, not each time the coins climb back over its price.
static func announce(save: SaveGame, announced: Dictionary) -> bool:
	var grew := false
	for node: Dictionary in NODES:
		if not announced.has(node.id) and save.coins >= price_of(node.id, save) and can_hold(node.id, save):
			announced[node.id] = true
			grew = true
	return grew


## The tug's strength now: hard until the screen was first opened (an old save that bought upgrades
## has), then TUG_OFFER while _tug_left runs (easing out over its last second).
func _tug() -> float:
	var save := SaveManager.save
	if not save.projector_opened and save.tree_bought.is_empty():
		return TUG_FIRST
	return TUG_OFFER * clampf(_tug_left, 0.0, 1.0)


## The draught's push `time` seconds in: slow gusts that never quite repeat, never still for long.
static func wind_at(time: float) -> Vector3:
	var gust := 0.6 + 0.4 * sin(time * 0.37)
	return Vector3(WIND.x * sin(time * 1.3) * gust, 0.0, WIND.y * sin(time * 0.9 + 1.7) * gust)


## `point` pulled back to within `length` of `tie` (a rope: slack is fine, never longer).
static func rope(tie: Vector3, point: Vector3, length: float) -> Vector3:
	return point if tie.distance_to(point) <= length else tie + tie.direction_to(point) * length


## The screen is fully down and nobody pulls it: the overlay is up and a click on it rolls it away.
func _open() -> bool:
	return _drop >= 1.0 and not _dragging


func _has_point(point: Vector2) -> bool:
	# The pull (and the screen while it is pulled) clicks through to the 3D world, where the hand grabs it.
	if not visible or _dragging or (_drop < 1.0 and point.distance_to(_grip_px) < _grip_r):
		return false
	return _open() or (_drop > 0.0 and _fabric_rect().has_point(point))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	var save: SaveGame = SaveManager.save
	var on_slide := _lamp > 0.9 and _tree_rect().has_point(event.position if event is InputEventMouse else Vector2.INF)
	if button != null and button.pressed and on_slide and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_at(button.position, ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
		_hovered = _node_at(button.position)
		accept_event()
	elif button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			if _open() and (_close_rect().has_point(button.position) or not _fabric_rect().has_point(button.position)):
				_settle(false)  # The X, or a click on the overlay.
			elif on_slide:
				# A press on a node starts buying it; moved past CLICK_PX it pans instead.
				_panning = true
				_panned = false
				_pan_press = button.position
				_pan_start = _pan
				_hovered = _node_at(button.position)
				# Only a node that can be held reacts (bought or out of reach: no denied blink and sound).
				_holding = _hovered if can_hold(_hovered, save) else ""
				_hold = 0.0
				if button.double_click and _hovered == "":
					_recentre()
		else:
			_panning = false
			_panned = false
			_holding = ""
			_hold = 0.0
			_hovered = _node_at(button.position) if _lamp > 0.9 else ""
		accept_event()
	elif event is InputEventMouseMotion:
		var at := (event as InputEventMouseMotion).position
		if _panning and (_panned or at.distance_to(_pan_press) > CLICK_PX):
			_panned = true
			_pan = _clamp_pan(_pan_start + at - _pan_press)
		_hovered = _node_at(at) if _lamp > 0.9 and not _panned else ""
		_close_hot = _lamp > 0.9 and _close_rect().has_point(at)
		if _holding != "" and _hovered != _holding:
			_holding = ""
			_hold = 0.0
		mouse_default_cursor_shape = CURSOR_DRAG if _panned else CURSOR_POINTING_HAND if _close_hot or can_hold(_hovered, save) \
				else CURSOR_ARROW


## Esc rolls the screen away, taken before the pause menu sees it (unless that menu is already open).
func _input(event: InputEvent) -> void:
	if visible and (_down or _dragging) and event.is_action_pressed("ui_cancel") and not _menu_open():
		_dragging = false
		_settle(false)
		get_viewport().set_input_as_handled()


func _menu_open() -> bool:
	var scene := get_tree().current_scene
	var menu := scene.get_node_or_null(^"UI/InGameMenu") as CanvasItem if scene != null else null
	return menu != null and menu.visible


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovered = ""
		_holding = ""
		_close_hot = false


## Turns up: the pull (dropping in from above when `arrive`), built here.
func _show(arrive: bool) -> void:
	visible = true
	if arrive:
		_arrive = -80.0
		create_tween().tween_property(self, "_arrive", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_build_pull()


## The pull: a grey enamel pennant, a downward-pointing triangle stamped PULL, hanging by its top edge
## from a steel eyelet on a dark cord. Its face is tipped back toward the camera so the word reads from
## above. Hovered it glows faintly and lifts; the hand pinches its tip (Interactable reach + carried).
func _build_pull() -> void:
	_grip = StaticBody3D.new()
	_grip.collision_mask = 0
	_enamel.albedo_color = Color(0.6, 0.63, 0.59)
	_enamel.roughness = 0.45
	_enamel.emission_enabled = true
	_enamel.emission = BEAM
	_enamel.emission_energy_multiplier = 0.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.58, 0.57)
	steel.metallic = 0.8
	steel.roughness = 0.3
	# The tab hangs from the cord's end by its top edge, tipped back about that edge.
	_tab.rotation.x = TAB_TILT
	_grip.add_child(_tab)
	var prism := PrismMesh.new()
	prism.size = Vector3(TAB.x, TAB.y, 0.018)
	prism.material = _enamel
	var pennant := MeshInstance3D.new()
	pennant.mesh = prism
	pennant.rotation.z = PI  # Point down.
	pennant.position.y = -TAB.y / 2.0
	_tab.add_child(pennant)
	var word := Label3D.new()
	word.text = "PULL"
	word.font = FONT
	word.font_size = 64
	word.pixel_size = 0.0006
	word.outline_size = 0
	word.modulate = INK
	word.position = Vector3(0.0, -TAB.y * 0.3, 0.0095)
	_tab.add_child(word)
	# The buyable count on its own dark plate hung just under the tip, apart from the word.
	var rim := BoxMesh.new()
	rim.size = Vector3(0.046, 0.032, 0.005)
	rim.material = steel
	var plate_box := BoxMesh.new()
	plate_box.size = Vector3(0.04, 0.026, 0.006)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = STEEL
	plate_mat.roughness = 0.6
	plate_box.material = plate_mat
	for mesh: BoxMesh in [rim, plate_box]:
		var slab := MeshInstance3D.new()
		slab.mesh = mesh
		_badge.add_child(slab)
	_count.font = FONT
	_count.font_size = 44
	_count.pixel_size = 0.0006
	_count.outline_size = 0
	_count.modulate = BEAM
	_count.position.z = 0.0035
	_badge.add_child(_count)
	_badge.position = Vector3(0.0, -TAB.y - 0.01, 0.0)
	_badge.visible = false
	_tab.add_child(_badge)
	var eye := CylinderMesh.new()
	eye.top_radius = 0.008
	eye.bottom_radius = 0.012
	eye.height = 0.025
	eye.material = steel
	var eyelet := MeshInstance3D.new()
	eyelet.mesh = eye
	_grip.add_child(eyelet)
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = TAB.x * 0.6
	shape.position.y = -TAB.y / 2.0
	_grip.add_child(shape)
	_handle = Interactable.new()
	_handle.reach = true
	_handle.carried = true
	_handle.tooltip = "Pull down to open the projector: the upgrade tree. Hold an upgrade there to buy it with coins."
	_handle.hovered.connect(_touch_tab.bind(true))
	_handle.unhovered.connect(_touch_tab.bind(false))
	_handle.grabbed.connect(_grab)
	_handle.released.connect(_let_go)
	_grip.add_child(_handle)
	var cord := CylinderMesh.new()
	cord.top_radius = 0.005
	cord.bottom_radius = 0.005
	cord.height = 1.0
	cord.radial_segments = 6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = INK
	cord.material = dark
	_cord.mesh = cord
	add_child(_grip)
	add_child(_cord)


func _touch_tab(hot: bool) -> void:
	_tab_hot = hot


func _grab() -> void:
	_dragging = true
	_press_y = get_local_mouse_position().y
	_press_drop = _drop
	_grab_offset = _bob - _on_plane(get_local_mouse_position(), TIE_HEIGHT - CORD)
	_lamp_off()
	if _settling != null:
		_settling.kill()


## Let go of the pull: a click opens the screen, a short pull springs back to where it was.
func _let_go() -> void:
	if not _dragging:
		return  # The screen already took over (LET_GO).
	_dragging = false
	var clicked := absf(get_local_mouse_position().y - _press_y) < CLICK_PX
	_settle(_press_drop < 0.5 if clicked else _drop > 0.5)


func _settle(down: bool) -> void:
	_down = down
	if _settling != null:
		_settling.kill()
	_settling = create_tween()
	if down:
		mark_first_open(SaveManager.save)
		_tug_left = 0.0
		_play(roll_down_sound)
		_settling.tween_property(self, "_drop", 1.0, 0.35 * (1.0 - _drop) + 0.05).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		# The lamp warms up with a stutter.
		for level: float in [0.6, 0.1, 0.8, 0.3, 1.0]:
			_settling.tween_property(self, "_lamp", level, 0.05)
	else:
		_lamp_off()
		_play(roll_up_sound)
		_settling.tween_property(self, "_drop", 0.0, 0.3 * _drop + 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _lamp_off() -> void:
	# Rolled up: what was marked NEW has been seen.
	for id in _fresh:
		SaveManager.save.tree_seen.append(id)
	_fresh.clear()
	_layer_key = []
	_lamp = 0.0
	_hovered = ""
	_holding = ""
	_close_hot = false


func _play(stream: AudioStream) -> void:
	if stream != null:
		_sfx.stream = stream
		_sfx.play()


# --- Layout ---

func _screen_rect() -> Rect2:
	return Rect2(size * SCREEN.position, size * SCREEN.size)


## How far the fabric can unroll (px).
func _span() -> float:
	return _screen_rect().size.y - ROLLER_H - BAR_H


func _fabric_rect() -> Rect2:
	var screen := _screen_rect()
	return Rect2(screen.position.x + 12.0, ROLLER_H, screen.size.x - 24.0, _drop * _span() + BAR_H)


## The weighted bar at the fabric's foot (before the sway).
func _bar_rect() -> Rect2:
	var fabric := _fabric_rect()
	return Rect2(fabric.position.x - 4.0, fabric.end.y - BAR_H, fabric.size.x + 8.0, BAR_H)


## Where the cord is tied, on screen: under the bar, or just above the view while the screen is up
## (then only the pull shows, hanging in from the top).
func _tie_px() -> Vector2:
	var bar := _bar_rect()
	var y := lerpf(-12.0, bar.end.y, minf(_drop * 10.0, 1.0)) + _arrive
	return Vector2(lerpf(bar.position.x, bar.end.x, TAB_AT) + _sway, y)


func _close_rect() -> Rect2:
	var fabric := _fabric_rect()
	return Rect2(fabric.end.x - CLOSE - 18.0, fabric.position.y + 16.0, CLOSE, CLOSE)


## Where the camera ray through `point` (px) crosses the horizontal plane at `height`.
func _on_plane(point: Vector2, height: float) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(0.0, height, 0.0)
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	return hit if hit != null else Vector3(0.0, height, 0.0)


## The part of the slide under the heading where the tree is drawn, panned and zoomed.
func _tree_rect() -> Rect2:
	var fabric := _fabric_rect()
	var top := fabric.position.y + fabric.size.y * 0.13
	return Rect2(fabric.position.x, top, fabric.size.x, maxf(fabric.end.y - BAR_H - top, 0.0))


## The wheel's centre, its scale (px per unit, x and y) and the node radius, panned and zoomed.
## On a wide screen it spreads sideways, at most to WIDEN times its height scale.
func _wheel() -> Array:
	var area := _tree_rect()
	var uy := area.size.y / 2.0 / 1.25
	var unit := Vector2(minf(area.size.x / 2.0 / 1.05, uy * WIDEN), uy)
	return [area.get_center() + Vector2(0.0, uy * 0.06) + _pan, unit * _zoom, _radius(unit) * _zoom]


func _radius(unit: Vector2) -> float:
	return clampf(unit.y * 0.1, 20.0, 42.0)


## Zooms by `factor` keeping the tree point under `point` where it is.
func _zoom_at(point: Vector2, factor: float) -> void:
	var wheel := _wheel()
	var under: Vector2 = (point - wheel[0]) / wheel[1]
	var base_unit: Vector2 = wheel[1] / _zoom
	var middle: Vector2 = wheel[0] - _pan
	var old := _zoom
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var pan := point - under * base_unit * _zoom - middle
	# Zooming into empty slide that would push the whole tree out is refused.
	if _keeps_tree(pan):
		_pan = pan
	else:
		_zoom = old


## `pan` if a node (or the hub) stays well inside the slide with it, else the closest move along one
## axis that does, else the current pan: the tree can't be lost off the slide.
func _clamp_pan(pan: Vector2) -> Vector2:
	for option: Vector2 in [pan, Vector2(pan.x, _pan.y), Vector2(_pan.x, pan.y)]:
		if _keeps_tree(option):
			return option
	return _pan


func _keeps_tree(pan: Vector2) -> bool:
	var wheel := _wheel()
	var centre: Vector2 = wheel[0] - _pan + pan
	var inside := _tree_rect().grow(-wheel[2] * 1.5)
	if inside.has_point(centre):
		return true
	for node: Dictionary in NODES:
		if inside.has_point(centre + node.at * wheel[1]):
			return true
	return false


## Eases the view back to the start: no pan, zoom 1.
func _recentre() -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_pan", Vector2.ZERO, 0.25)
	tween.tween_property(self, "_zoom", 1.0, 0.25)


func _node_at(point: Vector2) -> String:
	if not _tree_rect().has_point(point):
		return ""
	var wheel := _wheel()
	var r: float = wheel[2]
	for node: Dictionary in NODES:
		if not _shown.has(node.id):
			continue
		var at: Vector2 = wheel[0] + node.at * wheel[1]
		if plate(node.id, at, r).grow(4.0).has_point(point) if is_dept(node.id) else point.distance_to(at) < r * 1.2:
			return node.id
	return ""


# --- Drawing ---

func _draw() -> void:
	if _drop <= 0.0:
		return  # Rolled up out of sight: only the pull shows.
	var save: SaveGame = SaveManager.save
	var screen := _screen_rect()
	var fabric := _fabric_rect()
	var bar := _bar_rect()
	# The sheet: its foot trails the swing; a lit left edge and a dark right edge give it thickness.
	var sheet := PackedVector2Array([fabric.position, Vector2(fabric.end.x, fabric.position.y),
			fabric.end + Vector2(_sway, 0.0), Vector2(fabric.position.x + _sway, fabric.end.y)])
	var shadow := sheet.duplicate()
	for i in shadow.size():
		shadow[i] += Vector2(10.0, 8.0)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(sheet, FABRIC)
	_draw_content(save, fabric)
	draw_line(sheet[0], sheet[3], Color(1, 1, 1, 0.14), 2.0)
	draw_line(sheet[1], sheet[2], Color(0, 0, 0, 0.5), 3.0)
	# The roller's shadow on the sheet just under it.
	for i in 6:
		draw_rect(Rect2(fabric.position.x, fabric.position.y + i * 4.0, fabric.size.x, 4.0), Color(0, 0, 0, 0.28 * (1.0 - i / 6.0)))
	# The roller: the rolled sheet (thinner the more is down) under a steel tube in end brackets.
	_draw_tube(Rect2(fabric.position.x, ROLLER_H - 6.0, fabric.size.x, lerpf(16.0, 7.0, _drop)), FABRIC)
	_draw_tube(Rect2(screen.position.x, 0.0, screen.size.x, ROLLER_H), TUBE)
	for x: float in [screen.position.x - 12.0, screen.end.x - 6.0]:
		draw_rect(Rect2(x, -6.0, 18.0, ROLLER_H + 12.0), STEEL)
		draw_circle(Vector2(x + 9.0, ROLLER_H / 2.0), 4.0, TUBE)
	# The weighted bar, and the latch on its right where the pull's cord is tied.
	_draw_tube(Rect2(bar.position + Vector2(_sway, 0.0), bar.size), TUBE)
	var tie := _tie_px()
	draw_rect(Rect2(tie + Vector2(-9.0, -BAR_H - 4.0), Vector2(18.0, BAR_H + 8.0)), STEEL)
	draw_circle(tie + Vector2(0.0, -BAR_H / 2.0), 3.5, TUBE)


## A cylinder seen from the side: horizontal bands, lit from above, dark underneath.
func _draw_tube(rect: Rect2, color: Color) -> void:
	const BANDS := 8
	for i in BANDS:
		var t := (i + 0.5) / BANDS
		var light := 0.45 + 0.75 * sin(PI * t) * (1.2 - t)
		draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * i / BANDS, rect.size.x, rect.size.y / BANDS + 0.5),
				Color(color.r * light, color.g * light, color.b * light))


func _draw_content(save: SaveGame, fabric: Rect2) -> void:
	if _lamp <= 0.0:
		return
	var light := _lamp * pulse(Time.get_ticks_msec() / 1000.0)
	# The beam: a cold, uneven wash brightest in the middle.
	draw_texture_rect(_beam, fabric, false, Color(1, 1, 1, light))
	var ink := Color(INK, _lamp)
	var top := fabric.position.y + fabric.size.y * 0.04
	var head := clampf(fabric.size.x * 0.035, 22.0, 44.0)
	draw_string(FONT, Vector2(fabric.position.x, top + head), tr("GROWTH INITIATIVES"), HORIZONTAL_ALIGNMENT_CENTER, fabric.size.x, int(head), ink)
	draw_string(FONT, Vector2(fabric.position.x, top + head * 1.6), tr("FORM GW-7   |   HOLD TO APPROVE"),
			HORIZONTAL_ALIGNMENT_CENTER, fabric.size.x, int(head * 0.42), Color(INK, _lamp * 0.75))
	# What there is to spend, live, in the sheet's top-left corner.
	var stat := int(head * 0.62)
	var corner := Vector2(fabric.position.x + 22.0, top + stat)
	draw_string(FONT, corner, tr("BUDGET  $%d") % save.coins, HORIZONTAL_ALIGNMENT_LEFT, -1, stat, ink)
	draw_string(FONT, corner + Vector2(0.0, stat * 1.2), tr("FINDINGS  ¶%d") % save.findings, HORIZONTAL_ALIGNMENT_LEFT, -1, stat, ink)
	# The close button: a dark stamped square with an X, top right.
	var close := _close_rect()
	draw_rect(close, Color(INK, _lamp * (1.0 if _close_hot else 0.8)))
	var x := close.grow(-12.0)
	var paper := Color(BEAM, _lamp)
	draw_line(x.position, x.end, paper, 3.0, true)
	draw_line(Vector2(x.end.x, x.position.y), Vector2(x.position.x, x.end.y), paper, 3.0, true)


## The tree's nodes and edges on _layer, around its origin (the hub). Drawn at full strength; the
## lamp and its pulse dim the layer (modulate). Only redrawn when _layer_key changes.
func _draw_layer() -> void:
	var save: SaveGame = SaveManager.save
	var wheel := _wheel()
	var unit: Vector2 = wheel[1]
	var r: float = wheel[2]
	var faint := PackedVector2Array()
	var locked := PackedVector2Array()
	for node: Dictionary in NODES:
		if not _shown.has(node.id):
			continue
		# Edge to edge: the line stops at both circles instead of running into them (under a
		# department's opaque plate it simply runs on to its centre).
		var from: Vector2 = Vector2.ZERO if node.parent == "" else node_data(node.parent).at * unit
		var to: Vector2 = node.at * unit
		var dir := from.direction_to(to)
		var from_r := r * 1.1 if node.parent == "" else _size(node.parent, r)
		var to_r := _size(node.id, r)
		if from.distance_to(to) > from_r + to_r + r:
			var start := from + dir * from_r
			var end := to - dir * to_r
			if not is_reachable(node.id, save):
				_dashes(faint, start, end, 7.0)
			elif locked_by(node.id, save) != "":
				_dashes(locked, start, end, 9.0)
			else:
				_layer.draw_line(start, end, Color(INK, 0.6), 3.0, true)
	if not faint.is_empty():
		_layer.draw_multiline(faint, Color(INK, 0.15), 2.0)
	if not locked.is_empty():
		_layer.draw_multiline(locked, Color(INK, 0.35), 3.0)
	# Each theme's faint heading past the end of its branch.
	var heading := int(clampf(r * 0.8, 12.0, 44.0))
	for i in THEMES.size():
		if i >= _themes_shown.size() or not _themes_shown[i]:
			continue
		var named: Array = THEMES[i]
		_layer.draw_string(FONT, named[1] * unit - Vector2(300.0, 0.0), tr(named[0]), HORIZONTAL_ALIGNMENT_CENTER, 600.0, heading, Color(INK, 0.22))
	# The hub: a cabbage cross-section, the one green thing on the slide.
	_layer.draw_circle(Vector2.ZERO, r * 1.1, CABBAGE)
	_layer.draw_circle(Vector2.ZERO, r * 1.1, INK, false, 3.0, true)
	for i in 3:
		_layer.draw_arc(Vector2(r * 0.15, 0), r * (0.3 + i * 0.25), PI * 0.6, PI * 1.9, 16, Color(0.9, 1.0, 0.8, 0.8), 2.0, true)
	for node: Dictionary in NODES:
		if _shown.has(node.id):
			_draw_node(node, node.at * unit, r, save)


## Dash segments from `from` to `to` (`dash` long, same gap) added to a multiline batch.
static func _dashes(into: PackedVector2Array, from: Vector2, to: Vector2, dash: float) -> void:
	var length := from.distance_to(to)
	var dir := from.direction_to(to)
	var at := 0.0
	while at < length:
		into.append(from + dir * at)
		into.append(from + dir * minf(at + dash, length))
		at += dash * 2.0


## What moves per frame, on _top (projector coordinates): the hint, the hovered node's ring, the hold
## arc and the popup. Steady: the lamp's pulse doesn't reach it.
func _draw_top() -> void:
	var save: SaveGame = SaveManager.save
	_top.draw_set_transform(-_tree.position)
	var wheel := _wheel()
	var r: float = wheel[2]
	var area := _tree_rect()
	var hint := tr("DRAG TO MOVE   |   WHEEL TO ZOOM") if _pan == Vector2.ZERO and is_equal_approx(_zoom, 1.0) else tr("DOUBLE-CLICK TO RECENTRE")
	_top.draw_string(FONT, area.end - Vector2(area.size.x, 12.0), hint, HORIZONTAL_ALIGNMENT_RIGHT, area.size.x - 14.0, 15, Color(INK, _lamp * 0.55))
	if _holding != "":
		var at: Vector2 = wheel[0] + node_data(_holding).at * wheel[1]
		if _denied > 0.0:
			_top.draw_arc(at, r + 4.0, 0.0, TAU, 32, Color(DENIED, _lamp), 4.0, true)
		elif _hold > 0.0:
			_top.draw_arc(at, r + 6.0, -PI / 2.0, -PI / 2.0 + TAU * _hold, 40, Color(INK, _lamp), 5.0, true)
	# NEW: a ring pulsing out from each node showing for the first time.
	var beat := fmod(Time.get_ticks_msec() / 1000.0, NEW_PULSE) / NEW_PULSE
	for id in _fresh:
		var at: Vector2 = wheel[0] + node_data(id).at * wheel[1]
		var fade := Color(INK, _lamp * 0.7 * (1.0 - beat))
		var corner := Vector2(r * 0.8, r * 1.05)
		if is_dept(id):
			var box := plate(id, at, r)
			_draw_plate(_top, box.grow(r * 0.35 * beat), Color.TRANSPARENT, fade, 3.0)
			corner = box.end - at + Vector2(4.0, 0.0)
		else:
			_top.draw_arc(at, r * (1.15 + 0.35 * beat), 0.0, TAU, 40, fade, 3.0, true)
		_top.draw_string(FONT, at + corner, tr("NEW"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(clampf(r * 0.6, 14.0, 28.0)), Color(INK, _lamp))
	if _hovered != "":
		var at: Vector2 = wheel[0] + node_data(_hovered).at * wheel[1]
		var glow := Color(BEAM.lerp(Color.WHITE, 0.3), _lamp * 0.25)
		var reach := r
		if is_dept(_hovered):
			var box := plate(_hovered, at, r)
			_draw_plate(_top, box, glow, Color.TRANSPARENT, 0.0)
			reach = box.size.x / 2.0
		else:
			_top.draw_circle(at, r, glow)
		_draw_popup(node_data(_hovered), at, reach, save, _lamp, area)


## Where an edge stops short of node `id`: its circle's rim, or (under a department's plate) nowhere.
static func _size(id: String, r: float) -> float:
	return 0.0 if is_dept(id) else r


func _draw_node(node: Dictionary, at: Vector2, r: float, save: SaveGame) -> void:
	if node.get("dept", false):
		_draw_dept(node, at, r, save)
		return
	var bought := is_bought(node.id, save)
	var reachable := is_reachable(node.id, save)
	var locked := reachable and locked_by(node.id, save) != ""
	var alpha := 0.16 if not reachable else 0.3 if locked else 1.0 if bought or save.coins >= price_of(node.id, save) else 0.35
	var ink := Color(INK, alpha)
	if bought:
		_layer.draw_circle(at, r, ink)
	if locked or not reachable:
		# A broken rim: on the plan, not yet approved (a padlock when research holds it).
		var rim := PackedVector2Array()
		for i in 12:
			for j in 3:
				rim.append(at + Vector2.from_angle(TAU * (i + 0.2 * j) / 12.0) * r)
				rim.append(at + Vector2.from_angle(TAU * (i + 0.2 * (j + 1)) / 12.0) * r)
		_layer.draw_multiline(rim, ink, 3.0)
	else:
		_layer.draw_circle(at, r, ink, false, 3.0, true)
	_draw_icon("padlock" if locked else node.icon, at, r * 0.55, Color(BEAM, alpha) if bought else ink)
	# Bought shows as the filled disc (the popup says APPROVED): a word under it would run into
	# the next node's title in the vertical chains.
	var font_size := int(clampf(r * 0.6, 9.0, 34.0))
	_layer.draw_string(FONT, at + Vector2(-200.0, -r - 8.0), tr(node.title), HORIZONTAL_ALIGNMENT_CENTER, 400.0, font_size, ink)


## A department: info only, so a rounded plate in the hub's green with its glyph and name, never
## a circle (circles are bought). Closed (its cards or research missing) it is faded, a padlock for research.
func _draw_dept(node: Dictionary, at: Vector2, r: float, save: SaveGame) -> void:
	var open := is_open(node.id, save)
	var locked := is_reachable(node.id, save) and not open
	var alpha := 1.0 if open else 0.45 if locked else 0.3
	var ink := Color(INK, alpha)
	var box := plate(node.id, at, r)
	# Opaque (faded toward the fabric, not see-through) so the edges under it stay hidden.
	_draw_plate(_layer, box, FABRIC.lerp(CABBAGE, alpha), ink, 4.0 if open else 2.0)
	var font_size := _plate_font(r)
	var icon_at := Vector2(box.position.x + box.size.y * 0.55, at.y)
	_draw_icon("padlock" if locked else node.icon, icon_at, box.size.y * 0.3, ink)
	_layer.draw_string(FONT, Vector2(box.position.x + box.size.y, at.y + font_size * 0.36), tr(node.title),
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)


## A department plate's type size for node radius `r`.
static func _plate_font(r: float) -> int:
	return int(clampf(r * 0.7, 12.0, 32.0))


## A department's plate around `at`, sized to its translated name with room for the glyph on its left.
static func plate(id: String, at: Vector2, r: float) -> Rect2:
	var font_size := _plate_font(r)
	var title := TranslationServer.translate(node_data(id).get("title", ""))
	var height := font_size * 2.0
	var dims := Vector2(FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + height * 1.45, height)
	return Rect2(at - dims / 2.0, dims)


## A rounded box on `canvas`: `fill` inside, a `border` rim `width` wide.
static func _draw_plate(canvas: CanvasItem, box: Rect2, fill: Color, border: Color, width: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(int(width))
	style.set_corner_radius_all(int(box.size.y * 0.25))
	style.anti_aliasing = true
	style.draw(canvas.get_canvas_item(), box)


## Simple line glyphs, centred on `at`, about `s` from the centre to the edge.
func _draw_icon(icon: String, at: Vector2, s: float, color: Color) -> void:
	match icon:
		"megaphone":
			_layer.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.6, -s * 0.3), at + Vector2(s * 0.7, -s * 0.8),
					at + Vector2(s * 0.7, s * 0.8), at + Vector2(-s * 0.6, s * 0.3)]), color)
			_layer.draw_rect(Rect2(at + Vector2(-s, -s * 0.3), Vector2(s * 0.4, s * 0.6)), color)
		"crate":
			var box := Rect2(at - Vector2(s, s) * 0.8, Vector2(s, s) * 1.6)
			_layer.draw_rect(box, color, false, 2.5)
			_layer.draw_line(box.position, box.end, color, 2.0)
			_layer.draw_line(Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), color, 2.0)
		"clock":
			_layer.draw_arc(at, s * 0.85, 0.0, TAU, 24, color, 2.5, true)
			_layer.draw_line(at, at + Vector2(0, -s * 0.6), color, 2.5)
			_layer.draw_line(at, at + Vector2(s * 0.45, 0), color, 2.5)
		"lens":
			_layer.draw_arc(at + Vector2(-s * 0.2, -s * 0.2), s * 0.55, 0.0, TAU, 20, color, 2.5, true)
			_layer.draw_line(at + Vector2(s * 0.2, s * 0.2), at + Vector2(s * 0.85, s * 0.85), color, 4.0)
		"hand":
			# A mitten-like office hand: palm, four fingers, a thumb.
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.5, -s * 0.15), Vector2(s, s * 0.85)), color)
			for i in 4:
				var tall := s * (0.55 if i in [0, 3] else 0.7)
				_layer.draw_rect(Rect2(at + Vector2(-s * 0.5 + i * s * 0.26, -s * 0.15 - tall), Vector2(s * 0.2, tall)), color)
			_layer.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.5, s * 0.05), at + Vector2(-s * 0.95, -s * 0.3),
					at + Vector2(-s * 0.8, -s * 0.45), at + Vector2(-s * 0.5, -s * 0.2)]), color)
		"belt":
			for x: float in [-0.55, 0.55]:
				_layer.draw_arc(at + Vector2(s * x, 0), s * 0.3, 0.0, TAU, 14, color, 2.5, true)
			_layer.draw_line(at + Vector2(-s * 0.55, -s * 0.3), at + Vector2(s * 0.55, -s * 0.3), color, 2.5)
			_layer.draw_line(at + Vector2(-s * 0.55, s * 0.3), at + Vector2(s * 0.55, s * 0.3), color, 2.5)
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.25, -s * 0.75), Vector2(s * 0.5, s * 0.4)), color)
		"padlock":
			_layer.draw_arc(at + Vector2(0, -s * 0.15), s * 0.42, PI, TAU, 12, color, 3.0, true)
			for x: float in [-0.42, 0.42]:
				_layer.draw_line(at + Vector2(s * x, -s * 0.15), at + Vector2(s * x, s * 0.1), color, 3.0)
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.7, s * 0.05), Vector2(s * 1.4, s * 0.85)), color)
			_layer.draw_circle(at + Vector2(0, s * 0.4), s * 0.13, Color(FABRIC, color.a))
		"pilcrow":
			_layer.draw_string(FONT, at + Vector2(-s, s * 0.6), "¶+", HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 1.5), color)
		"desk":
			# A desk top seen from above, with two units on it.
			_layer.draw_rect(Rect2(at - Vector2(s * 0.9, s * 0.6), Vector2(s * 1.8, s * 1.2)), color, false, 2.5)
			for x: float in [-0.4, 0.4]:
				_layer.draw_circle(at + Vector2(s * x, 0), s * 0.28, color)
		"puck":
			# The coin unit: a disc with its lamp, and a coin beside it.
			_layer.draw_arc(at + Vector2(-s * 0.15, 0), s * 0.7, 0.0, TAU, 20, color, 2.5, true)
			_layer.draw_circle(at + Vector2(-s * 0.15, -s * 0.4), s * 0.14, color)
			_layer.draw_circle(at + Vector2(s * 0.75, s * 0.55), s * 0.22, color)
		"chair":
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.5, -s * 0.8), Vector2(s * 0.25, s * 1.0)), color)
			_layer.draw_rect(Rect2(at + Vector2(-s * 0.5, 0), Vector2(s * 1.0, s * 0.22)), color)
			for x: float in [-0.45, 0.4]:
				_layer.draw_line(at + Vector2(s * x, s * 0.2), at + Vector2(s * x, s * 0.85), color, 2.5)


func _draw_popup(node: Dictionary, at: Vector2, r: float, save: SaveGame, light: float, fabric: Rect2) -> void:
	var width := 430.0
	var lines: PackedStringArray = tr(node.body).split("\n")
	var needs := requirement(node.id, save)
	var height := 100.0 + lines.size() * 27.0 + (32.0 if not needs.is_empty() else 0.0)
	var pos := at + Vector2(r + 14.0, -height / 2.0)
	if pos.x + width > fabric.end.x:
		pos.x = at.x - r - 14.0 - width
	pos.x = clampf(pos.x, fabric.position.x + 6.0, fabric.end.x - width - 6.0)
	pos.y = clampf(pos.y, fabric.position.y + 6.0, fabric.end.y - height - 6.0)
	var box := Rect2(pos, Vector2(width, height))
	_top.draw_rect(box, Color(INK, light * 0.92))
	var paper := Color(BEAM, light)
	_top.draw_string(FONT, pos + Vector2(16, 38), tr(node.title), HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 30, paper)
	for i in lines.size():
		_top.draw_string(FONT, pos + Vector2(16, 70 + i * 27), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 21, Color(paper, light * 0.8))
	if not needs.is_empty():
		# What it waits for, on one line, its name under it.
		var red := Color(0.85, 0.35, 0.3, light)
		_top.draw_string(FONT, pos + Vector2(16, height - 48), tr(needs[0]), HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 21, red)
		_top.draw_string(FONT, pos + Vector2(16, height - 16), tr(needs[1]), HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 24, red)
		return
	if node.get("dept", false):
		_top.draw_string(FONT, pos + Vector2(16, height - 16), tr("DEPARTMENT"), HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 24, paper)
		return
	var bought := is_bought(node.id, save)
	var price := tr("APPROVED") if bought else tr("COST $%d") % price_of(node.id, save)
	if node.id == MAT:
		price += "   " + tr("MAT %d / %d") % [save.desk_capacity, MAT_MAX]
	var short: bool = not bought and save.coins < price_of(node.id, save)
	_top.draw_string(FONT, pos + Vector2(16, height - 16), price, HORIZONTAL_ALIGNMENT_LEFT, width - 32.0, 24,
			Color(0.85, 0.35, 0.3, light) if short else paper)
