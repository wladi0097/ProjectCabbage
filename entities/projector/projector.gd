class_name Projector
extends Control
## The projector screen (coin upgrades), there once the "projector" desk card is stamped. A roller
## hangs at the top of the screen with a pull tab; drag the tab down (heavy, like the press lever)
## and the screen unrolls, past half it drops the rest of the way and the projector lamp flickers
## on, showing the upgrade tree (NODES). A click on the tab, or dragging it back up, rolls it up.
## The game keeps running behind it. Each node: a circle with a glyph and its name above; hovered,
## a block with name, description and cost; held for HOLD_TIME, it is bought with coins. A node
## shows once its parent is bought and the desk cards it `needs` are stamped. A node with `research`
## (a research card on the desk) shows locked until that card is stamped: greyed, a padlock, its
## popup naming the research, and a hold is refused. Its children stay hidden until it is bought. Like a phone map, a
## held press dragged across the slide pans the tree (kept on the slide) and the wheel zooms it; a double-click recentres.
##
## Drawn in 2D on a full-screen Control rather than a 3D quad: the camera looks steeply down on the
## desk, so a hanging 3D screen would shrink to a thin strip, and a 2D overlay gets mouse hover and
## hold for free. _has_point keeps the rest of the screen clicking through to the desk.

enum Size { SMALL, FULL }

## Every node, in one list for retuning (prices from reports/economy_rework_2026-10-31.md). A bought
## node multiplies each save number in `mul`, raises each in `add`, and `hire` adds one hand.
## `research` names the desk card that unlocks it (see locked_by).
## `at` is the spot on the wheel (centre 0,0), laid out radially by the supply agent's layout script
## (each first-ring node a sector, chains run straight out): slogans and campaigns up, the consultant,
## associate speed and seating, window targets, manager and bin round the right, the hired hands
## and QA down, coin vacuums down-left, supply and auto-buy left, the combo and lamp up-left.
const NODES := [
	{id = "slogan_1", parent = "", at = Vector2(0.00, -0.75), icon = "megaphone", price = 25,
		mul = {marketing = 1.25}, title = "SLOGAN I",
		body = "\"Cabbage. Because you have to eat.\"
The street pays 25% more per unit."},
	{id = "slogan_2", parent = "slogan_1", at = Vector2(0.00, -1.11), icon = "megaphone", price = 30,
		mul = {marketing = 1.25}, title = "SLOGAN II",
		body = "\"Cabbage. Compliance tastes green.\"
The street pays 25% more per unit."},
	{id = "slogan_3", parent = "slogan_2", at = Vector2(-0.17, -1.48), icon = "megaphone", price = 1000,
		mul = {marketing = 1.25}, title = "SLOGAN III",
		body = "\"Cabbage. You were expecting something else?\"
The street pays 25% more per unit."},
	{id = "slogan_4", parent = "slogan_3", at = Vector2(-0.44, -1.85), icon = "megaphone", price = 5000,
		research = "research_sentiment", mul = {marketing = 1.25}, title = "SLOGAN IV",
		body = "\"Cabbage. It has been decided.\"
The street pays 25% more per unit."},
	{id = "slogan_5", parent = "slogan_4", at = Vector2(-0.53, -2.23), icon = "megaphone", price = 18000,
		mul = {marketing = 1.25}, title = "SLOGAN V",
		body = "\"Cabbage. Your household quota is attached.\"
The street pays 25% more per unit."},
	{id = "slogan_6", parent = "slogan_5", at = Vector2(-0.62, -2.60), icon = "megaphone", price = 65000,
		mul = {marketing = 1.25}, title = "SLOGAN VI",
		body = "\"Cabbage.\"
The street pays 25% more per unit."},
	{id = "pack_1", parent = "", at = Vector2(-0.74, 0.13), icon = "crate", price = 25,
		add = {pack_size = 3}, title = "BULK PROCUREMENT",
		body = "Three more units in every pack.
Volume is policy."},
	{id = "pack_2", parent = "pack_1", at = Vector2(-0.96, 0.71), icon = "crate", price = 500,
		research = "research_materials", add = {pack_size = 5}, title = "PACK +5",
		body = "Five more units in every pack.
The supplier has been informed."},
	{id = "conveyor_1", parent = "pack_1", at = Vector2(-1.13, 0.43), icon = "belt", price = 500,
		research = "research_materials", mul = {dispense_interval = 0.5}, add = {desk_capacity = 2}, title = "CONVEYOR RETROFIT",
		body = "The ramp is motorised.
Units arrive twice as fast, two more fit on the mat."},
	{id = "conveyor_2", parent = "conveyor_1", at = Vector2(-1.50, 0.73), icon = "belt", price = 11000,
		mul = {dispense_interval = 0.67}, add = {desk_capacity = 2}, title = "CONVEYOR II",
		body = "A second motor, same belt.
Units arrive 50% faster, two more fit on the mat."},
	{id = "conveyor_3", parent = "conveyor_2", at = Vector2(-1.91, 0.93), icon = "belt", price = 45000,
		mul = {dispense_interval = 0.67}, add = {desk_capacity = 2}, title = "CONVEYOR III",
		body = "Safety guards removed.
Units arrive 50% faster, two more fit on the mat."},
	{id = "associate_1", parent = "", at = Vector2(0.65, -0.37), icon = "clock", price = 25,
		needs = ["junior_associate"], mul = {associate_speed = 1.5}, title = "BRISK WALK I",
		body = "A stopwatch on every associate's desk.
Associates move 50% faster."},
	{id = "associate_2", parent = "associate_1", at = Vector2(0.94, -0.74), icon = "clock", price = 65,
		research = "performance_review", mul = {associate_speed = 1.5}, title = "BRISK WALK II",
		body = "Lunch is now a standing meeting.
Associates move 50% faster."},
	{id = "associate_3", parent = "associate_2", at = Vector2(1.29, -1.01), icon = "clock", price = 2250,
		mul = {associate_speed = 1.5}, title = "BRISK WALK III",
		body = "Chairs have been removed from the floor.
Associates move 50% faster."},
	{id = "hire_associate_2", parent = "", at = Vector2(0.10, 0.74), icon = "hand", price = 25,
		needs = ["junior_associate"], hire = true, title = "HIRE ASSOCIATE II",
		body = "Headcount approved.
One more hand at the mat."},
	{id = "hire_associate_3", parent = "hire_associate_2", at = Vector2(0.16, 1.11), icon = "hand", price = 35,
		hire = true, title = "HIRE ASSOCIATE III",
		body = "Another sleeve, same grey.
One more hand at the mat."},
	{id = "hire_associate_4", parent = "hire_associate_3", at = Vector2(0.69, 1.41), icon = "hand", price = 55,
		hire = true, title = "HIRE ASSOCIATE IV",
		body = "Interviews were waived.
One more hand at the mat."},
	{id = "hire_associate_5", parent = "hire_associate_4", at = Vector2(0.86, 1.77), icon = "hand", price = 75,
		research = "performance_review", hire = true, title = "HIRE ASSOCIATE V",
		body = "The desk is now a department.
One more hand at the mat."},
	{id = "hire_associate_6", parent = "hire_associate_5", at = Vector2(1.04, 2.14), icon = "hand", price = 120,
		hire = true, title = "HIRE ASSOCIATE VI",
		body = "Names are no longer collected.
One more hand at the mat."},
	{id = "hire_associate_7", parent = "hire_associate_6", at = Vector2(1.22, 2.50), icon = "hand", price = 750,
		hire = true, title = "HIRE ASSOCIATE VII",
		body = "A second coat rack is requisitioned.
One more hand at the mat."},
	{id = "hire_associate_8", parent = "hire_associate_7", at = Vector2(1.40, 2.87), icon = "hand", price = 3250,
		hire = true, title = "HIRE ASSOCIATE VIII",
		body = "Full complement. Morale is not tracked.
One more hand at the mat."},
	{id = "qa_time", parent = "hire_associate_3", at = Vector2(0.05, 1.48), icon = "lens", price = 50,
		needs = ["quality_assurance"], research = "research_inspection", mul = {qa_time = 0.75}, title = "FASTER ANALYSIS",
		body = "The scan line is told to hurry.
QA analyses a unit 25% faster."},
	{id = "qa_findings", parent = "qa_time", at = Vector2(0.46, 1.85), icon = "pilcrow", price = 60,
		add = {findings_per_cabbage = 1}, title = "MORE FINDINGS",
		body = "Standards are revised.
One more Finding per unit analysed."},
	{id = "qa_fast_track", parent = "qa_findings", at = Vector2(0.56, 2.23), icon = "lens", price = 4750,
		mul = {qa_time = 0.5}, title = "QA FAST TRACK",
		body = "Analysis is now a formality.
QA analyses a unit twice as fast."},
	{id = "double_findings", parent = "qa_fast_track", at = Vector2(0.65, 2.60), icon = "pilcrow", price = 16000,
		mul = {findings_per_cabbage = 2}, title = "DOUBLE FINDINGS",
		body = "Every finding is filed twice.
Twice the Findings per unit analysed."},
	# Supply + automation (desk space, packs, auto-buy, hands, seating, campaigns, vacuums, QA rest):
	# entities/supply_console/, entities/associate/, entities/vacuum/, entities/qa_bay/.
	{id = "desk_1", parent = "conveyor_1", at = Vector2(-1.62, 0.44), icon = "desk", price = 1200,
		add = {desk_capacity = 2}, title = "HOT-DESKING",
		body = "Units now share the mat.
Two more units fit on the mat."},
	{id = "desk_2", parent = "desk_1", at = Vector2(-2.07, 0.57), icon = "desk", price = 4500,
		add = {desk_capacity = 2}, title = "CLEAR-DESK POLICY",
		body = "Personal items have been binned.
Two more units fit on the mat."},
	{id = "desk_3", parent = "desk_2", at = Vector2(-2.51, 0.69), icon = "desk", price = 15000,
		add = {desk_capacity = 2}, title = "MAT EXTENSION",
		body = "The mat is lengthened by memo.
Two more units fit on the mat."},
	{id = "desk_4", parent = "desk_3", at = Vector2(-2.96, 0.81), icon = "desk", price = 30000,
		add = {desk_capacity = 2}, title = "DENSITY TARGETS",
		body = "Units are asked to sit closer.
Two more units fit on the mat."},
	{id = "desk_5", parent = "desk_4", at = Vector2(-3.41, 0.93), icon = "desk", price = 60000,
		add = {desk_capacity = 2}, title = "OPEN-PLAN MAT",
		body = "Partitions between units are removed.
Two more units fit on the mat."},
	{id = "desk_6", parent = "desk_5", at = Vector2(-3.86, 1.06), icon = "desk", price = 70000,
		add = {desk_capacity = 2}, title = "MAXIMUM OCCUPANCY",
		body = "The fire code has been reinterpreted.
Two more units fit on the mat."},
	{id = "pack_3", parent = "pack_2", at = Vector2(-1.32, 0.98), icon = "crate", price = 2750,
		add = {pack_size = 10}, title = "PALLET ORDERS",
		body = "Units now arrive on pallets.
Ten more units in every pack."},
	{id = "pack_4", parent = "pack_3", at = Vector2(-1.68, 1.25), icon = "crate", price = 27500,
		add = {pack_size = 25}, title = "CONTAINER ORDERS",
		body = "A container is parked in the street.
25 more units in every pack."},
	{id = "discount_1", parent = "pack_1", at = Vector2(-1.21, 0.10), icon = "crate", price = 30,
		mul = {pack_discount = 0.85}, title = "SUPPLIER REVIEW",
		body = "The supplier is reminded of alternatives.
Packs cost 15% less."},
	{id = "discount_2", parent = "discount_1", at = Vector2(-1.68, 0.14), icon = "crate", price = 2750,
		mul = {pack_discount = 0.85}, title = "VOLUME REBATE",
		body = "A rebate form is filed in triplicate.
Packs cost 15% less."},
	{id = "discount_3", parent = "discount_2", at = Vector2(-2.15, 0.18), icon = "crate", price = 30000,
		mul = {pack_discount = 0.8}, title = "EXCLUSIVITY CLAUSE",
		body = "The supplier has no other customers now.
Packs cost 20% less."},
	{id = "auto_reserve_1", parent = "pack_1", at = Vector2(-1.19, -0.24), icon = "clock", price = 1600,
		needs = ["auto_procurement"], add = {auto_reserve = 7}, title = "SAFETY STOCK",
		body = "The order is placed earlier.
Auto-buy reorders at 10 units left."},
	{id = "auto_reserve_2", parent = "auto_reserve_1", at = Vector2(-1.68, -0.18), icon = "clock", price = 14000,
		add = {auto_reserve = 15}, title = "STRATEGIC RESERVE",
		body = "A second shelf is approved.
Auto-buy reorders at 25 units left."},
	{id = "auto_smart_1", parent = "auto_reserve_1", at = Vector2(-1.61, -0.48), icon = "lens", price = 3250,
		add = {auto_max_factor = -0.5}, title = "PRICE DISCIPLINE",
		body = "The order waits for a fair price.
While stock lasts, auto-buy skips prices over base."},
	{id = "auto_smart_2", parent = "auto_smart_1", at = Vector2(-2.05, -0.61), icon = "lens", price = 37500,
		add = {auto_max_factor = -0.2}, title = "FORWARD BUYING",
		body = "Procurement watches the ticker all day.
While stock lasts, auto-buy waits for -20% dips."},
	{id = "hire_associate_9", parent = "hire_associate_8", at = Vector2(1.58, 3.24), icon = "hand", price = 10000,
		hire = true, title = "HIRE ASSOCIATE IX",
		body = "Desks are now shared in shifts.
One more hand at the mat."},
	{id = "hire_associate_10", parent = "hire_associate_9", at = Vector2(1.76, 3.60), icon = "hand", price = 25000,
		hire = true, title = "HIRE ASSOCIATE X",
		body = "Headcount is final. For now.
One more hand at the mat."},
	{id = "associate_4", parent = "associate_3", at = Vector2(1.64, -1.28), icon = "clock", price = 12000,
		mul = {associate_speed = 1.3}, title = "BRISK WALK IV",
		body = "Elevators are reserved for units.
Associates move 30% faster."},
	{id = "associate_5", parent = "associate_4", at = Vector2(1.99, -1.56), icon = "clock", price = 40000,
		mul = {associate_speed = 1.3}, title = "BRISK WALK V",
		body = "Breathing is now scheduled.
Associates move 30% faster."},
	{id = "seating_1", parent = "associate_1", at = Vector2(1.12, -0.45), icon = "chair", price = 30,
		mul = {hand_output = 1.5}, title = "OPEN-PLAN SEATING I",
		body = "The walls between associates come down.
Associates make 50% more trips."},
	{id = "seating_2", parent = "seating_1", at = Vector2(1.55, -0.63), icon = "chair", price = 11000,
		mul = {hand_output = 1.5}, title = "OPEN-PLAN SEATING II",
		body = "Chairs are replaced with a bench.
Associates make 50% more trips."},
	{id = "campaign_1", parent = "slogan_2", at = Vector2(0.35, -1.48), icon = "megaphone", price = 35,
		mul = {marketing = 1.25}, title = "SYNERGY JINGLE",
		body = "Four notes. Staff are asked to hum them.
The street pays 25% more per unit."},
	{id = "campaign_2", parent = "campaign_1", at = Vector2(0.44, -1.85), icon = "megaphone", price = 425,
		mul = {marketing = 1.25}, title = "LEAF IT TO US",
		body = "Legal approved the pun.
The street pays 25% more per unit."},
	{id = "campaign_3", parent = "campaign_2", at = Vector2(0.53, -2.23), icon = "megaphone", price = 2250,
		mul = {marketing = 1.25}, title = "CRUCIFEROUS EXCELLENCE",
		body = "Nobody knows the word. Everyone trusts it.
The street pays 25% more per unit."},
	{id = "campaign_4", parent = "slogan_3", at = Vector2(0.00, -1.83), icon = "megaphone", price = 2500,
		research = "research_sentiment", mul = {marketing = 1.25}, title = "BRASSICA FOR THE MASSES",
		body = "Posters in every stairwell.
The street pays 25% more per unit."},
	{id = "campaign_5", parent = "campaign_4", at = Vector2(0.00, -2.19), icon = "megaphone", price = 16000,
		mul = {marketing = 1.25}, title = "TRUSTED BY THE MINISTRY",
		body = "The Ministry has not denied it.
The street pays 25% more per unit."},
	{id = "campaign_6", parent = "campaign_5", at = Vector2(0.00, -2.55), icon = "megaphone", price = 45000,
		mul = {marketing = 1.25}, title = "THE ONLY VEGETABLE",
		body = "Other vegetables are under review.
The street pays 25% more per unit."},
	{id = "vacuum_speed_1", parent = "", at = Vector2(-0.40, 0.64), icon = "puck", price = 1000,
		needs = ["coin_collector"], mul = {vacuum_speed = 1.5}, title = "FIRMWARE UPDATE",
		body = "The unit is told to hurry.
Coin units move 50% faster."},
	{id = "vacuum_bag_1", parent = "vacuum_speed_1", at = Vector2(-0.47, 1.05), icon = "puck", price = 3000,
		add = {vacuum_capacity = 12}, title = "LARGER BAG",
		body = "The bag is replaced with a bigger bag.
Coin units carry 12 more coins per trip."},
	{id = "vacuum_suction", parent = "vacuum_bag_1", at = Vector2(-0.63, 1.42), icon = "puck", price = 11000,
		mul = {vacuum_reach = 1.5}, title = "STRONGER SUCTION",
		body = "The unit is louder now. This is progress.
Coin units reach 50% further."},
	{id = "vacuum_2", parent = "vacuum_speed_1", at = Vector2(-0.76, 0.90), icon = "puck", price = 5000,
		add = {vacuums = 1}, title = "SECOND UNIT",
		body = "A second unit is unboxed.
One more coin unit on the mat."},
	{id = "vacuum_speed_2", parent = "vacuum_2", at = Vector2(-1.03, 1.23), icon = "puck", price = 16000,
		mul = {vacuum_speed = 1.5}, title = "FIRMWARE UPDATE II",
		body = "Obstacle detection is disabled.
Coin units move 50% faster."},
	{id = "vacuum_bag_2", parent = "vacuum_suction", at = Vector2(-0.80, 1.79), icon = "puck", price = 37500,
		add = {vacuum_capacity = 30}, title = "INDUSTRIAL BAG",
		body = "The bag is now a sack.
Coin units carry 30 more coins per trip."},
	{id = "vacuum_3", parent = "vacuum_speed_2", at = Vector2(-1.31, 1.56), icon = "puck", price = 55000,
		add = {vacuums = 1}, title = "THIRD UNIT",
		body = "The units have formed a department.
One more coin unit on the mat."},
	{id = "qa_slot_2", parent = "qa_time", at = Vector2(0.06, 1.84), icon = "lens", price = 1000,
		add = {qa_slots = 1}, title = "SECOND BENCH",
		body = "A second bench in the bay.
QA analyses two units at once."},
	{id = "qa_slot_3", parent = "qa_slot_2", at = Vector2(0.08, 2.20), icon = "lens", price = 27500,
		add = {qa_slots = 1}, title = "THIRD BENCH",
		body = "The bay is now a lab.
QA analyses three units at once."},
	{id = "qa_feed_1", parent = "qa_time", at = Vector2(-0.33, 1.86), icon = "hand", price = 200,
		add = {qa_feed_every = 6}, title = "INTAKE ROTA",
		body = "Associates take turns feeding QA.
Every 6th associate trip goes to QA."},
	{id = "qa_feed_2", parent = "qa_feed_1", at = Vector2(-0.39, 2.23), icon = "hand", price = 13000,
		add = {qa_feed_every = -2}, title = "INTAKE ROTA II",
		body = "The rota is laminated.
Every 4th associate trip goes to QA."},
	{id = "qa_feed_3", parent = "qa_feed_2", at = Vector2(-0.46, 2.60), icon = "hand", price = 47500,
		add = {qa_feed_every = -1}, title = "INTAKE ROTA III",
		body = "QA is now everyone's job.
Every 3rd associate trip goes to QA."},
	# Manager (down-right) and pricing consultant (up-right): entities/manager/, entities/consultant/.
	{id = "manager_time", parent = "", at = Vector2(0.70, 0.28), icon = "clock", price = 60,
		needs = ["managerial_oversight"], add = {manager_time = 15.0}, title = "EXTENDED DEADLINES",
		body = "The manager is shown a calendar.
Quotas allow 15 more seconds."},
	{id = "manager_reward_1", parent = "manager_time", at = Vector2(1.12, 0.45), icon = "crate", price = 300,
		mul = {manager_reward = 1.5}, title = "PERFORMANCE BONUS",
		body = "Bonuses are now discussed openly.
Met quotas pay 50% more."},
	{id = "manager_raise", parent = "manager_reward_1", at = Vector2(1.55, 0.63), icon = "lens", price = 2000,
		add = {manager_raise = -0.1}, title = "REALISTIC TARGETS",
		body = "Ambition is capped by memo.
Quotas ask 10% less over your pace."},
	{id = "manager_reward_2", parent = "manager_raise", at = Vector2(1.98, 0.80), icon = "crate", price = 5500,
		mul = {manager_reward = 1.5}, title = "EMPLOYEE OF THE QUARTER",
		body = "A frame is purchased. It stays empty.
Met quotas pay 50% more."},
	{id = "consultant_speed_1", parent = "", at = Vector2(0.40, -0.64), icon = "clock", price = 25,
		needs = ["pricing_consultant"], mul = {consultant_interval = 0.5}, title = "BILLABLE HOURS",
		body = "The consultant bills by the tap.
It adjusts the price twice as often."},
	{id = "consultant_mood", parent = "consultant_speed_1", at = Vector2(0.62, -0.99), icon = "lens", price = 200,
		add = {consultant_skill = 1}, title = "READS THE ROOM",
		body = "The consultant looks out of the window.
It follows the street's mood, not the textbook."},
	{id = "consultant_smart", parent = "consultant_mood", at = Vector2(0.84, -1.34), icon = "crate", price = 2000,
		add = {consultant_skill = 1}, title = "YIELD OPTIMISATION",
		body = "Some units may now be refused.
It aims for the most money per unit after pack costs."},
	{id = "consultant_speed_2", parent = "consultant_smart", at = Vector2(1.06, -1.70), icon = "clock", price = 15000,
		mul = {consultant_interval = 0.5}, title = "RETAINER",
		body = "The consultant no longer leaves.
It adjusts the price twice as often."},
	# Sales events (golden lamp up-left, catch combo far up-left, waste bin down, window targets far
	# right): entities/golden_lamp/, catch_combo/, rotten_bin/, window_targets/.
	{id = "lamp_mult", parent = "", at = Vector2(-0.40, -0.64), icon = "crate", price = 22500,
		needs = ["golden_lamp"], add = {lamp_mult = 3.0}, title = "GILDED FILAMENT",
		body = "The bulb is replaced with a better bulb.
The golden lamp pays ×8 instead of ×5."},
	{id = "lamp_time", parent = "lamp_mult", at = Vector2(-0.62, -0.99), icon = "clock", price = 30000,
		mul = {lamp_time = 1.5}, title = "EXTENDED BURN",
		body = "The lamp's timer is taped down.
It glows 50% longer."},
	{id = "lamp_every", parent = "lamp_time", at = Vector2(-0.84, -1.34), icon = "clock", price = 47500,
		mul = {lamp_every = 0.6}, title = "LOOSE WIRING",
		body = "Maintenance has been told not to look.
The lamp glows much more often."},
	{id = "combo_window", parent = "", at = Vector2(-0.62, -0.42), icon = "clock", price = 25,
		needs = ["catch_combo"], mul = {combo_window = 1.5}, title = "GRACE PERIOD",
		body = "Interceptions are counted generously.
The combo holds 50% longer between catches."},
	{id = "combo_cap", parent = "combo_window", at = Vector2(-0.99, -0.67), icon = "crate", price = 200,
		add = {combo_cap = 0.5}, title = "UNCAPPED ENTHUSIASM",
		body = "The ceiling is raised by memo.
The combo can reach ×2 instead of ×1.5."},
	{id = "combo_step", parent = "combo_cap", at = Vector2(-1.37, -0.92), icon = "hand", price = 4250,
		mul = {combo_step = 2.0}, title = "REFLEX TRAINING",
		body = "A mandatory seminar on catching things.
Each catch adds twice as much."},
	{id = "bin_mouth", parent = "", at = Vector2(0.52, 0.54), icon = "lens", price = 35,
		needs = ["rotten_bin"], mul = {bin_mouth = 1.35}, title = "WIDER RECEPTACLE",
		body = "A larger bin is requisitioned.
Its mouth is 35% wider."},
	{id = "bin_rebate", parent = "bin_mouth", at = Vector2(0.82, 0.85), icon = "crate", price = 225,
		add = {bin_rebate = 1.0}, title = "DISPOSAL REBATE",
		body = "Waste is now a revenue stream.
Each binned unit refunds one unit's price."},
	{id = "hands_bin", parent = "bin_rebate", at = Vector2(1.13, 1.17), icon = "hand", price = 700,
		needs = ["junior_associate"], add = {hands_bin = 1}, title = "WASTE HANDLING PROTOCOL",
		body = "Associates are shown where the bin is.
Hired hands bin rotten units instead of leaving them."},
	{id = "target_size", parent = "", at = Vector2(0.75, -0.03), icon = "lens", price = 200,
		needs = ["window_targets"], mul = {target_size = 1.5}, title = "BROADER FLOODLIGHT",
		body = "The street lamp is pointed less carefully.
Lit targets are 50% wider."},
	{id = "target_every", parent = "target_size", at = Vector2(1.22, -0.04), icon = "clock", price = 800,
		mul = {target_every = 0.6}, title = "STREET COOPERATION",
		body = "The street has been asked to stand still.
Targets are lit much more often."},
	{id = "target_shower", parent = "target_every", at = Vector2(1.68, -0.06), icon = "crate", price = 5000,
		mul = {target_shower = 2}, title = "PRIZE CRATES",
		body = "The crates are lined with coin.
A hit pays twenty times the sale instead of ten."},
]
## The screen's rect as fractions of the view. SMALL leaves the mat and the window gap free.
const RECTS := {Size.SMALL: Rect2(0.02, 0.0, 0.444, 0.95), Size.FULL: Rect2(0.03, 0.0, 0.94, 0.97)}
const HOLD_TIME := 0.6
const ZOOM_MIN := 0.6
const ZOOM_MAX := 2.5
## One wheel notch zooms by this factor, about the cursor.
const ZOOM_STEP := 1.15
const WIDEN := 1.6
## The screen follows the tab at most this fast (screens per second): the roller spring is heavy.
const PULL_SPEED := 4.0
## A press on the tab that moves less than this (px) is a click: it rolls the screen down or up.
const CLICK_PX := 8.0
const ROLLER_H := 18.0
const BAR_H := 10.0
const TAB_SIZE := Vector2(84, 58)
const CORD := 30.0
## Where the tab hangs along the bottom bar (0 left .. 1 right): clear of the tally machine's drums.
const TAB_AT := 0.1
const FONT := preload("res://assets/fonts/Oswald.ttf")
const FABRIC := Color(0.36, 0.39, 0.36)
const BEAM := Color(0.78, 0.84, 0.84)
const INK := Color(0.13, 0.15, 0.14)
const STEEL := Color(0.16, 0.17, 0.17)
const DENIED := Color(0.55, 0.12, 0.1)
const CABBAGE := Color(0.42, 0.72, 0.24)

## SMALL (~45% of the view, the mat and window stay free) or FULL (the whole desk).
@export var size_mode := Size.SMALL
@export var roll_down_sound: AudioStream
@export var roll_up_sound: AudioStream
@export var approve_sound: AudioStream
@export var denied_sound: AudioStream

## How far the screen is unrolled, 0 (up) to 1 (down), and how far the projector lamp is on.
var _drop := 0.0
var _lamp := 0.0
var _flick := 1.0
var _dragging := false
var _press_y := 0.0
var _press_drop := 0.0
var _settling: Tween
var _hovered := ""
var _holding := ""
var _hold := 0.0
var _denied := 0.0
## The roller's slide down from above the screen when it first turns up (px of offset).
var _arrive := 0.0
var _sfx := AudioStreamPlayer.new()
var _beam := GradientTexture2D.new()
## The tree's pan (px) and zoom; a press on the slide pans once it moves past CLICK_PX.
var _pan := Vector2.ZERO
var _zoom := 1.0
var _panning := false
var _panned := false
var _pan_press := Vector2.ZERO
var _pan_start := Vector2.ZERO
## The tree is drawn on this child, which clips it to the slide below the heading.
var _tree := Control.new()
## shown_nodes() for the current save, rebuilt only when a stamp, a purchase or a new save changes it.
var _shown := {}
var _shown_key := []


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_tree.clip_contents = true
	_tree.mouse_filter = MOUSE_FILTER_IGNORE
	_tree.draw.connect(_draw_tree)
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
	visible = unlocked(SaveManager.save)


func _process(delta: float) -> void:
	var save: SaveGame = SaveManager.save
	if not visible:
		if unlocked(save):
			_arrive_now()
		return
	if _dragging:
		var target := clampf(_press_drop + (get_local_mouse_position().y - _press_y) / _span(), 0.0, 1.0)
		_drop = move_toward(_drop, target, PULL_SPEED * delta)
	_flick = 1.0 - (randf() * 0.12 if randf() < 0.08 else randf() * 0.03)
	_denied = maxf(_denied - delta, 0.0)
	if _holding != "" and _lamp > 0.9:
		if can_buy(_holding, save):
			_hold += delta / HOLD_TIME
			if _hold >= 1.0:
				buy(_holding, save)
				SaveManager.log_event("node", _holding, node_data(_holding).price, "coins")
				_play(approve_sound)
				_holding = ""
				_hold = 0.0
		elif _denied == 0.0:
			_denied = 0.5
			_play(denied_sound)
	var area := _tree_rect()
	_tree.position = area.position
	_tree.size = area.size
	_tree.visible = _drop > 0.0
	queue_redraw()
	_tree.queue_redraw()


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


## The nodes on the screen for `save`, in NODES order: id -> the research it waits for ("" if open).
static func shown_nodes(save: SaveGame) -> Dictionary:
	var shown := {}
	for node: Dictionary in NODES:
		if is_shown(node.id, save):
			shown[node.id] = locked_by(node.id, save)
	return shown


## Shown on the screen: the parent is bought and every desk card it needs is stamped.
static func is_shown(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	return not node.is_empty() and (node.parent == "" or save.tree_bought.has(node.parent)) \
			and node.get("needs", []).all(func(card: String) -> bool: return save.stamped.has(card))


## The research card node `id` still waits for, or "" (none, stamped, or the node already bought).
static func locked_by(id: String, save: SaveGame) -> String:
	var card: String = node_data(id).get("research", "")
	return "" if card == "" or save.stamped.has(card) or save.tree_bought.has(id) else card


static func can_buy(id: String, save: SaveGame) -> bool:
	return is_shown(id, save) and not save.tree_bought.has(id) and locked_by(id, save) == "" \
			and save.coins >= node_data(id).price


## Pays for node `id` and applies it; false (and nothing changes) if it can't be bought.
static func buy(id: String, save: SaveGame) -> bool:
	if not can_buy(id, save):
		return false
	save.coins -= node_data(id).price
	save.tree_bought.append(id)
	apply(id, save)
	return true


## What node `id` does to the save.
static func apply(id: String, save: SaveGame) -> void:
	var node := node_data(id)
	for stat in node.get("mul", {}):
		var value: Variant = save.get(stat) * node.mul[stat]
		save.set(stat, roundi(value) if save.get(stat) is int else value)
	for stat in node.get("add", {}):
		save.set(stat, save.get(stat) + node.add[stat])
	if node.get("hire", false):
		Associate.add_hand(save)


func _has_point(point: Vector2) -> bool:
	return visible and (_tab_rect().grow(6.0).has_point(point) or (_drop > 0.0 and _fabric_rect().has_point(point)))


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	var on_slide := _lamp > 0.9 and _tree_rect().has_point(event.position if event is InputEventMouse else Vector2.INF)
	if button != null and button.pressed and on_slide and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_at(button.position, ZOOM_STEP if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP)
		_hovered = _node_at(button.position)
		accept_event()
	elif button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			if _tab_rect().grow(6.0).has_point(button.position):
				_dragging = true
				_press_y = button.position.y
				_press_drop = _drop
				_lamp_off()
				if _settling != null:
					_settling.kill()
			elif on_slide:
				# A press on a node starts buying it; moved past CLICK_PX it pans instead.
				_panning = true
				_panned = false
				_pan_press = button.position
				_pan_start = _pan
				_hovered = _node_at(button.position)
				# A bought node does nothing on press (no denied blink and sound).
				_holding = _hovered if not SaveManager.save.tree_bought.has(_hovered) else ""
				_hold = 0.0
				if button.double_click and _hovered == "":
					_recentre()
		else:
			if _dragging:
				_dragging = false
				var clicked := absf(button.position.y - _press_y) < CLICK_PX
				_settle(_press_drop < 0.5 if clicked else _drop > 0.5)
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
		if _holding != "" and _hovered != _holding:
			_holding = ""
			_hold = 0.0
		mouse_default_cursor_shape = CURSOR_DRAG if _dragging or _panned or _tab_rect().grow(6.0).has_point(at) \
				else CURSOR_POINTING_HAND if _hovered != "" else CURSOR_ARROW


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovered = ""
		_holding = ""


func _arrive_now() -> void:
	visible = true
	_arrive = -80.0
	create_tween().tween_property(self, "_arrive", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _settle(down: bool) -> void:
	_settling = create_tween()
	if down:
		_play(roll_down_sound)
		_settling.tween_property(self, "_drop", 1.0, 0.35 * (1.0 - _drop) + 0.05).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		# The lamp warms up with a stutter.
		for level: float in [0.6, 0.1, 0.8, 0.3, 1.0]:
			_settling.tween_property(self, "_lamp", level, 0.05)
	else:
		_play(roll_up_sound)
		_settling.tween_property(self, "_drop", 0.0, 0.3 * _drop + 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _lamp_off() -> void:
	_lamp = 0.0
	_hovered = ""
	_holding = ""


func _play(stream: AudioStream) -> void:
	if stream != null:
		_sfx.stream = stream
		_sfx.play()


# --- Layout ---

func _screen_rect() -> Rect2:
	var frac: Rect2 = RECTS[size_mode]
	return Rect2(size * frac.position, size * frac.size)


## How far the fabric can unroll (px).
func _span() -> float:
	return _screen_rect().size.y - ROLLER_H - BAR_H


func _fabric_rect() -> Rect2:
	var screen := _screen_rect()
	return Rect2(screen.position.x + 10.0, ROLLER_H + _arrive, screen.size.x - 20.0, _drop * _span() + BAR_H)


func _tab_rect() -> Rect2:
	var fabric := _fabric_rect()
	return Rect2(Vector2(lerpf(fabric.position.x, fabric.end.x, TAB_AT) - TAB_SIZE.x / 2.0, fabric.end.y + CORD), TAB_SIZE)


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


## `pan` if a shown node (or the hub) stays well inside the slide with it, else the closest move
## along one axis that does, else the current pan: the tree can't be lost off the slide.
func _clamp_pan(pan: Vector2) -> Vector2:
	for option: Vector2 in [pan, Vector2(pan.x, _pan.y), Vector2(_pan.x, pan.y)]:
		if _keeps_tree(option):
			return option
	return _pan


func _keeps_tree(pan: Vector2) -> bool:
	var wheel := _wheel()
	var centre: Vector2 = wheel[0] - _pan + pan
	var inside := _tree_rect().grow(-wheel[2] * 1.5)
	return _visible_nodes().keys().any(func(id: String) -> bool: \
			return inside.has_point(centre + node_data(id).at * wheel[1])) or inside.has_point(centre)


## shown_nodes() of the current save, cached: stamps and purchases only ever grow, so their counts
## (and the save's identity, for a reset) tell when it is stale.
func _visible_nodes() -> Dictionary:
	var save: SaveGame = SaveManager.save
	var key := [save.get_instance_id(), save.stamped.size(), save.tree_bought.size()]
	if key != _shown_key:
		_shown_key = key
		_shown = shown_nodes(save)
	return _shown


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
	for id: String in _visible_nodes():
		if point.distance_to(wheel[0] + node_data(id).at * wheel[1]) < r * 1.2:
			return id
	return ""


# --- Drawing ---

func _draw() -> void:
	var save: SaveGame = SaveManager.save
	var screen := _screen_rect()
	var fabric := _fabric_rect()
	if _drop > 0.0:
		draw_rect(Rect2(fabric.position + Vector2(8, 6), fabric.size), Color(0, 0, 0, 0.35))
		draw_rect(fabric, FABRIC)
		_draw_content(save, fabric)
	# Roller at the top, weighted bar at the fabric's foot, the cord and the pull tab.
	draw_rect(Rect2(screen.position.x, _arrive, screen.size.x, ROLLER_H), STEEL)
	draw_rect(Rect2(screen.position.x, _arrive + ROLLER_H * 0.65, screen.size.x, ROLLER_H * 0.35), Color(0, 0, 0, 0.4))
	var bar := Rect2(fabric.position.x - 4.0, fabric.end.y - BAR_H, fabric.size.x + 8.0, BAR_H)
	draw_rect(bar, STEEL)
	var tab := _tab_rect()
	draw_line(Vector2(tab.get_center().x, bar.end.y), Vector2(tab.get_center().x, tab.position.y), INK, 3.0)
	draw_rect(Rect2(tab.position + Vector2(4, 4), tab.size), Color(0, 0, 0, 0.4))
	draw_rect(tab, Color(0.62, 0.65, 0.6))
	draw_rect(tab, INK, false, 2.0)
	draw_circle(tab.get_center() + Vector2(0, -9), 9.0, INK)
	var label := "PULL" if _drop < 0.5 else "STOW"
	draw_string(FONT, Vector2(tab.position.x, tab.end.y - 7.0), label, HORIZONTAL_ALIGNMENT_CENTER, tab.size.x, 17, INK)


func _draw_content(save: SaveGame, fabric: Rect2) -> void:
	var light := _lamp * _flick
	if light <= 0.0:
		return
	# The beam: a cold, uneven wash brightest in the middle.
	draw_texture_rect(_beam, fabric, false, Color(1, 1, 1, light))
	var ink := Color(INK, light)
	var top := fabric.position.y + fabric.size.y * 0.04
	var head := clampf(fabric.size.x * 0.05, 22.0, 44.0)
	draw_string(FONT, Vector2(fabric.position.x, top + head), "GROWTH INITIATIVES", HORIZONTAL_ALIGNMENT_CENTER, fabric.size.x, int(head), ink)
	draw_string(FONT, Vector2(fabric.position.x, top + head * 1.6), "FORM GW-7   |   BUDGET AVAILABLE $%d   |   HOLD TO APPROVE" % save.coins,
			HORIZONTAL_ALIGNMENT_CENTER, fabric.size.x, int(head * 0.42), Color(INK, light * 0.75))


## The tree, on the clipped child. Coordinates stay the projector's own (the transform undoes the
## child's offset), so hit tests and drawing share _wheel().
func _draw_tree() -> void:
	var save: SaveGame = SaveManager.save
	var light := _lamp * _flick
	if light <= 0.0 or _drop <= 0.0:
		return
	_tree.draw_set_transform(-_tree.position)
	var ink := Color(INK, light)
	var wheel := _wheel()
	var centre: Vector2 = wheel[0]
	var unit: Vector2 = wheel[1]
	var r: float = wheel[2]
	var shown := _visible_nodes()
	for id: String in shown:
		var node := node_data(id)
		# Edge to edge: the line stops at both circles instead of running into them.
		var from: Vector2 = centre if node.parent == "" else centre + node_data(node.parent).at * unit
		var to: Vector2 = centre + node.at * unit
		var dir := from.direction_to(to)
		var gap := r + (6.0 if id == _holding else 0.0)
		if from.distance_to(to) > r * 2.2 + gap:
			var start := from + dir * r * (1.1 if node.parent == "" else 1.0)
			if shown[id] != "":
				_tree.draw_dashed_line(start, to - dir * gap, Color(INK, light * 0.35), 3.0, 9.0)
			else:
				_tree.draw_line(start, to - dir * gap, Color(INK, light * 0.6), 3.0, true)
	# The hub: a cabbage cross-section, the one green thing on the slide.
	_tree.draw_circle(centre, r * 1.1, Color(CABBAGE, light))
	_tree.draw_circle(centre, r * 1.1, ink, false, 3.0, true)
	for i in 3:
		_tree.draw_arc(centre + Vector2(r * 0.15, 0), r * (0.3 + i * 0.25), PI * 0.6, PI * 1.9, 16, Color(0.9, 1.0, 0.8, light * 0.8), 2.0, true)
	for id: String in shown:
		_draw_node(node_data(id), centre + node_data(id).at * unit, r, shown[id] != "", save, light)
	var area := _tree_rect()
	var hint := "DRAG TO MOVE   |   WHEEL TO ZOOM" if _pan == Vector2.ZERO and is_equal_approx(_zoom, 1.0) else "DOUBLE-CLICK TO RECENTRE"
	_tree.draw_string(FONT, area.end - Vector2(area.size.x, 12.0), hint, HORIZONTAL_ALIGNMENT_RIGHT, area.size.x - 14.0, 15, Color(INK, light * 0.55))
	if _hovered != "":
		_draw_popup(node_data(_hovered), centre + node_data(_hovered).at * unit, r, save, light, _tree_rect())


func _draw_node(node: Dictionary, at: Vector2, r: float, locked: bool, save: SaveGame, light: float) -> void:
	var bought: bool = save.tree_bought.has(node.id)
	var alpha := light * (0.3 if locked else 1.0 if bought or save.coins >= node.price else 0.35)
	var ink := Color(INK, alpha)
	if node.id == _holding and _denied > 0.0:
		ink = Color(DENIED, alpha)
	var face := Color(BEAM.lerp(Color.WHITE, 0.3), alpha * (0.5 if node.id == _hovered else 0.0))
	_tree.draw_circle(at, r, ink if bought else face)
	if locked:
		# A broken rim and a padlock: on the plan, not yet approved.
		for i in 12:
			_tree.draw_arc(at, r, TAU * i / 12.0, TAU * (i + 0.6) / 12.0, 6, ink, 3.0, true)
	else:
		_tree.draw_circle(at, r, ink, false, 3.0, true)
	_draw_icon("padlock" if locked else node.icon, at, r * 0.55, Color(BEAM, alpha) if bought else ink)
	if node.id == _holding and _hold > 0.0:
		_tree.draw_arc(at, r + 6.0, -PI / 2.0, -PI / 2.0 + TAU * _hold, 40, Color(INK, light), 5.0, true)
	# Bought shows as the filled disc (the popup says APPROVED): a word under it would run into
	# the next node's title in the vertical chains.
	var font_size := int(clampf(r * 0.6, 14.0, 34.0))
	_tree.draw_string(FONT, at + Vector2(-200.0, -r - 8.0), node.title, HORIZONTAL_ALIGNMENT_CENTER, 400.0, font_size, ink)


## Simple line glyphs, centred on `at`, about `s` from the centre to the edge.
func _draw_icon(icon: String, at: Vector2, s: float, color: Color) -> void:
	match icon:
		"megaphone":
			_tree.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.6, -s * 0.3), at + Vector2(s * 0.7, -s * 0.8),
					at + Vector2(s * 0.7, s * 0.8), at + Vector2(-s * 0.6, s * 0.3)]), color)
			_tree.draw_rect(Rect2(at + Vector2(-s, -s * 0.3), Vector2(s * 0.4, s * 0.6)), color)
		"crate":
			var box := Rect2(at - Vector2(s, s) * 0.8, Vector2(s, s) * 1.6)
			_tree.draw_rect(box, color, false, 2.5)
			_tree.draw_line(box.position, box.end, color, 2.0)
			_tree.draw_line(Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), color, 2.0)
		"clock":
			_tree.draw_arc(at, s * 0.85, 0.0, TAU, 24, color, 2.5, true)
			_tree.draw_line(at, at + Vector2(0, -s * 0.6), color, 2.5)
			_tree.draw_line(at, at + Vector2(s * 0.45, 0), color, 2.5)
		"lens":
			_tree.draw_arc(at + Vector2(-s * 0.2, -s * 0.2), s * 0.55, 0.0, TAU, 20, color, 2.5, true)
			_tree.draw_line(at + Vector2(s * 0.2, s * 0.2), at + Vector2(s * 0.85, s * 0.85), color, 4.0)
		"hand":
			# A mitten-like office hand: palm, four fingers, a thumb.
			_tree.draw_rect(Rect2(at + Vector2(-s * 0.5, -s * 0.15), Vector2(s, s * 0.85)), color)
			for i in 4:
				var tall := s * (0.55 if i in [0, 3] else 0.7)
				_tree.draw_rect(Rect2(at + Vector2(-s * 0.5 + i * s * 0.26, -s * 0.15 - tall), Vector2(s * 0.2, tall)), color)
			_tree.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.5, s * 0.05), at + Vector2(-s * 0.95, -s * 0.3),
					at + Vector2(-s * 0.8, -s * 0.45), at + Vector2(-s * 0.5, -s * 0.2)]), color)
		"belt":
			for x: float in [-0.55, 0.55]:
				_tree.draw_arc(at + Vector2(s * x, 0), s * 0.3, 0.0, TAU, 14, color, 2.5, true)
			_tree.draw_line(at + Vector2(-s * 0.55, -s * 0.3), at + Vector2(s * 0.55, -s * 0.3), color, 2.5)
			_tree.draw_line(at + Vector2(-s * 0.55, s * 0.3), at + Vector2(s * 0.55, s * 0.3), color, 2.5)
			_tree.draw_rect(Rect2(at + Vector2(-s * 0.25, -s * 0.75), Vector2(s * 0.5, s * 0.4)), color)
		"padlock":
			_tree.draw_arc(at + Vector2(0, -s * 0.15), s * 0.42, PI, TAU, 12, color, 3.0, true)
			for x: float in [-0.42, 0.42]:
				_tree.draw_line(at + Vector2(s * x, -s * 0.15), at + Vector2(s * x, s * 0.1), color, 3.0)
			_tree.draw_rect(Rect2(at + Vector2(-s * 0.7, s * 0.05), Vector2(s * 1.4, s * 0.85)), color)
			_tree.draw_circle(at + Vector2(0, s * 0.4), s * 0.13, Color(FABRIC, color.a))
		"pilcrow":
			_tree.draw_string(FONT, at + Vector2(-s, s * 0.6), "¶+", HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 1.5), color)
		"desk":
			# A desk top seen from above, with two units on it.
			_tree.draw_rect(Rect2(at - Vector2(s * 0.9, s * 0.6), Vector2(s * 1.8, s * 1.2)), color, false, 2.5)
			for x: float in [-0.4, 0.4]:
				_tree.draw_circle(at + Vector2(s * x, 0), s * 0.28, color)
		"puck":
			# The coin unit: a disc with its lamp, and a coin beside it.
			_tree.draw_arc(at + Vector2(-s * 0.15, 0), s * 0.7, 0.0, TAU, 20, color, 2.5, true)
			_tree.draw_circle(at + Vector2(-s * 0.15, -s * 0.4), s * 0.14, color)
			_tree.draw_circle(at + Vector2(s * 0.75, s * 0.55), s * 0.22, color)
		"chair":
			_tree.draw_rect(Rect2(at + Vector2(-s * 0.5, -s * 0.8), Vector2(s * 0.25, s * 1.0)), color)
			_tree.draw_rect(Rect2(at + Vector2(-s * 0.5, 0), Vector2(s * 1.0, s * 0.22)), color)
			for x: float in [-0.45, 0.4]:
				_tree.draw_line(at + Vector2(s * x, s * 0.2), at + Vector2(s * x, s * 0.85), color, 2.5)


func _draw_popup(node: Dictionary, at: Vector2, r: float, save: SaveGame, light: float, fabric: Rect2) -> void:
	var width := 330.0
	var lines: PackedStringArray = node.body.split("\n")
	var research := locked_by(node.id, save)
	var height := 82.0 + lines.size() * 22.0 + (26.0 if research != "" else 0.0)
	var pos := at + Vector2(r + 14.0, -height / 2.0)
	if pos.x + width > fabric.end.x:
		pos.x = at.x - r - 14.0 - width
	pos.x = clampf(pos.x, fabric.position.x + 6.0, fabric.end.x - width - 6.0)
	pos.y = clampf(pos.y, fabric.position.y + 6.0, fabric.end.y - height - 6.0)
	var box := Rect2(pos, Vector2(width, height))
	_tree.draw_rect(box, Color(INK, light * 0.92))
	var paper := Color(BEAM, light)
	_tree.draw_string(FONT, pos + Vector2(14, 32), node.title, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 24, paper)
	for i in lines.size():
		_tree.draw_string(FONT, pos + Vector2(14, 58 + i * 22), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 17, Color(paper, light * 0.8))
	if research != "":
		# REQUIRES RESEARCH: on one line, the study's name (without its RESEARCH: prefix) under it.
		var study: String = UpgradeDesk.card_data(research).get("title", research).trim_prefix("RESEARCH: ")
		var red := Color(0.85, 0.35, 0.3, light)
		_tree.draw_string(FONT, pos + Vector2(14, height - 40), "REQUIRES RESEARCH:", HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 18, red)
		_tree.draw_string(FONT, pos + Vector2(14, height - 14), study, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 20, red)
		return
	var bought: bool = save.tree_bought.has(node.id)
	var price := "APPROVED" if bought else "COST $%d" % node.price
	var short: bool = not bought and save.coins < node.price
	_tree.draw_string(FONT, pos + Vector2(14, height - 14), price, HORIZONTAL_ALIGNMENT_LEFT, width - 28.0, 20,
			Color(0.85, 0.35, 0.3, light) if short else paper)
