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
## research card on the desk), `lock` (any other desk card) or `after` (another node) is reachable but
## locked until that card is stamped or that node bought: a padlock, and a hold is refused. Like a phone map, a held
## press dragged across the slide pans the tree (kept on the slide) and the wheel zooms it; a
## double-click recentres.
##
## The sheet is drawn in 2D on a full-screen Control rather than a 3D quad: the camera looks steeply
## down on the desk, so a hanging 3D screen would shrink to a thin strip, and a 2D overlay gets mouse
## hover and hold for free. _has_point lets the pull and the rest of the desk click through.
## The tree itself (pan, zoom, hover, hold, NEW, drawing) is an UpgradeTree
## (entities/components/upgrade_tree/) on these rules (the static funcs below, NODES, THEMES).

const Events := preload("res://globalScripts/game_events.gd")

## Every node, in one list for retuning (prices from reports/economy_rework_2026-10-31.md). A bought
## node multiplies each save number in `mul`, raises each in `add`, and `hire` adds one hand.
## `research` names the research card that unlocks it, `lock` any other desk card, `after` a node
## that must be bought first (see locked_by): until then it shows with a padlock.
## `at` is the spot on the wheel (centre 0,0; x is drawn 1.6 times wider than y): marketing up, QA
## down (research, lab hands), manual handling right (procurement and desk space, minis, sales events,
## management fanning out), automation left (consultancy, supply chain, coin units, associates,
## headcount); THEMES names the fans. Generated, with no overlaps or crossing edges, by tools/projector_layout/layout.py from its
## sectors.json (the mat, procurement and storage chains are laid by hand, "fixed" there, and checked by it).
## The late game (the first node of each late run names big_ideas in its `needs`, which hides the run) and
## chapter 3's own nodes (the block at the end of NODES) only show once the desk card BIG MINDS HAVE
## BIG IDEAS is stamped, on the wider sheet (screen_for). A node a save has bought always shows.
## Storage steps dropped from the chain (200 to 1,000 in two steps, not six), each with the kept
## step an old save that bought it gets instead (migrate_storage).
const DROPPED_STORAGE := {"stock_250": "storage_3", "stock_320": "storage_3", "stock_400": "storage_3", "stock_750": "stock_1000"}
## The mat allowance: the desk card gives the 3rd unit, then a chain of nodes "mat_%d" (the size the
## mat reaches): one unit a step from MAT_FIRST to MAT_SINGLES, then three a step up to MAT_MAX
## (migrate_mat files an old save's steps as bought).
const MAT_FIRST := 4
const MAT_SINGLES := 11
const MAT_MAX := 20
const NODES := [
	# Departments: free sub-hubs around the hub, one per direction, never bought (`dept`). Greyed until
	# their own `needs` / `research` are met; every upgrade hangs under exactly one of them.
	{id = "dept_marketing", parent = "", at = Vector2(0.12, -0.60), icon = "megaphone", price = 0,
		dept = true, needs = ["street_posters"], title = "MARKETING",
		body = "The street is told what it wants.\nSlogans and campaigns. Each one raises the price\nthe street pays without refusing."},
	{id = "dept_manual", parent = "", at = Vector2(0.84, 0.00), icon = "hand", price = 0,
		dept = true, title = "MANUAL HANDLING",
		body = "Work you still do yourself.\nPacks, desk space, minis, catches, the bin,\ntargets, the Golden Age, the manager's quotas."},
	{id = "dept_qa", parent = "", at = Vector2(0.00, 0.77), icon = "lens", price = 0,
		dept = true, needs = ["quality_assurance"], research = "research_inspection", title = "RESEARCH LAB",
		body = "Every cabbage is a lesson.\nFaster analysis, more Findings (¶) per cabbage, more\nbenches, research cabbages and lab hands."},
	{id = "dept_automation", parent = "", at = Vector2(-0.61, 0.00), icon = "belt", price = 0,
		dept = true, needs = ["junior_associate"], title = "AUTOMATION",
		body = "Work that no longer needs you.\nHired hands, conveyors, auto-buy, coin robots,\nthe consultant and the waste protocol."},
	{id = "slogan_1", parent = "dept_marketing", at = Vector2(0.12, -1.03), icon = "megaphone", price = 35,
		mul = {marketing = 1.25}, title = "SLOGAN I",
		body = "\"Cabbage. Because you have to eat.\"\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "slogan_2", parent = "slogan_1", at = Vector2(0.12, -1.46), icon = "megaphone", price = 120,
		mul = {marketing = 1.25}, title = "SLOGAN II",
		body = "\"Cabbage. Compliance tastes green.\"\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "slogan_3", parent = "slogan_2", at = Vector2(-0.24, -1.89), icon = "megaphone", price = 900,
		mul = {marketing = 1.25}, title = "SLOGAN III",
		body = "\"Cabbage. You were expecting something else?\"\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "slogan_4", parent = "slogan_3", at = Vector2(-0.49, -2.32), icon = "megaphone", price = 5500,
		research = "research_sentiment", mul = {marketing = 1.25}, title = "SLOGAN IV",
		body = "\"Cabbage. It has been decided.\"\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "slogan_5", parent = "slogan_4", at = Vector2(-0.49, -2.75), icon = "megaphone", price = 22500,
		mul = {marketing = 1.25}, title = "SLOGAN V",
		body = "\"Cabbage. Your household quota is attached.\"\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "slogan_6", parent = "slogan_5", at = Vector2(-0.49, -3.18), icon = "megaphone", price = 105000,
		needs = ["big_ideas"], mul = {marketing = 1.25}, title = "SLOGAN VI",
		body = "\"Cabbage.\"\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "pack_1", parent = "dept_manual", at = Vector2(1.79, -0.18), icon = "crate", price = 250,
		add = {pack_size = 3}, title = "BULK PROCUREMENT",
		body = "Volume is policy.
Every pack from the supply console holds 3 more
cabbages: 13 instead of 10."},
	# Its 53-unit packs need the room: locked (`after`) until the stock room (75) is bought.
	{id = "pack_2", parent = "pack_1", at = Vector2(2.75, -0.20), icon = "crate", price = 600,
		after = "storage_1", add = {pack_size = 40}, title = "CONTAINER ORDERS",
		body = "A container is parked in the street.
Every pack holds 40 more cabbages: 53 instead of 13."},
	# Storage (its own branch, STORAGE): the most units the stock holds (save.storage_cap, 20 at the
	# start), a long chain of steps, each the child of the last and at least 25% more room, up
	# to 15,000 (200 to 1,000 in two big ones). The kept ids storage_1..6 hold 75, 200, 500, 1,500, 4,000 and 9,999 as they did
	# (migrate_storage); the steps between are stock_<cap>. Past the stock room the chain is shown
	# but locked (`lock`) until the desk card REQUISITION OFF-SITE STORAGE is stamped.
	{id = "stock_25", parent = "dept_manual", at = Vector2(2.20, -0.70), icon = "crate", price = 50,
		add = {storage_cap = 5}, title = "SHELF BRACKET",
		body = "A bracket is screwed to the wall. It is load-bearing.
Storage holds 25 cabbages instead of 20."},
	{id = "stock_32", parent = "stock_25", at = Vector2(2.47, -1.13), icon = "crate", price = 90,
		add = {storage_cap = 7}, title = "STACKING POLICY",
		body = "Cabbages may now be stacked. Two high. Carefully.
Storage holds 32 cabbages instead of 25."},
	{id = "stock_40", parent = "stock_32", at = Vector2(2.74, -0.70), icon = "crate", price = 150,
		add = {storage_cap = 8}, title = "UNDER-DESK ALLOCATION",
		body = "Your legs are relocated to the left.
Storage holds 40 cabbages instead of 32."},
	{id = "stock_50", parent = "stock_40", at = Vector2(3.01, -1.13), icon = "crate", price = 240,
		add = {storage_cap = 10}, title = "FILING CABINET",
		body = "The files are shredded to make room.
Storage holds 50 cabbages instead of 40."},
	{id = "storage_1", parent = "stock_50", at = Vector2(3.28, -0.70), icon = "crate", price = 400,
		add = {storage_cap = 25}, title = "STOCK ROOM",
		body = "The broom cupboard is reassigned.
Storage holds 75 cabbages instead of 50."},
	{id = "stock_100", parent = "storage_1", at = Vector2(3.55, -1.13), icon = "crate", price = 500,
		lock = "offsite_storage", add = {storage_cap = 25}, title = "OFF-SITE LOCKER",
		body = "A locker at the bus depot. The key is laminated.
Storage holds 100 cabbages instead of 75."},
	{id = "stock_125", parent = "stock_100", at = Vector2(3.82, -0.70), icon = "crate", price = 750,
		add = {storage_cap = 25}, title = "CORRIDOR OVERFLOW",
		body = "Fire exits are reclassified as aspirational.
Storage holds 125 cabbages instead of 100."},
	{id = "stock_160", parent = "stock_125", at = Vector2(4.09, -1.13), icon = "crate", price = 1100,
		add = {storage_cap = 35}, title = "LIFT SHAFT",
		body = "The lift is out of order. Permanently. On purpose.
Storage holds 160 cabbages instead of 125."},
	{id = "storage_2", parent = "stock_160", at = Vector2(4.36, -0.70), icon = "crate", price = 1600,
		add = {storage_cap = 40}, title = "BASEMENT ANNEX",
		body = "The archive is moved to the car park.
Storage holds 200 cabbages instead of 160."},
	# Golden units (desk card golden_cabbage): what one pays, sold (save.golden_sale) or in the lab
	# (golden_lab), and which hands may take them. How often a square grows golden is the farm tree's (¶). Under the annex, below
	# the chain, clear of every node and edge (by hand, not from layout.py).
	{id = "gold_sale_1", parent = "storage_2", at = Vector2(4.06, -0.27), icon = "crate", price = 6000,
		needs = ["golden_cabbage"], add = {golden_sale = 5.0}, title = "PREMIUM SHELF",
		body = "The golden ones are kept at eye level.
A golden cabbage sold pays 15× your price, not 10×."},
	{id = "gold_sale_2", parent = "gold_sale_1", at = Vector2(4.06, 0.16), icon = "crate", price = 20000,
		needs = ["big_ideas"], add = {golden_sale = 5.0}, title = "LUXURY CLASSIFICATION",
		body = "The street is told it cannot afford them.
A golden cabbage sold pays 20× your price, not 15×."},
	# Until this, the golden lamp's Golden Age skips golden units (SaleWindow.boosts_for, GOLD_AGE). No
	# number: the window reads tree_bought. The dearest golden node (slogan_6 and hire_associate_8 cost more;
	# tools/pace.py: "nogate"), bought after chapter 2's last card in the sim.
	{id = "gold_age", parent = "gold_sale_1", at = Vector2(3.56, -0.27), icon = "crate", price = 75000,
		needs = ["golden_cabbage", "golden_lamp", "big_ideas"], title = "GOLD STANDARD",
		body = "The Golden Age is extended to the premium range.
In a Golden Age, golden cabbages get its bonus too.
Until now they paid only their own premium."},
	{id = "gold_lab_1", parent = "storage_2", at = Vector2(4.66, -0.27), icon = "pilcrow", price = 5000,
		needs = ["golden_cabbage"], add = {golden_lab = 5.0}, title = "ASSAY OFFICE",
		body = "Gold is tested. The test is gold.
A golden cabbage in the research lab gives 15× the
Findings, not 10×."},
	{id = "gold_lab_2", parent = "gold_lab_1", at = Vector2(4.66, 0.16), icon = "pilcrow", price = 18000,
		needs = ["big_ideas"], add = {golden_lab = 10.0}, title = "PRECIOUS METALS DESK",
		body = "Nobody is sure which metal.
A golden cabbage in the research lab gives 25× the
Findings, not 15×."},
	# Until these, no hand touches a golden unit; each lets one kind take them. No number:
	# entities/associate/ reads tree_bought (Associate.GOLD_SALE, GOLD_LAB).
	{id = "gold_hands", parent = "gold_sale_1", at = Vector2(3.56, 0.16), icon = "hand", price = 8000,
		title = "BULLION HANDLING CLEARANCE",
		body = "Associates are vetted, then trusted, in that order.
Hired hands throw golden cabbages out of the window
too. Until now they were left for you."},
	{id = "gold_lab_hands", parent = "gold_lab_1", at = Vector2(5.16, 0.16), icon = "hand", price = 7500,
		title = "PRECIOUS SAMPLE PROTOCOL",
		body = "Lab coats are issued tongs, and a form for the tongs.
Lab hands toss golden cabbages into the research
lab too. Until now they were left for you."},
	# The steps to chapter 2's last card (UpgradeDesk consolidation, 1,900 cabbages + $20,000): it
	# waits on AIRCRAFT HANGAR's 2,000 cap, so the chain from the annex to it is chapter 2's, spaced to
	# fill the wait between the other cards and the stamp (tools/pace.py storage); SALT MINE and up
	# are optional growth past it.
	{id = "storage_3", parent = "storage_2", at = Vector2(4.63, -1.56), icon = "crate", price = 4000,
		add = {storage_cap = 300}, title = "COLD STORE",
		body = "Kept at four degrees. So is the staff room.
Storage holds 500 cabbages instead of 200."},
	{id = "stock_1000", parent = "storage_3", at = Vector2(4.63, -2.63), icon = "crate", price = 7000,
		add = {storage_cap = 500}, title = "DECOMMISSIONED SCHOOL",
		body = "Education has been rationalised.
Storage holds 1,000 cabbages instead of 500."},
	{id = "storage_4", parent = "stock_1000", at = Vector2(4.63, -3.71), icon = "crate", price = 8500,
		add = {storage_cap = 500}, title = "REGIONAL DEPOT",
		body = "A warehouse on the ring road. Nobody visits.
Storage holds 1,500 cabbages instead of 1,000."},
	{id = "stock_2000", parent = "storage_4", at = Vector2(4.13, -3.71), icon = "crate", price = 10000,
		add = {storage_cap = 500}, title = "AIRCRAFT HANGAR",
		body = "The aircraft were surplus to requirements.
Storage holds 2,000 cabbages instead of 1,500."},
	{id = "stock_3000", parent = "stock_2000", at = Vector2(4.13, -3.28), icon = "crate", price = 12500,
		needs = ["big_ideas"], add = {storage_cap = 1000}, title = "SALT MINE",
		body = "Underground, stable, and nobody asks.
Storage holds 3,000 cabbages instead of 2,000."},
	{id = "storage_5", parent = "stock_3000", at = Vector2(4.13, -2.85), icon = "crate", price = 15500,
		add = {storage_cap = 1000}, title = "STRATEGIC RESERVE",
		body = "Classified as critical infrastructure.
Storage holds 4,000 cabbages instead of 3,000."},
	{id = "stock_6000", parent = "storage_5", at = Vector2(4.13, -2.42), icon = "crate", price = 19500,
		add = {storage_cap = 2000}, title = "FORMER MINISTRY",
		body = "The ministry has been consolidated into a memo.
Storage holds 6,000 cabbages instead of 4,000."},
	{id = "storage_6", parent = "stock_6000", at = Vector2(4.13, -1.99), icon = "crate", price = 24500,
		add = {storage_cap = 3999}, title = "NATIONAL CABBAGE RESERVE",
		body = "The nation's cabbages are now your problem.
Storage holds 9,999 cabbages instead of 6,000."},
	{id = "stock_15000", parent = "storage_6", at = Vector2(4.13, -1.56), icon = "crate", price = 31000,
		add = {storage_cap = 5001}, title = "ANNEXED PROVINCE",
		body = "A province is reclassified as a warehouse. Residents were informed by leaflet.
Storage holds 15,000 cabbages instead of 9,999."},
	{id = "conveyor_1", parent = "dept_automation", at = Vector2(-0.99, -0.87), icon = "belt", price = 775,
		research = "research_materials", mul = {dispense_interval = 0.5}, title = "CONVEYOR RETROFIT",
		body = "The ramp is motorised.\nThe chute rolls out a cabbage every 0.5 s, not every 1 s."},
	{id = "conveyor_2", parent = "conveyor_1", at = Vector2(-1.47, -1.51), icon = "belt", price = 13500,
		mul = {dispense_interval = 0.67}, title = "CONVEYOR II",
		body = "A second motor, same belt.\nThe chute rolls out a cabbage every 0.33 s, not every 0.5 s."},
	{id = "conveyor_3", parent = "conveyor_2", at = Vector2(-1.95, -2.15), icon = "belt", price = 67500,
		needs = ["big_ideas"], mul = {dispense_interval = 0.67}, title = "CONVEYOR III",
		body = "Safety guards removed.\nThe chute rolls out a cabbage every 0.22 s, not every 0.33 s."},
	{id = "associate_1", parent = "dept_automation", at = Vector2(-1.60, 0.50), icon = "clock", price = 180,
		needs = ["junior_associate"], mul = {associate_speed = 1.5}, title = "BRISK WALK I",
		body = "A stopwatch on every associate's desk.\nHired hands and lab hands move 50% faster."},
	{id = "associate_2", parent = "associate_1", at = Vector2(-2.03, 0.94), icon = "clock", price = 525,
		research = "performance_review", mul = {associate_speed = 1.5}, title = "BRISK WALK II",
		body = "Lunch is now a standing meeting.\nHired hands and lab hands move 50% faster again\n(2.25× the start speed)."},
	{id = "hire_associate_2", parent = "dept_automation", at = Vector2(-1.10, 0.58), icon = "hand", price = 150,
		needs = ["junior_associate"], hire = true, title = "HIRE ASSOCIATE II",
		body = "Headcount approved.\nOne more hired hand throws cabbages out of the\nwindow: 2 instead of 1."},
	{id = "hire_associate_3", parent = "hire_associate_2", at = Vector2(-1.19, 0.97), icon = "hand", price = 400,
		hire = true, title = "HIRE ASSOCIATE III",
		body = "Another sleeve, same grey.\nOne more hired hand throws cabbages out of the\nwindow: 3 instead of 2."},
	{id = "hire_associate_4", parent = "hire_associate_3", at = Vector2(-1.29, 1.36), icon = "hand", price = 1100,
		hire = true, title = "HIRE ASSOCIATE IV",
		body = "Interviews were waived.\nOne more hired hand throws cabbages out of the\nwindow: 4 instead of 3."},
	{id = "hire_associate_5", parent = "hire_associate_4", at = Vector2(-1.39, 1.75), icon = "hand", price = 3000,
		research = "performance_review", hire = true, title = "HIRE ASSOCIATE V",
		body = "The desk is now a department.\nOne more hired hand throws cabbages out of the\nwindow: 5 instead of 4."},
	{id = "hire_associate_6", parent = "hire_associate_5", at = Vector2(-1.49, 2.14), icon = "hand", price = 12000,
		hire = true, title = "HIRE ASSOCIATE VI",
		body = "Names are no longer collected.\nOne more hired hand throws cabbages out of the\nwindow: 6 instead of 5."},
	{id = "hire_associate_7", parent = "hire_associate_6", at = Vector2(-1.59, 2.53), icon = "hand", price = 35000,
		needs = ["big_ideas"], hire = true, title = "HIRE ASSOCIATE VII",
		body = "A second coat rack is requisitioned.\nOne more hired hand throws cabbages out of the\nwindow: 7 instead of 6."},
	{id = "hire_associate_8", parent = "hire_associate_7", at = Vector2(-1.69, 2.92), icon = "hand", price = 100000,
		hire = true, title = "HIRE ASSOCIATE VIII",
		body = "Full complement. Morale is not tracked.\nOne more hired hand throws cabbages out of the\nwindow: 8 instead of 7."},
	{id = "qa_time", parent = "dept_qa", at = Vector2(0.00, 1.33), icon = "lens", price = 150,
		needs = ["quality_assurance"], research = "research_inspection", mul = {qa_time = 0.75}, title = "FASTER ANALYSIS",
		body = "The scan line is told to hurry.\nThe research lab analyses a cabbage in 3.75 s, not 5 s."},
	{id = "qa_findings", parent = "qa_time", at = Vector2(0.15, 1.89), icon = "pilcrow", price = 575,
		add = {findings_per_cabbage = 1}, title = "MORE FINDINGS",
		body = "Standards are revised.\nEach analysed cabbage gives 1 more Finding:\n1 to 2, or 2 to 3 after the 100-cabbages memo."},
	{id = "qa_fast_track", parent = "qa_findings", at = Vector2(0.15, 2.45), icon = "lens", price = 5000,
		mul = {qa_time = 0.5}, title = "LAB FAST TRACK",
		body = "Analysis is now a formality.\nThe research lab analyses a cabbage in 1.9 s, not 3.75 s."},
	{id = "double_findings", parent = "qa_fast_track", at = Vector2(0.15, 3.01), icon = "pilcrow", price = 20000,
		needs = ["big_ideas"], mul = {findings_per_cabbage = 2}, title = "DOUBLE FINDINGS",
		body = "Every finding is filed twice.\nEach cabbage analysed gives twice the Findings."},
	# Supply + automation (desk space, packs, auto-buy, hands, seating, campaigns, vacuums, QA rest):
	# entities/supply_console/, entities/associate/, entities/vacuum/, entities/qa_bay/.
	# The mat allowance: one node per unit on the mat past the 3 the card gives (MAT_FIRST..MAT_SINGLES),
	# each the child of the last, 1.4 times dearer each; then three units a step to MAT_MAX (a single
	# unit stopped being felt there: +4-7% each). The three-unit steps cost more than chapter 2's purse
	# holds ($40,000), so they wait for big_ideas.
	{id = "mat_4", parent = "dept_manual", at = Vector2(2.26, -1.57), icon = "desk", price = 2100,
		needs = ["mat_allowance"], add = {desk_capacity = 1}, title = "4-CABBAGE MAT",
		body = "Floor space is leased by the cabbage.\nOne more cabbage fits on the mat\n(the chute keeps it full): 4 instead of 3."},
	{id = "mat_5", parent = "mat_4", at = Vector2(2.26, -2.00), icon = "desk", price = 2950,
		add = {desk_capacity = 1}, title = "5-CABBAGE MAT",
		body = "The mat is measured again, generously.\nOne more cabbage fits on the mat\n(the chute keeps it full): 5 instead of 4."},
	{id = "mat_6", parent = "mat_5", at = Vector2(2.26, -2.43), icon = "desk", price = 4100,
		add = {desk_capacity = 1}, title = "6-CABBAGE MAT",
		body = "A corner of the mat is reclaimed from a stapler.\nOne more cabbage fits on the mat\n(the chute keeps it full): 6 instead of 5."},
	{id = "mat_7", parent = "mat_6", at = Vector2(2.26, -2.86), icon = "desk", price = 5750,
		add = {desk_capacity = 1}, title = "7-CABBAGE MAT",
		body = "The mat is now billed by the square inch.\nOne more cabbage fits on the mat\n(the chute keeps it full): 7 instead of 6."},
	{id = "mat_8", parent = "mat_7", at = Vector2(2.26, -3.29), icon = "desk", price = 8050,
		add = {desk_capacity = 1}, title = "8-CABBAGE MAT",
		body = "Elbow room is reclassified as storage.\nOne more cabbage fits on the mat\n(the chute keeps it full): 8 instead of 7."},
	{id = "mat_9", parent = "mat_8", at = Vector2(2.26, -3.72), icon = "desk", price = 11300,
		add = {desk_capacity = 1}, title = "9-CABBAGE MAT",
		body = "The mat's edges are moved by memo.\nOne more cabbage fits on the mat\n(the chute keeps it full): 9 instead of 8."},
	{id = "mat_10", parent = "mat_9", at = Vector2(2.76, -3.72), icon = "desk", price = 15800,
		add = {desk_capacity = 1}, title = "10-CABBAGE MAT",
		body = "A second mat is taped under the first.\nOne more cabbage fits on the mat\n(the chute keeps it full): 10 instead of 9."},
	{id = "mat_11", parent = "mat_10", at = Vector2(2.76, -3.29), icon = "desk", price = 22150,
		add = {desk_capacity = 1}, title = "11-CABBAGE MAT",
		body = "Coffee is no longer permitted on the mat.\nOne more cabbage fits on the mat\n(the chute keeps it full): 11 instead of 10."},
	{id = "mat_14", parent = "mat_11", at = Vector2(2.76, -2.86), icon = "desk", price = 100000,
		needs = ["big_ideas"], add = {desk_capacity = 3}, title = "MAT ANNEXATION",
		body = "The in-tray and the desk lamp are relocated.
Three more cabbages fit on the mat
(the chute keeps it full): 14 instead of 11."},
	{id = "mat_17", parent = "mat_14", at = Vector2(2.76, -2.43), icon = "desk", price = 300000,
		add = {desk_capacity = 3}, title = "DESK REZONING",
		body = "Personal items and the telephone are removed.
Three more cabbages fit on the mat
(the chute keeps it full): 17 instead of 14."},
	{id = "mat_20", parent = "mat_17", at = Vector2(2.76, -2.00), icon = "desk", price = 700000,
		add = {desk_capacity = 3}, title = "TOTAL MAT",
		body = "There is no more desk. There is only the mat.
Three more cabbages fit on the mat
(the chute keeps it full): 20 instead of 17."},
	{id = "discount_1", parent = "pack_1", at = Vector2(2.28, 0.05), icon = "crate", price = 350,
		mul = {pack_discount = 0.7}, title = "SUPPLIER REVIEW",
		body = "The supplier is reminded of alternatives.\nPacks cost 30% less. The ticker shows the cut price."},
	{id = "auto_reserve_1", parent = "dept_automation", at = Vector2(-1.21, -0.44), icon = "clock", price = 600,
		needs = ["auto_procurement"], add = {auto_reserve = 7}, title = "SAFETY STOCK",
		body = "The order is placed earlier.\nAuto-buy orders a pack at 10 cabbages left, not 3."},
	{id = "auto_smart_1", parent = "auto_reserve_1", at = Vector2(-1.69, -1.09), icon = "lens", price = 700,
		add = {auto_max_factor = -0.5}, title = "PRICE DISCIPLINE",
		body = "The order waits for a fair price.\nAuto-buy waits for the base pack price or lower\n(it used to pay up to 150%), unless stock runs out."},
	{id = "hire_associate_9", parent = "hire_associate_8", at = Vector2(-1.78, 3.31), icon = "hand", price = 250000,
		hire = true, title = "HIRE ASSOCIATE IX",
		body = "Desks are now shared in shifts.\nOne more hired hand throws cabbages out of the\nwindow: 9 instead of 8."},
	{id = "hire_associate_10", parent = "hire_associate_9", at = Vector2(-1.88, 3.70), icon = "hand", price = 400000,
		hire = true, title = "HIRE ASSOCIATE X",
		body = "Headcount is final. For now.\nOne more hired hand throws cabbages out of the\nwindow: 10 instead of 9."},
	{id = "seating_1", parent = "associate_1", at = Vector2(-1.89, 1.36), icon = "chair", price = 500,
		mul = {hand_output = 1.5}, title = "OPEN-PLAN SEATING I",
		body = "The walls between associates come down.\nHired hands and lab hands set off 50% more often:\nevery 5.3 s, not 8 s (2.7 s, not 4 s, after the study)."},
	{id = "seating_2", parent = "seating_1", at = Vector2(-2.36, 1.76), icon = "chair", price = 13500,
		mul = {hand_output = 1.5}, title = "OPEN-PLAN SEATING II",
		body = "Chairs are replaced with a bench.\nHired hands and lab hands set off 50% more often\nagain (e.g. every 1.8 s, not 2.7 s)."},
	{id = "campaign_1", parent = "slogan_2", at = Vector2(0.49, -1.89), icon = "megaphone", price = 220,
		mul = {marketing = 1.25}, title = "SYNERGY JINGLE",
		body = "Four notes. Staff are asked to hum them.\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "campaign_2", parent = "campaign_1", at = Vector2(0.49, -2.32), icon = "megaphone", price = 1500,
		mul = {marketing = 1.25}, title = "LEAF IT TO US",
		body = "Legal approved the pun.\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "campaign_3", parent = "campaign_2", at = Vector2(0.49, -2.75), icon = "megaphone", price = 2500,
		mul = {marketing = 1.25}, title = "CRUCIFEROUS EXCELLENCE",
		body = "Nobody knows the word. Everyone trusts it.\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "campaign_4", parent = "slogan_3", at = Vector2(0.00, -2.32), icon = "megaphone", price = 2500,
		research = "research_sentiment", mul = {marketing = 1.25}, title = "BRASSICA FOR THE MASSES",
		body = "Posters in every stairwell.\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "campaign_5", parent = "campaign_4", at = Vector2(0.00, -2.75), icon = "megaphone", price = 20000,
		mul = {marketing = 1.25}, title = "TRUSTED BY THE MINISTRY",
		body = "The Ministry has not denied it.\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "campaign_6", parent = "campaign_5", at = Vector2(0.00, -3.18), icon = "megaphone", price = 67500,
		needs = ["big_ideas"], mul = {marketing = 1.25}, title = "THE ONLY VEGETABLE",
		body = "Other vegetables are under review.\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	# Coin units (entities/vacuum/): many small steps (drive, bag, dock, nozzle) between the big ones,
	# the second and third robot. A spine to the left with the docks above and the rest below; the bag
	# steps sit on the spine before each robot, so every "instead of" holds whatever order is bought.
	# Old saves get the bag steps now on their path (migrate_vacuums). Paced in tools/pace.py.
	{id = "vacuum_speed_1", parent = "dept_automation", at = Vector2(-1.50, 0.05), icon = "puck", price = 150,
		needs = ["coin_collector"], mul = {vacuum_speed = 1.5}, title = "FIRMWARE UPDATE",
		body = "The unit is told to hurry.
Coin robots drive 50% faster."},
	{id = "vacuum_hopper_1", parent = "vacuum_speed_1", at = Vector2(-2.05, 0.10), icon = "puck", price = 250,
		add = {vacuum_capacity = 4}, title = "LARGER BAG",
		body = "The bag is replaced with a slightly larger bag.
Each coin robot carries 12 coins per trip
before it drives home, not 8."},
	{id = "vacuum_dock_1", parent = "vacuum_hopper_1", at = Vector2(-2.61, -0.30), icon = "clock", price = 450,
		mul = {vacuum_rest = 0.5}, title = "QUICK DISCHARGE",
		body = "The charging contacts are now polished weekly.
Coin robots recharge on their docks for 2 s
after emptying, not 4 s."},
	{id = "vacuum_dock_2", parent = "vacuum_dock_1", at = Vector2(-3.17, -0.26), icon = "clock", price = 1000,
		mul = {vacuum_rest = 0.5}, title = "RAPID DISCHARGE",
		body = "The safety interval was reviewed and found safe enough.
Coin robots recharge on their docks for 1 s
after emptying, not 2 s."},
	{id = "vacuum_2", parent = "vacuum_hopper_1", at = Vector2(-2.61, 0.14), icon = "puck", price = 800,
		add = {vacuums = 1, vacuum_capacity = 12}, title = "SECOND UNIT",
		body = "A second unit is unboxed, with a bigger bag.
A second coin robot docks on the mat.
Each robot carries 24 coins per trip, not 12."},
	{id = "vacuum_nozzle_1", parent = "vacuum_2", at = Vector2(-2.61, 0.58), icon = "puck", price = 600,
		mul = {vacuum_reach = 1.5}, title = "WIDER NOZZLE",
		body = "The nozzle is widened by facilities request.
Coin robots suck up coins from 50% further away."},
	{id = "vacuum_hopper_2", parent = "vacuum_2", at = Vector2(-3.17, 0.19), icon = "puck", price = 1500,
		add = {vacuum_capacity = 12}, title = "BAG EXTENSION",
		body = "A second bag is taped to the first.
Each coin robot carries 36 coins per trip
before it drives home, not 24."},
	{id = "vacuum_speed_2", parent = "vacuum_hopper_2", at = Vector2(-3.17, 0.62), icon = "puck", price = 2000,
		mul = {vacuum_speed = 1.5, vacuum_reach = 1.5}, title = "FIRMWARE UPDATE II",
		body = "Obstacle detection is disabled. The unit is louder.
Coin robots drive 50% faster again and suck up
coins from 50% further away."},
	{id = "vacuum_3", parent = "vacuum_hopper_2", at = Vector2(-3.73, 0.23), icon = "puck", price = 6000,
		add = {vacuums = 1, vacuum_capacity = 30}, title = "THIRD UNIT",
		body = "The units have formed a department.
A third coin robot docks on the mat.
Each robot carries 66 coins per trip, not 36."},
	{id = "vacuum_speed_3", parent = "vacuum_3", at = Vector2(-3.73, 0.66), icon = "puck", price = 12000,
		mul = {vacuum_speed = 1.4}, title = "FIRMWARE UPDATE III",
		body = "The speed limiter is reclassified as a suggestion.
Coin robots drive 40% faster."},
	# No number: entities/vacuum/ reads tree_bought (CoinVacuums.STABILISER).
	{id = "vacuum_gyro", parent = "vacuum_speed_1", at = Vector2(-2.08, -0.33), icon = "puck", price = 400,
		title = "GYROSCOPIC STABILISER",
		body = "A lead plate is bolted underneath. Falling over
is now a disciplinary matter.
Coin robots no longer tip onto their backs."},
	{id = "qa_slot_2", parent = "qa_time", at = Vector2(-0.15, 1.89), icon = "lens", price = 700,
		add = {qa_slots = 1}, title = "SECOND BENCH",
		body = "A second bench in the lab.\nThe research lab analyses 2 cabbages at once, not 1."},
	{id = "qa_slot_3", parent = "qa_slot_2", at = Vector2(-0.15, 2.45), icon = "lens", price = 1800,
		add = {qa_slots = 1}, title = "THIRD BENCH",
		body = "The lab is now an institute.\nThe research lab analyses 3 cabbages at once, not 2."},
	{id = "qa_slot_4", parent = "qa_slot_3", at = Vector2(-0.15, 3.01), icon = "lens", price = 4500,
		add = {qa_slots = 1}, title = "FOURTH BENCH",
		body = "The institute has applied for a wing.\nThe research lab analyses 4 cabbages at once, not 3."},
	{id = "qa_slot_5", parent = "qa_slot_4", at = Vector2(-0.15, 3.57), icon = "lens", price = 12000,
		add = {qa_slots = 1}, title = "FIFTH BENCH",
		body = "The wing has a committee for its benches.\nThe research lab analyses 5 cabbages at once, not 4."},
	# Manager (down-right) and pricing consultant (up-right): entities/manager/, entities/consultant/.
	{id = "manager_time", parent = "dept_manual", at = Vector2(1.01, 0.92), icon = "clock", price = 200,
		needs = ["managerial_oversight"], add = {manager_time = 15.0}, title = "EXTENDED DEADLINES",
		body = "The manager is shown a calendar.\nQuotas give you 60 s instead of 45 s."},
	{id = "manager_reward_1", parent = "manager_time", at = Vector2(1.11, 1.48), icon = "crate", price = 875,
		mul = {manager_reward = 1.5}, title = "PERFORMANCE BONUS",
		body = "Bonuses are now discussed openly.\nMet quotas pay quota × price × 1.5, not × 1."},
	{id = "manager_raise", parent = "manager_reward_1", at = Vector2(1.21, 2.04), icon = "lens", price = 2000,
		add = {manager_raise = -0.1}, title = "REALISTIC TARGETS",
		body = "Ambition is capped by memo.\nQuotas ask for at most your pace plus 15%, not plus 25%.\nPace: full cabbages you sold per quota window,\naveraged over your last 5 minutes. Minis do not count."},
	{id = "manager_reward_2", parent = "manager_raise", at = Vector2(1.31, 2.60), icon = "crate", price = 6250,
		mul = {manager_reward = 1.5}, title = "EMPLOYEE OF THE QUARTER",
		body = "A frame is purchased. It stays empty.\nMet quotas pay quota × price × 2.25, not × 1.5."},
	{id = "consultant_speed_1", parent = "dept_automation", at = Vector2(-0.86, -1.47), icon = "clock", price = 200,
		needs = ["pricing_consultant"], mul = {consultant_interval = 0.5}, title = "BILLABLE HOURS",
		body = "The consultant bills by the tap.\nIt taps the slate every 2 s instead of 4 s."},
	# No number: the slate and the mandate read tree_bought (PriceSlate.FORECAST, FORECAST_TIME).
	{id = "consultant_mood", parent = "consultant_speed_1", at = Vector2(-0.94, -1.96), icon = "lens", price = 425,
		title = "READS THE ROOM",
		body = "The consultant reads the room in advance.\nThe slate and the mandate show which way\nthe street next moves its prices."},
	{id = "consultant_clock", parent = "consultant_speed_1", at = Vector2(-1.32, -1.88), icon = "clock", price = 300,
		title = "STREET TIMETABLE",
		body = "The street's mood swings are scheduled by memo.\nThe slate and the mandate count down to\nthe street's next price move."},
	{id = "consultant_smart", parent = "consultant_mood", at = Vector2(-1.02, -2.45), icon = "crate", price = 2000,
		title = "YIELD OPTIMISATION",
		body = "Billed per tap, delivered in one.\nThe consultant chalks its target price in a single\ntap instead of $1 at a time. Wild streets, met at once."},
	{id = "consultant_speed_2", parent = "consultant_smart", at = Vector2(-1.11, -2.95), icon = "clock", price = 18000,
		mul = {consultant_interval = 0.5}, title = "RETAINER",
		body = "The consultant no longer leaves.\nIt taps the slate every 1 s instead of 2 s."},
	# Sales events (catch combo far up-left, waste bin down, window targets far right):
	# entities/catch_combo/, rotten_bin/, window_targets/. The golden lamp's card (entities/golden_lamp/)
	# is the last of its kind: nothing waits on it but the optional GOLD STANDARD (gold_age). Its old nodes (lamp_mult, lamp_time, lamp_every) are
	# gone; an old save keeps their ids in tree_bought, read by nothing, and their numbers.
	{id = "combo_window", parent = "dept_manual", at = Vector2(1.74, 0.74), icon = "clock", price = 150,
		needs = ["catch_combo"], add = {miss_keep = 0.5}, title = "GRACE PERIOD",
		body = "Interceptions are counted generously.\nA missed catch halves the combo instead of ending it."},
	{id = "combo_cap", parent = "combo_window", at = Vector2(2.21, 1.26), icon = "crate", price = 725,
		add = {combo_cap = 0.5}, title = "UNCAPPED ENTHUSIASM",
		body = "The ceiling is raised by memo.\nThe combo tops out at +100% instead of +50%."},
	{id = "combo_step", parent = "combo_cap", at = Vector2(2.67, 1.78), icon = "hand", price = 4250,
		mul = {combo_step = 2.0}, title = "REFLEX TRAINING",
		body = "A mandatory seminar on catching things.\nEach catch adds +20% to sales instead of +10%."},
	{id = "free_carry", parent = "combo_step", at = Vector2(3.13, 2.30), icon = "hand", price = 15000,
		mul = {carry_weight = 0.0}, title = "FRICTIONLESS HANDLING",
		body = "Cabbages have been reclassified as weightless.\nA held cabbage follows your mouse at once instead of lagging behind."},
	{id = "bin_mouth", parent = "dept_manual", at = Vector2(1.43, 1.46), icon = "lens", price = 120,
		needs = ["catch_combo"], mul = {bin_mouth = 1.35}, title = "WIDER RECEPTACLE",
		body = "A larger bin is requisitioned.\nThe bin's opening is 35% wider: cabbages dropped\nnear it fall in from further away."},
	{id = "bin_rebate", parent = "bin_mouth", at = Vector2(1.89, 1.98), icon = "crate", price = 575,
		add = {bin_coins = 2}, title = "DISPOSAL REBATE",
		body = "Waste is now a revenue stream.\nA rotten cabbage in the bin pops out $2 in coins\n(nothing before), whatever your price."},
	{id = "bin_rebate_2", parent = "bin_rebate", at = Vector2(2.36, 2.50), icon = "crate", price = 775,
		add = {bin_coins = 1}, title = "SALVAGE CREDIT",
		body = "Rot is reclassified as inventory.\nA rotten cabbage in the bin pops out $3 in coins\n($2 before), whatever your price."},
	{id = "bin_rebate_3", parent = "bin_rebate_2", at = Vector2(2.82, 3.02), icon = "crate", price = 3500,
		add = {bin_coins = 2}, title = "COMPOST CONTRACT",
		body = "The Ministry buys it by the tonne.\nA rotten cabbage in the bin pops out $5 in coins\n($3 before), whatever your price."},
	{id = "bin_rebate_4", parent = "bin_rebate_3", at = Vector2(3.29, 3.55), icon = "crate", price = 13000,
		add = {bin_coins = 3}, title = "WASTE MONETISATION",
		body = "Spoilage now has its own quarterly target.\nA rotten cabbage in the bin pops out $8 in coins\n($5 before), whatever your price."},
	{id = "bin_rebate_5", parent = "bin_rebate_4", at = Vector2(3.76, 4.07), icon = "crate", price = 40000,
		needs = ["big_ideas"], add = {bin_coins = 4}, title = "SPOILAGE PREMIUM",
		body = "A rotten cabbage is worth more than a fresh one.\nA rotten cabbage in the bin pops out $12 in coins\n($8 before), whatever your price."},
	{id = "hands_bin", parent = "dept_automation", at = Vector2(-0.52, 0.96), icon = "hand", price = 400,
		needs = ["junior_associate", "catch_combo"], add = {hands_bin = 1}, title = "WASTE HANDLING PROTOCOL",
		body = "Associates are shown where the bin is.\nHired hands throw rotten cabbages into the bin\ninstead of selling them or leaving them."},
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
		body = "The cabbages are asked to be smaller, sooner.\nMinis drop 43% more often (every 14 s, not 20 s)."},
	{id = "mini_rate_2", parent = "mini_rate_1", at = Vector2(0.70, -1.46), icon = "clock", price = 500,
		mul = {mini_every = 0.7}, title = "MINIATURISATION II",
		body = "Nobody measured the old ones.\nMinis drop 43% more often (wait between drops\n×0.7, e.g. every 9.8 s, not 14 s)."},
	{id = "mini_rate_3", parent = "mini_rate_2", at = Vector2(0.81, -2.09), icon = "clock", price = 2000,
		mul = {mini_every = 0.7}, title = "MINIATURISATION III",
		body = "The cabbages are now a rounding error.\nMinis drop 43% more often (wait ×0.7,\ne.g. every 6.9 s, not 9.8 s)."},
	{id = "mini_value_1", parent = "mini_rate_1", at = Vector2(1.06, -1.30), icon = "crate", price = 180,
		add = {mini_value = 0.08}, title = "PORTION REVIEW",
		body = "A mini is reclassified as a third.\nMinis sell for 1/3 of your price, not 1/4."},
	{id = "mini_value_2", parent = "mini_value_1", at = Vector2(1.17, -1.93), icon = "crate", price = 900,
		add = {mini_value = 0.17}, title = "HALF-CABBAGE STANDARD",
		body = "The street is told it is half a cabbage.\nMinis sell for 1/2 of your price, not 1/3."},
	{id = "tube_speed_1", parent = "mini_rate_1", at = Vector2(1.42, -1.15), icon = "belt", price = 300,
		needs = ["mini_tube"], mul = {tube_speed = 1.5, mini_every = 0.8}, title = "PNEUMATIC PRESSURE",
		body = "The compressor is set past its label.\nMinis roll through the tube 50% faster and drop\n25% more often (the wait between drops ×0.8)."},
	# The growing station (desk card mini_station, entities/growing_station/): save.mini_grow_chance
	# 5% -> 8 -> 12 -> 18 -> 25%. Prices are placeholders, not paced yet (tools/pace.py); spots picked
	# by hand clear of every node, edge and heading (not from layout.py).
	{id = "grow_1", parent = "tube_speed_1", at = Vector2(1.55, -1.62), icon = "lens", price = 1200,
		needs = ["mini_station"], add = {mini_grow_chance = 0.03}, title = "NUTRIENT MIST",
		body = "The chamber is humidified. Nobody asked how.\n8% of minis through the growing station come out\nfull cabbages, not 5%."},
	{id = "grow_2", parent = "grow_1", at = Vector2(1.68, -2.10), icon = "clock", price = 3500,
		add = {mini_grow_chance = 0.04}, title = "EXTENDED EXPOSURE",
		body = "Minis are kept in the chamber after hours.\n12% of minis through the growing station come out\nfull cabbages, not 8%."},
	{id = "grow_3", parent = "grow_2", at = Vector2(1.72, -2.60), icon = "lens", price = 9000,
		add = {mini_grow_chance = 0.06}, title = "GROWTH TARGETS",
		body = "Each mini is given a quarterly target.\n18% of minis through the growing station come out\nfull cabbages, not 12%."},
	{id = "grow_4", parent = "grow_3", at = Vector2(1.66, -3.10), icon = "crate", price = 22000,
		needs = ["big_ideas"], add = {mini_grow_chance = 0.07}, title = "MANDATORY MATURITY",
		body = "Remaining small is no longer an option.\n1 mini in 4 through the growing station comes out\na full cabbage, not 18%."},
	# Research units and lab hands (QA, down): Cabbage.research, entities/associate/ (research hands).
	{id = "research_mult_1", parent = "dept_qa", at = Vector2(-0.44, 1.61), icon = "pilcrow", price = 350,
		needs = ["research_cabbage"], add = {research_mult = 2.0}, title = "PEER REVIEW",
		body = "Each research cabbage is read by two people.\nBlue research cabbages give 5× the Findings, not 3×."},
	{id = "research_mult_2", parent = "research_mult_1", at = Vector2(-0.50, 2.19), icon = "pilcrow", price = 1600,
		add = {research_mult = 3.0}, title = "LONGITUDINAL STUDY",
		body = "The study is extended indefinitely.\nBlue research cabbages give 8× the Findings, not 5×."},
	{id = "research_mult_3", parent = "research_mult_2", at = Vector2(-0.70, 2.57), icon = "pilcrow", price = 7500,
		add = {research_mult = 4.0}, title = "CONTROL GROUP",
		body = "Half the cabbages are told nothing.\nBlue research cabbages give 12× the Findings, not 8×."},
	{id = "research_mult_4", parent = "research_mult_3", at = Vector2(-0.90, 2.95), icon = "pilcrow", price = 35000,
		needs = ["big_ideas"], add = {research_mult = 8.0}, title = "PUBLISH OR PERISH",
		body = "The findings are published internally.\nBlue research cabbages give 20× the Findings, not 12×."},
	{id = "research_chance_1", parent = "research_mult_1", at = Vector2(-0.79, 1.80), icon = "lens", price = 800,
		add = {research_chance = 0.05}, title = "SAMPLING QUOTA",
		body = "More cabbages are selected at random.\n1 cabbage in ~7 off the chute is blue, not 1 in 10."},
	{id = "research_chance_2", parent = "research_chance_1", at = Vector2(-0.99, 2.19), icon = "lens", price = 4500,
		add = {research_chance = 0.05}, title = "SAMPLING QUOTA II",
		body = "Random is redefined.\n1 cabbage in 5 off the chute is blue, not 1 in ~7."},
	{id = "research_chance_3", parent = "research_chance_2", at = Vector2(-1.19, 2.57), icon = "lens", price = 22000,
		needs = ["big_ideas"], add = {research_chance = 0.05}, title = "SAMPLING QUOTA III",
		body = "Every cabbage is now a candidate.\n1 cabbage in 4 off the chute is blue, not 1 in 5."},
	{id = "lab_hand_2", parent = "dept_qa", at = Vector2(0.50, 1.92), icon = "hand", price = 900,
		needs = ["research_assistant"], add = {research_hands = 1}, title = "SECOND LAB ASSISTANT",
		body = "A second coat, a smaller size.\nOne more lab hand throws cabbages into the\nresearch lab: 2 instead of 1."},
	{id = "lab_hand_3", parent = "lab_hand_2", at = Vector2(0.72, 2.41), icon = "hand", price = 9000,
		add = {research_hands = 1}, title = "THIRD LAB ASSISTANT",
		body = "The lab has a waiting list now.\nOne more lab hand throws cabbages into the\nresearch lab: 3 instead of 2."},
	# HANDLING (desk card hand_schedule): each lists one more cabbage kind on the handling schedule, so
	# it can be struck for lab hands or hired hands (HandSchedule.NODES; no number: it reads tree_bought).
	# The golden annex waits for golden cabbages and the hired hands' clearance (`after`): before a
	# clearance no hand takes gold, so there is nothing to withhold. By hand, between the lab hands and
	# the manager's column; the golden annex past THIRD LAB ASSISTANT, in the gap beside MANAGERIAL
	# SIGN-OFF (the pocket above it is full).
	{id = "schedule_research", parent = "dept_qa", at = Vector2(0.72, 1.40), icon = "hand", price = 120,
		needs = ["hand_schedule"], title = "ANNEX: BLUE",
		body = "Blue is a jurisdiction.\nThe handling schedule also lists blue research\ncabbages: strike them for either kind of hand."},
	{id = "schedule_mini", parent = "schedule_research", at = Vector2(0.80, 1.80), icon = "hand", price = 300,
		needs = ["mini_cabbages"], title = "ANNEX: MINI",
		body = "Small cabbages, full paperwork.\nThe handling schedule also lists mini cabbages:\nstrike them for either kind of hand."},
	{id = "schedule_golden", parent = "schedule_mini", at = Vector2(0.89, 2.93), icon = "hand", price = 6000,
		needs = ["golden_cabbage"], after = "gold_hands", title = "ANNEX: GOLD",
		body = "Clearance was the easy part.\nThe handling schedule also lists golden cabbages.\nIt only withholds: clearances still apply."},
	# Managerial work (desk cards own_sales, own_research): the player's own sales (save.own_sale) and
	# own flicks into the lab (own_lab), 1.2 from the card to 1.6. By hand, clear of every node and
	# edge: the sales under the manager's first node (down past the bin rebates' left), the lab under
	# MORE FINDINGS (down between the QA column and the lab hands).
	{id = "own_sale_1", parent = "manager_time", at = Vector2(1.62, 2.30), icon = "hand", price = 3000,
		needs = ["own_sales"], add = {own_sale = 0.1}, title = "COUNTERSIGNED SALES",
		body = "Every sale you make is now countersigned. By you.\nCabbages you sell yourself pay 30% more, not 20%."},
	{id = "own_sale_2", parent = "own_sale_1", at = Vector2(1.72, 2.85), icon = "hand", price = 14000,
		add = {own_sale = 0.15}, title = "AIR OF AUTHORITY",
		body = "The street can tell a manager threw it.\nCabbages you sell yourself pay 45% more, not 30%."},
	{id = "own_sale_3", parent = "own_sale_2", at = Vector2(1.82, 3.40), icon = "hand", price = 32000,
		needs = ["big_ideas"], add = {own_sale = 0.15}, title = "EXECUTIVE HANDLING",
		body = "Each cabbage is now released, not thrown.\nCabbages you sell yourself pay 60% more, not 45%."},
	{id = "own_lab_1", parent = "qa_findings", at = Vector2(0.50, 2.95), icon = "pilcrow", price = 2500,
		needs = ["own_research"], add = {own_lab = 0.1}, title = "MANAGERIAL SIGN-OFF",
		body = "A manager has looked at it. That is the finding.\nCabbages you flick into the research lab yourself\ngive 30% more Findings, not 20%."},
	{id = "own_lab_2", parent = "own_lab_1", at = Vector2(0.60, 3.45), icon = "pilcrow", price = 12000,
		add = {own_lab = 0.15}, title = "HANDS-ON LEADERSHIP",
		body = "The lab coat is worn over the suit.\nCabbages you flick into the research lab yourself\ngive 45% more Findings, not 30%."},
	{id = "own_lab_3", parent = "own_lab_2", at = Vector2(0.70, 3.95), icon = "pilcrow", price = 28000,
		needs = ["big_ideas"], add = {own_lab = 0.15}, title = "PRINCIPAL INVESTIGATOR",
		body = "Your name goes first on every paper. Then nobody's.\nCabbages you flick into the research lab yourself\ngive 60% more Findings, not 45%."},
	# ---- Chapter 3: the wide sheet's own nodes (desk card big_ideas). Prices paced in tools/pace.py
	# (`python tools/pace.py ch3`): the desk earns about $50k a minute when the sheet widens and about
	# $1.5M when the fifth farm is bought, some 50 min later.
	# Spots by hand, checked by tools/projector_layout/layout.py ("fixed" sectors) and the suite. ----
	# MARKETING II, past SLOGAN VI: two more slogans, then the street's bad moods stop counting. No
	# number for the last: the slate reads tree_bought (PriceSlate.MANDATORY, street_mood).
	{id = "slogan_7", parent = "slogan_6", at = Vector2(-0.49, -3.61), icon = "megaphone", price = 300000,
		needs = ["big_ideas"], mul = {marketing = 1.25}, title = "BOARD-APPROVED SLOGAN",
		body = "\"Cabbage. Approved by the board.\"\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "slogan_8", parent = "slogan_7", at = Vector2(-0.49, -4.04), icon = "megaphone", price = 1200000,
		mul = {marketing = 1.25}, title = "NATIONAL CAMPAIGN",
		body = "Every wall, every wireless, every hour.\nThe street now pays 25% more without refusing.\nRaise your price on the slate to cash in."},
	{id = "mandatory_consumption", parent = "slogan_8", at = Vector2(-0.49, -4.47), icon = "megaphone", price = 3000000,
		title = "MANDATORY CONSUMPTION",
		body = "Demand is no longer a matter of opinion.\nThe street's bad moods no longer count: it pays\nas in a normal mood, or better in a good one."},
	# HEADCOUNT II, off HIRE ASSOCIATE VII: two hands at once (past Associate.MAX_VISIBLE the visible
	# ones work faster), then every money hand throws save.hand_trip cabbages a trip (Associate.throws_again).
	{id = "headcount_2", parent = "hire_associate_7", at = Vector2(-2.35, 2.75), icon = "hand", price = 600000,
		needs = ["big_ideas"], add = {hands = 2}, title = "DEPARTMENTAL HEADCOUNT",
		body = "A second department is opened to manage the first.\nTwo more hired hands throw cabbages out of the\nwindow."},
	{id = "two_handed", parent = "headcount_2", at = Vector2(-3.00, 3.10), icon = "hand", price = 2000000,
		add = {hand_trip = 1}, title = "TWO-HANDED POLICY",
		body = "The other hand was idle. This has been corrected.\nEvery hired hand throws two cabbages out of the\nwindow per trip before it goes back, not one."},
	# CONDENSATION (desk card condense): which kinds come down the chute condensed (no number:
	# CabbageFeeder.CONDENSE_RESEARCH / CONDENSE_GOLD read tree_bought) and how many cabbages a
	# condensed one holds (save.condense, 2 from the card).
	{id = "condense_research", parent = "dept_manual", at = Vector2(3.60, 0.85), icon = "pilcrow", price = 100000,
		needs = ["big_ideas", "condense"], title = "CONDENSED SAMPLES",
		body = "A sample of two is a study.\nBlue research cabbages are condensed too:\neach holds as many as a plain cabbage."},
	{id = "condense_gold", parent = "condense_research", at = Vector2(4.00, 1.40), icon = "crate", price = 250000,
		title = "CONDENSED BULLION",
		body = "Gold is compressed. It does not complain.\nGolden cabbages are condensed too: each takes\nthat many from your golden stock."},
	{id = "condense_2", parent = "condense_research", at = Vector2(4.30, 0.85), icon = "crate", price = 600000,
		add = {condense = 1}, title = "CONDENSE II",
		body = "Three cabbages agree to share.\nA condensed cabbage holds 3 cabbages, not 2:\nit takes 3 from stock and counts as 3."},
	{id = "condense_3", parent = "condense_2", at = Vector2(5.00, 0.85), icon = "crate", price = 3500000,
		add = {condense = 1}, title = "CONDENSE III",
		body = "The cabbage is now mostly cabbage.\nA condensed cabbage holds 4 cabbages, not 3:\nit takes 4 from stock and counts as 4."},
	# The desk's answer to the farm's SEED BEDS (CH2, desk card structured_farm): the chute and the mat
	# pass no more cabbages a minute (20 slots, CONVEYOR III), so what follows a bigger harvest is what
	# each one holds. Paced in tools/pace.py (`ch3`, `flow`).
	{id = "condense_4", parent = "condense_3", at = Vector2(5.70, 0.85), icon = "crate", price = 5000000,
		add = {condense = 2}, title = "CONDENSE IV",
		body = "Six to a cabbage. Nobody asked the cabbages.\nA condensed cabbage holds 6 cabbages, not 4:\nit takes 6 from stock and counts as 6."},
	{id = "condense_5", parent = "condense_4", at = Vector2(6.40, 0.85), icon = "crate", price = 10000000,
		add = {condense = 2}, title = "CONDENSE V",
		body = "It is heavier than it looks. So is the paperwork.\nA condensed cabbage holds 8 cabbages, not 6:\nit takes 8 from stock and counts as 8."},
	# TREASURY: the most coins the save holds (save.coin_limit, SaveGame.earn), $200,000 from the desk
	# card cash_holding (stamped before big_ideas), up to $16M. Each step costs less than the limit
	# before it and at least doubles it, so the ladder stays ahead of what chapter 3 charges (the farms
	# to $5M, BRIBERY $2.5M, NO MORE TAXES $10M). Paced in tools/pace.py (`ch3`). By hand, in the gap
	# between SUPPLY CHAIN and COIN UNITS, up into the free top-left corner. The first step needs the
	# card too, so its x5 always comes before a step's sum.
	{id = "coin_limit_1", parent = "dept_automation", at = Vector2(-2.60, -0.85), icon = "crate", price = 45000,
		needs = ["cash_holding", "big_ideas"], add = {coin_limit = 300000}, title = "PETTY CASH TIN",
		body = "The tin is larger than the petty cash.\nYou can hold up to $500,000 instead of $200,000."},
	{id = "coin_limit_2", parent = "coin_limit_1", at = Vector2(-3.05, -1.25), icon = "crate", price = 100000,
		add = {coin_limit = 1000000}, title = "WALL SAFE",
		body = "Behind the founder's portrait. Everyone knows.\nYou can hold up to $1.5M instead of $500,000."},
	{id = "coin_limit_3", parent = "coin_limit_2", at = Vector2(-3.05, -1.68), icon = "crate", price = 300000,
		add = {coin_limit = 2500000}, title = "STRONGROOM",
		body = "The door weighs more than the staff.\nYou can hold up to $4M instead of $1.5M."},
	{id = "coin_limit_4", parent = "coin_limit_3", at = Vector2(-3.05, -2.11), icon = "crate", price = 800000,
		add = {coin_limit = 4000000}, title = "BASEMENT VAULT",
		body = "Two keys are required. You hold both.\nYou can hold up to $8M instead of $4M."},
	{id = "coin_limit_5", parent = "coin_limit_4", at = Vector2(-3.05, -2.54), icon = "crate", price = 2000000,
		add = {coin_limit = 8000000}, title = "CENTRAL RESERVE",
		body = "The desk is now a bank. The banks were not asked.\nYou can hold up to $16M instead of $8M."},
]
## Each theme's heading on the slide, part of its branch: the edges from its first nodes' (the roots,
## the last entry) parent run through it to them (UpgradeTree), so it names the branch as it opens
## (same units as a node's `at`; spots by tools/_theme_place.gd, on the branch line, clear of every
## node, edge and other heading in English and German). Last, its category's description for the
## heading's hover popup (UpgradeTree: a flavour line, then what the branch improves).
const THEMES := [
	["PROCUREMENT", Vector2(1.34, -0.07), ["pack_1"],
		"Volume is policy.\nBigger packs from the supply console, and cheaper ones."],
	["STORAGE", Vector2(1.44, -0.31), ["stock_25"],
		"Every cupboard is a warehouse in waiting.\nHow many cabbages storage holds, and what golden cabbages earn at the window and in the lab."],
	["DESK SPACE", Vector2(1.55, -0.79), ["mat_4"],
		"The mat is leased by the cabbage.\nOne more cabbage fits on the mat per step, later three, up to 20."],
	["SALES EVENTS", Vector2(1.25, 0.46), ["combo_window", "target_size", "bin_mouth"],
		"Incidents at the window, monetised.\nThe catch combo, the lit crates in the street and what the bin pays for rot."],
	["MANAGEMENT", Vector2(0.90, 0.46), ["manager_time"],
		"The manager's visits, made survivable.\nLonger and lower quotas, bigger bonuses, and more for cabbages you sell yourself."],
	["CONSULTANCY", Vector2(-0.69, -0.68), ["consultant_speed_1"],
		"Pricing, outsourced and billed by the tap.\nHow fast the consultant works the slate, and how far ahead it reads the street."],
	["SUPPLY CHAIN", Vector2(-0.86, -0.33), ["auto_reserve_1", "conveyor_1"],
		"Logistics nobody has to think about.\nWhen and at what price auto-buy orders, and how fast the chute rolls out cabbages."],
	["COIN UNITS", Vector2(-1.06, 0.03), ["vacuum_speed_1"],
		"Coins are collected, not picked up.\nMore coin robots, faster, with bigger bags, wider nozzles and shorter charging."],
	["ASSOCIATES", Vector2(-1.11, 0.25), ["associate_1"],
		"Productivity, measured in footsteps.\nHired hands and lab hands walk faster and set off more often."],
	["HEADCOUNT", Vector2(-0.71, 0.38), ["hands_bin", "hire_associate_2"],
		"Staffing is a number, and it goes up.\nMore hired hands at the window, and a protocol for the bin."],
	["MINI CABBAGES", Vector2(0.90, -0.38), ["mini_rate_1"],
		"Smaller cabbages, same paperwork.\nMinis drop more often, sell for more and grow into full cabbages in the growing station."],
	["RESEARCH", Vector2(-0.16, 1.05), ["research_mult_1"],
		"The blue ones are special. It says so here.\nMore blue research cabbages off the chute, and more Findings from each."],
	["LAB HANDS", Vector2(0.32, 1.52), ["lab_hand_2"],
		"The lab is staffed, eventually.\nMore lab hands throwing cabbages into the research lab."],
	["HANDLING", Vector2(0.40, 1.12), ["schedule_research"],
		"Who touches what, in writing.\nWhich cabbage kinds the handling schedule can withhold from lab hands or hired hands."],
	["CONDENSATION", Vector2(2.75, 0.59), ["condense_research"],
		"Less air, more cabbage.\nWhich cabbages come down the chute condensed, and how many cabbages each one holds."],
]
## The screen's rect as fractions of the view: centred, 70% wide, unrolled down to 88% of the height;
## SCREEN_WIDE once the desk card BIG_IDEAS is stamped (screen_for): nearly the whole view, the
## overlay's rim left to click it away. The first time it comes down after the stamp it unrolls
## as before, then widens over WIDEN_TIME (save.projector_wide: shown once). On the wide sheet the
## tree can be zoomed out as far as ZOOM_WIDE (UpgradeTree.zoom_min), where the whole wheel with the
## outer ring fits; it does not zoom out by itself.
const SCREEN := Rect2(0.15, 0.0, 0.7, 0.88)
const SCREEN_WIDE := Rect2(0.03, 0.0, 0.94, 0.95)
const BIG_IDEAS := "big_ideas"
const WIDEN_TIME := 0.9
const WIDEN_PAUSE := 0.35
const ZOOM_WIDE := 0.22
## Pulled this far (of the whole drop) from where it rested, the screen goes the rest of the way itself.
const LET_GO := 0.3
## A press on the pull that moves less than this (px) is a click: it rolls the screen down.
const CLICK_PX := 8.0
const ROLLER_H := 26.0
const BAR_H := 12.0
## The close button in the open sheet's top-right corner (px).
const CLOSE := 40.0
## Where the cord is tied along the bottom bar (0 left .. 1 right): a little right of the middle.
const TAB_AT := 0.6
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
const SHADE := Color(0.07, 0.08, 0.08, 0.62)
## The PULL word on the pennant: its font size and the most it may be wide (m), shrunk to fit.
const PULL_SIZE := 64
const PULL_PIXEL := 0.0006
const PULL_WIDTH := 0.08

@export var roll_down_sound: AudioStream
@export var roll_up_sound: AudioStream
@export var approve_sound: AudioStream
@export var denied_sound: AudioStream
## The wide sheet running out to both sides (WIDEN_TIME; its stop lands on the overshoot).
@export var widen_sound: AudioStream
## The projector's hot spot: a soft cold wash, fading out toward the screen's edges.
@export var beam: GradientTexture2D

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
var _close_hot := false
## The pull's slide down from above when the projector first turns up (px of offset).
var _arrive := 0.0
## The bottom bar's sideways lag behind the swinging pull while it rolls (px).
var _sway := 0.0
## How far the sheet has grown from SCREEN (0) to SCREEN_WIDE (1), see screen_for.
var _wide := 0.0
## The dimming behind the open sheet, and the player for its sounds.
@onready var _overlay: ColorRect = $Overlay
@onready var _sfx: AudioStreamPlayer = $Sfx
## The tree, clipped to the slide below the heading, lit with the lamp.
@onready var _tree: UpgradeTree = $Tree
## The sheet was down at the last redraw (rolled up, _draw is empty and needs no redraw).
var _sheet_drawn := true
## Node prices sorted, to count the affordable ones cheaply (they change the drawing).
static var _prices := PackedInt32Array()
## The pull in the 3D world: its body, the tipping tab, the cord, its handle and material. A grey
## enamel pennant, a downward-pointing triangle stamped PULL, hanging by its top edge from a steel
## eyelet on a dark cord. Its face is tipped back toward the camera so the word reads from above.
## Hovered it glows faintly and lifts; the hand pinches its tip (Interactable reach + carried).
@onready var _grip: StaticBody3D = $Grip
@onready var _tab: Node3D = $Grip/Tab
@onready var _cord: MeshInstance3D = $Cord
@onready var _handle: Interactable = $Grip/Handle
@onready var _enamel: StandardMaterial3D = ($Grip/Tab/Pennant.mesh as PrimitiveMesh).material
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
@onready var _count: Label3D = $Grip/Tab/Badge/Count
## The dark plate riveted under the tip that carries the count; hidden while nothing is buyable.
@onready var _badge: Node3D = $Grip/Tab/Badge
var _step_left := 0.0
## While dragged, the tab keeps this offset from the mouse's point under it (no lag, no jump).
var _grab_offset := Vector3.ZERO
## The tab on screen (px) and its reach there, for the click-through.
var _grip_px := Vector2(-1000.0, -1000.0)
var _grip_r := 40.0


func _ready() -> void:
	# Before the Hand autoload, so the hand sits on where the tab is this frame, not the last.
	process_priority = -1
	_tree.rules = Projector
	_tree.bought.connect(_approved)
	_tree.denied.connect(_play.bind(denied_sound))
	_handle.hovered.connect(_touch_tab.bind(true))
	_handle.unhovered.connect(_touch_tab.bind(false))
	_handle.grabbed.connect(_grab)
	_handle.released.connect(_let_go)
	visible = false
	_wide = 1.0 if SaveManager.save.projector_wide else 0.0
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
	_tree.light = _lamp
	_tree.zoom_min = lerpf(UpgradeTree.ZOOM_MIN, ZOOM_WIDE, clampf(_wide, 0.0, 1.0))
	# Rolled up, _draw draws nothing: one last redraw clears the sheet, then none.
	if _drop > 0.0 or _sheet_drawn:
		queue_redraw()
	_sheet_drawn = _drop > 0.0


## The pull: while dragged it sits under the mouse; otherwise it swings on its cord, in fixed STEPs.
## Shown only while the screen is not fully down (open, the overlay, X and Esc close it), and not
## while the camera is at the farm TV.
func _move_pull(delta: float) -> void:
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


## A node bought on the tree (a hold): logged, and the approval sound.
func _approved(id: String, paid: int) -> void:
	SaveManager.log_event("node", id, paid, "coins")
	_play(approve_sound)


## Besides zoom and size, what changes the tree's drawing (UpgradeTree): cards, nodes bought, the mat,
## and how many upgrades the coins cover.
static func drawn_key(save: SaveGame) -> Array:
	return [save.stamped.size(), save.tree_bought.size(), save.desk_capacity, affordable(save.coins)]


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


## Shown on the tree: its feature is unlocked, i.e. every desk card it and its ancestors need is
## stamped. A node the save has bought always shows (a late node bought before it moved behind
## BIG_IDEAS: it keeps its effect and its place, and the run past it stays buyable).
static func is_shown(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	if node.is_empty():
		return false
	return save.tree_bought.has(id) or (node.get("needs", []).all(func(card: String) -> bool: return save.stamped.has(card)) \
			and (node.parent == "" or is_shown(node.parent, save)))


## Whether the save has the wide sheet: the desk card BIG_IDEAS is stamped.
static func wide(save: SaveGame) -> bool:
	return save.stamped.has(BIG_IDEAS)


## The screen's rect (fractions of the view) `widened` of the way from SCREEN (0) to SCREEN_WIDE (1).
static func screen_for(widened: float) -> Rect2:
	return Rect2(SCREEN.position.lerp(SCREEN_WIDE.position, widened), SCREEN.size.lerp(SCREEN_WIDE.size, widened))


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


## Which THEMES have a heading showing: one shows with the first of its first nodes (its roots).
static func themes_shown(save: SaveGame) -> Array[bool]:
	var out: Array[bool] = []
	for heading: Array in THEMES:
		out.append(heading[2].any(func(id: String) -> bool: return is_shown(id, save)))
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


## What node `id` still waits for although reachable: "demo" if the demo locks it (dearer than
## Demo.NODE_PRICE_CAP), its `research` or `lock` desk card not stamped yet, its `after` node not
## bought yet, or "" (none, all in, or the node already bought).
static func locked_by(id: String, save: SaveGame) -> String:
	if save.tree_bought.has(id):
		return ""
	if Events.Demo.active() and price_of(id, save) > Events.Demo.NODE_PRICE_CAP:
		return "demo"
	var node := node_data(id)
	for card: String in [node.get("research", ""), node.get("lock", "")]:
		if card != "" and not save.stamped.has(card):
			return card
	var after: String = node.get("after", "")
	return after if after != "" and not save.tree_bought.has(after) else ""


static func is_bought(id: String, save: SaveGame) -> bool:
	return save.tree_bought.has(id)


static func price_of(id: String, _save: SaveGame) -> int:
	return node_data(id).get("price", 0)


## The storage a save holds with storage node `id` bought (and so the whole chain up to it).
static func cap_at(id: String) -> int:
	var node := node_data(id)
	if not node.get("add", {}).has("storage_cap"):
		return SaveGame.new().storage_cap
	return cap_at(node.parent) + node.add.storage_cap


## An old save's storage: container orders bought before storage had a cap count the stock room as
## bought; every step before a bought one counts as bought (the chain was 6 nodes before the steps
## between them), and the cap is the chain's (cap_at), so storage_1..6 keep 75 ... 9,999. Safe to rerun.
## A step dropped from the chain (DROPPED_STORAGE) becomes the next kept step above it: rounding up
## never takes room away, and the cap stays the chain's.
static func migrate_storage(save: SaveGame) -> void:
	if save.tree_bought.has("pack_2") and not save.tree_bought.has("storage_1"):
		save.tree_bought.append("storage_1")
	for dropped: String in DROPPED_STORAGE:
		var at := save.tree_bought.find(dropped)
		if at >= 0:
			save.tree_bought.remove_at(at)
			if not save.tree_bought.has(DROPPED_STORAGE[dropped]):
				save.tree_bought.append(DROPPED_STORAGE[dropped])
	var top := ""
	for node: Dictionary in NODES:  # In chain order: the last bought one is the top.
		if node.get("add", {}).has("storage_cap") and save.tree_bought.has(node.id):
			top = node.id
	if top == "":
		return
	save.storage_cap = cap_at(top)
	var step := top
	while node_data(step).get("add", {}).has("storage_cap"):
		if not save.tree_bought.has(step):
			save.tree_bought.append(step)
		step = node_data(step).parent


## An old save's coin units: the bag steps now on the path to its bought robot nodes (the second
## unit once hung straight off the firmware update) count as bought, with their coins per trip, so
## the branch reads as bought from the root. Never takes anything away; safe to rerun.
static func migrate_vacuums(save: SaveGame) -> void:
	for id: String in save.tree_bought.duplicate():
		if not id.begins_with("vacuum_") or node_data(id).is_empty():
			continue
		var step: String = node_data(id).parent
		while step.begins_with("vacuum_") and not save.tree_bought.has(step):
			save.tree_bought.append(step)
			apply(step, save)
			step = node_data(step).parent


## An old save's mat: with the allowance card stamped it holds at least 3 (the card's free unit), and
## each chain step its capacity reaches counts as bought. A save between two steps (it bought the
## single units 12, 13, 15... the three-unit steps replaced) keeps every unit and pays the next step
## in full for the rest. Never takes a unit away; safe to rerun.
static func migrate_mat(save: SaveGame) -> void:
	if save.stamped.has("mat_allowance"):
		save.desk_capacity = maxi(save.desk_capacity, MAT_FIRST - 1)
	for node: Dictionary in NODES:
		if node.id.begins_with("mat_") and node.id.trim_prefix("mat_").to_int() <= save.desk_capacity \
				and not save.tree_bought.has(node.id):
			save.tree_bought.append(node.id)


## Reachable, not bought and not waiting for research: a hold on it buys it (if the coins are there).
## Departments are never bought.
static func can_hold(id: String, save: SaveGame) -> bool:
	return not is_dept(id) and is_reachable(id, save) and not is_bought(id, save) and locked_by(id, save) == ""


static func can_buy(id: String, save: SaveGame) -> bool:
	return can_hold(id, save) and save.coins >= price_of(id, save)


## What node `id` waits for, as [heading, name] for its popup, or [] if nothing: its parent, then a
## desk card it needs (hidden till then, so never seen), then its research or lock card (a form:
## UpgradeTree.form_lock, a third entry). Under a closed department: what the department waits for.
static func requirement(id: String, save: SaveGame) -> Array:
	var node := node_data(id)
	if node.parent != "" and not is_open(node.parent, save):
		return requirement(node.parent, save) if is_dept(node.parent) else ["REQUIRES:", node_data(node.parent).title]
	for card: String in node.get("needs", []):
		if not save.stamped.has(card):
			return ["REQUIRES DESK CARD:", UpgradeDesk.card_data(card).get("title", card)]
	var lock := locked_by(id, save)
	if lock == "demo":
		return ["FULL GAME ONLY:", "Wishlist it on Steam"]
	if lock == "":
		return []
	if lock == node.get("after", ""):
		return ["REQUIRES:", node_data(lock).title]
	return UpgradeTree.form_lock(lock, save)  # Its `research` or `lock` card: a form to approve.


## Pays for node `id` and applies it; false (and nothing changes) if it can't be bought.
static func buy(id: String, save: SaveGame) -> bool:
	if not can_buy(id, save):
		return false
	save.coins -= price_of(id, save)
	save.tree_bought.append(id)
	apply(id, save)
	return true


## What node `id` does to the save.
static func apply(id: String, save: SaveGame) -> void:
	if id.begins_with("mat_"):
		# Its +1 lands the mat on its own unit, never under what an old save's mat already holds.
		save.desk_capacity = maxi(save.desk_capacity, id.trim_prefix("mat_").to_int())
		return
	var node := node_data(id)
	UpgradeTree.apply_effect(node, save)
	if node.get("hire", false):
		Associate.add_hand(save)


## What the merged chains' nodes did before the merge (save.migration 2): per chain, each old id's
## effect. Removed ids stay in an old save's tree_bought (nothing reads them) with their numbers.
const MERGED := [
	{desk_1 = {add = {desk_capacity = 2}}, desk_2 = {add = {desk_capacity = 2}}, desk_3 = {add = {desk_capacity = 2}},
		desk_4 = {add = {desk_capacity = 2}}, desk_5 = {add = {desk_capacity = 2}}, desk_6 = {add = {desk_capacity = 2}}},
	{pack_2 = {add = {pack_size = 5}}, pack_3 = {add = {pack_size = 10}}, pack_4 = {add = {pack_size = 25}}},
	# Measured against today's discount_1, which holds the whole branch (so MERGED_PACKS is skipped after it).
	{discount_1 = {mul = {pack_discount = 0.85}}, discount_2 = {mul = {pack_discount = 0.85}}, discount_3 = {mul = {pack_discount = 0.8}}},
	{vacuum_2 = {add = {vacuums = 1}}, vacuum_bag_1 = {add = {vacuum_capacity = 12}}, vacuum_suction = {mul = {vacuum_reach = 1.5}},
		vacuum_speed_2 = {mul = {vacuum_speed = 1.5}}, vacuum_bag_2 = {add = {vacuum_capacity = 30}}, vacuum_3 = {add = {vacuums = 1}}},
	{auto_reserve_2 = {add = {auto_reserve = 15}}, auto_smart_2 = {add = {auto_max_factor = -0.2}}},
	{associate_3 = {mul = {associate_speed = 1.5}}, associate_4 = {mul = {associate_speed = 1.3}}, associate_5 = {mul = {associate_speed = 1.3}}},
]
## The slimmed pack branch (save.migration 3): the two discounts merged into discount_1. The dropped
## auto_reserve_2 needs no entry: what it gave is simply kept.
const MERGED_PACKS := [
	{discount_1 = {mul = {pack_discount = 0.85}}, discount_2 = {mul = {pack_discount = 0.68}}},
]


## An old save's merged chains: where the nodes it kept now do more than what it got from the old
## ones it bought (an old Hot-Desking alone: +2, now +4), the difference is added. Never takes away.
static func migrate_merged(save: SaveGame, chains: Array = MERGED) -> void:
	for chain: Dictionary in chains:
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
	# The slide's own clicks, drags and wheel go to the tree (UpgradeTree), drawn over this.
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and _open() and (_close_rect().has_point(button.position) or not _fabric_rect().has_point(button.position)):
			_settle(false)  # The X, or a click on the overlay.
		accept_event()
	elif event is InputEventMouseMotion:
		_close_hot = _lamp > 0.9 and _close_rect().has_point((event as InputEventMouseMotion).position)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if _close_hot else CURSOR_ARROW


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
		_close_hot = false


## Turns up: the pull (dropping in from above when `arrive`).
func _show(arrive: bool) -> void:
	visible = true
	if arrive:
		_arrive = -80.0
		create_tween().tween_property(self, "_arrive", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	($Grip/Tab/Word as Label3D).font_size = pull_size(TranslationServer.translate("PULL"))


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
		if wide(SaveManager.save) and _wide < 1.0:
			# The wide sheet's first showing: lit as it was, then the roller runs out to both sides and
			# the fabric with it, past its width and back.
			_settling.tween_interval(WIDEN_PAUSE)
			_settling.tween_callback(_play.bind(widen_sound))
			_settling.tween_property(self, "_wide", 1.0, WIDEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_settling.tween_callback(func() -> void: SaveManager.save.projector_wide = true)
	else:
		_lamp_off()
		_play(roll_up_sound)
		_settling.tween_property(self, "_drop", 0.0, 0.3 * _drop + 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _lamp_off() -> void:
	# Rolled up: what was marked NEW has been seen.
	SaveManager.save.tree_seen.append_array(_tree.close())
	_lamp = 0.0
	_close_hot = false


func _play(stream: AudioStream) -> void:
	if stream != null:
		_sfx.stream = stream
		_sfx.play()


# --- Layout ---

func _screen_rect() -> Rect2:
	var screen := screen_for(_wide)
	return Rect2(size * screen.position, size * screen.size)


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
	var light := _lamp * UpgradeTree.pulse(Time.get_ticks_msec() / 1000.0)
	# The beam: a cold, uneven wash brightest in the middle.
	draw_texture_rect(beam, fabric, false, Color(1, 1, 1, light))
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


## The PULL word's font size: PULL_SIZE, shrunk until `shown` is at most PULL_WIDTH wide on the pennant.
static func pull_size(shown: String) -> int:
	var font_size := PULL_SIZE
	while font_size > 24 and FONT.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * PULL_PIXEL > PULL_WIDTH:
		font_size -= 2
	return font_size
