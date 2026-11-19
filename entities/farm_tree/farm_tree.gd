class_name FarmTree
extends Control
## CH2 on the farm TV (entities/farm_tv/): the farm's own upgrade tree, the projector's tree view
## (UpgradeTree) in the CRT's green phosphor, its layout and palette in farm_tree.tscn. Until desk
## card `farm_terminal` is stamped the channel shows SUBSCRIPTION PENDING instead. Bought ids go into
## save.farm_bought. Every node is paid in Findings (¶): coins stay for the projector (stage 2's coin
## sinks were walling the projector's mat and storage chains). Hand nodes wait for card seasonal_workforce, tractor nodes for
## mechanisation (the desk cards that bring the first of each). The farm's old one-off upgrades keep
## their ids (seed_contract, fertiliser, irrigation, greenhouse): FarmScreen reads them from farm_bought.
## STRUCTURED FARM (desk card WIDE_CARD, as the projector's BIG MINDS): the view opens up (it settles
## zoomed out to ZOOM_WIDE, the first time shown easing out over WIDEN_TIME with the projector's
## widening sound, save.farm_tree_wide) and the outer ring shows: the nodes that name the card in
## `needs` and their runs (SEED BEDS, the farm hands' farm rounds and satchels, and the late steps
## moved behind it: FARM OUTPUT from x20, ARCHIVE from the third). A node a save has bought always shows.

const CARD := "farm_terminal"
const WIDE_CARD := "structured_farm"
## The opened-up view: the zoom it settles at (and returns to), how far out it zooms, the opening's seconds.
const ZOOM_WIDE := 0.6
## Chapter 4's NUCLEAR runs reach further out: from desk card NUCLEAR_CARD the view settles here.
const ZOOM_NUCLEAR := 0.30
const NUCLEAR_CARD := "nuclear_research"
const ZOOM_MIN_WIDE := 0.2
const WIDEN_TIME := 0.9
## Every node (UpgradeTree's format: parent, at, icon, price, currency, add/mul on save numbers,
## needs). ponytail: prices are placeholders, unpaced (the old coin prices / ~12, the sim's $ per ¶
## at 70-90 min); set them with tools/pace.py once CH1's workers are in.
const NODES := [
	{id = "hand_2", parent = "", at = Vector2(-0.6, -0.42), icon = "hand", price = 400, currency = "findings",
		needs = ["seasonal_workforce"], add = {farm_hands = 1}, title = "SECOND FARM HAND",
		body = "Seasonal contract. The season is permanent.\nOne more farm hand plants empty squares: 1 to 2 hands."},
	{id = "hand_speed", parent = "hand_2", at = Vector2(-1.05, -0.72), icon = "clock", price = 600, currency = "findings",
		mul = {farm_hand_speed = 1.5}, title = "WORK BOOTS",
		body = "Boots are issued. Laces are extra.\nFarm hands walk 50% faster."},
	{id = "hand_3", parent = "hand_speed", at = Vector2(-1.5, -1.02), icon = "hand", price = 1200, currency = "findings",
		add = {farm_hands = 1}, title = "THIRD FARM HAND",
		body = "The bunkhouse is at capacity.\nOne more farm hand plants empty squares: 2 to 3 hands."},
	# The fourth and fifth hand (and tractor, below): the outer ring (structured_farm), a hut each in
	# the yard (FarmScreen.SLOTS). ¶30,000 / ¶80,000, tractors ¶40,000 / ¶100,000 (tools/pace.py ch3:
	# 2-3.5 min of ¶ each, bought at ~70 / ~92 min and ~80 / ~96 min, each lifting its rate x1.22-1.32).
	{id = "hand_4", parent = "hand_3", at = Vector2(-1.95, -1.32), icon = "hand", price = 30000, currency = "findings",
		needs = ["structured_farm"], add = {farm_hands = 1}, title = "FOURTH FARM HAND",
		body = "A second bunkhouse has been requisitioned. It was the first one's shed.\nOne more farm hand plants empty squares: 3 to 4 hands."},
	{id = "hand_5", parent = "hand_4", at = Vector2(-2.4, -1.62), icon = "hand", price = 80000, currency = "findings",
		add = {farm_hands = 1}, title = "FIFTH FARM HAND",
		body = "Headcount is now a line item.\nOne more farm hand plants empty squares: 4 to 5 hands."},
	{id = "hand_route", parent = "hand_2", at = Vector2(-1.1, -0.2), icon = "lens", price = 150,
		currency = "findings", add = {farm_hand_route = 1}, title = "PLANTING ROSTER",
		body = "A roster is pinned to the barn door.\nFarm hands walk straight to an empty square instead of wandering the field."},
	# ESTATE PERMIT / LICENCE (FarmScreen.PLANT_PERMIT / HARVEST_LICENCE, can_work): until bought the
	# workers leave farm squares to the player. Shown with the first farm (no free permits for old
	# saves); ¶2,500 each (tools/pace.py ch3: ~3.5 min of ¶ at the first farm's ~700 a minute, both
	# bought from savings within a minute of it; the licence lifts ¶/min ×1.6).
	{id = "estate_permit", parent = "hand_route", at = Vector2(-1.6, -0.45), icon = "lens", price = 2500,
		currency = "findings", needs_farm = true, title = "ESTATE PLANTING PERMIT",
		body = "Estate soil may now be touched by staff, in triplicate.\nFarm hands plant farm squares too. Until then you plant them yourself."},
	{id = "hand_shift", parent = "hand_2", at = Vector2(-0.55, -0.95), icon = "clock", price = 700, currency = "findings",
		add = {farm_hand_shift = 1}, title = "MANDATORY OVERTIME",
		body = "Overtime is voluntary. Volunteering is mandatory.
Farm hands carry one more seed per trip and plant one more square before returning to the yard."},
	{id = "tractor_2", parent = "", at = Vector2(0.6, -0.42), icon = "tractor", price = 1000, currency = "findings",
		needs = ["mechanisation"], add = {farm_tractors = 1}, title = "SECOND TRACTOR",
		body = "Leased. Never owned.\nOne more tractor harvests ripe squares: 1 to 2 tractors."},
	{id = "tractor_speed", parent = "tractor_2", at = Vector2(1.05, -0.72), icon = "clock", price = 1200, currency = "findings",
		mul = {farm_tractor_speed = 1.5}, title = "GOVERNOR REMOVED",
		body = "The speed governor is now optional.\nTractors drive 50% faster."},
	{id = "tractor_3", parent = "tractor_speed", at = Vector2(1.5, -1.02), icon = "tractor", price = 2500, currency = "findings",
		add = {farm_tractors = 1}, title = "THIRD TRACTOR",
		body = "Three tractors. One gate.\nOne more tractor harvests ripe squares: 2 to 3 tractors."},
	{id = "tractor_4", parent = "tractor_3", at = Vector2(1.95, -1.32), icon = "tractor", price = 40000, currency = "findings",
		needs = ["structured_farm"], add = {farm_tractors = 1}, title = "FOURTH TRACTOR",
		body = "The lease now includes a fleet clause.\nOne more tractor harvests ripe squares: 3 to 4 tractors."},
	{id = "tractor_5", parent = "tractor_4", at = Vector2(2.4, -1.62), icon = "tractor", price = 100000, currency = "findings",
		add = {farm_tractors = 1}, title = "FIFTH TRACTOR",
		body = "A second gate was proposed. A fifth tractor was approved.\nOne more tractor harvests ripe squares: 4 to 5 tractors."},
	{id = "tractor_route", parent = "tractor_2", at = Vector2(1.1, -0.2), icon = "lens", price = 250,
		currency = "findings", add = {farm_tractor_route = 1}, title = "HARVEST DISPATCH",
		body = "Ripeness is now reported centrally.\nTractors drive straight to a ripe square instead of cruising the field."},
	{id = "estate_licence", parent = "tractor_route", at = Vector2(1.6, -0.45), icon = "lens", price = 2500,
		currency = "findings", needs_farm = true, title = "ESTATE HARVEST LICENCE",
		body = "Leased machinery may now enter leased land.\nTractors harvest farm squares too. Until then you pull them yourself."},
	{id = "tractor_shift", parent = "tractor_2", at = Vector2(0.55, -0.95), icon = "clock", price = 1600, currency = "findings",
		add = {farm_tractor_shift = 1}, title = "DOUBLE SHIFT",
		body = "The night shift is the day shift, continued.
Tractors harvest one more ripe square before returning to the yard."},
	# The old one-off farm upgrades, same ids: FarmScreen reads them from farm_bought.
	{id = "fertiliser", parent = "", at = Vector2(-0.6, 0.48), icon = "sprout", price = 250, currency = "findings",
		title = "FERTILISER",
		body = "Its contents are not disclosed.\nSquares ripen in 20 s instead of 30 s."},
	{id = "greenhouse", parent = "fertiliser", at = Vector2(-1.05, 0.82), icon = "sprout", price = 2500, currency = "findings",
		title = "GREENHOUSE",
		body = "Weather is no longer a factor. Nor is daylight.\nSquares ripen in 15 s."},
	{id = "irrigation", parent = "fertiliser", at = Vector2(-1.1, 0.3), icon = "lens", price = 300,
		currency = "findings", title = "IRRIGATION",
		body = "The water is metered by the drop.\nEvery harvest gives 1 more cabbage."},
	{id = "seed_contract", parent = "", at = Vector2(0.6, 0.48), icon = "crate", price = 200, currency = "findings",
		title = "SEED CONTRACT",
		body = "A supplier has been found. Do not ask which.\nSeed packs cost half."},
	# STANDING SEED ORDER (desk card standing_seed_order, FarmScreen.auto_seed): when it reorders and what.
	# Comfort, no gain (the order buys at once anyway, the 50 pack saves 12% on seeds): priced as pocket
	# change, right after the card (tools/pace.py: under 20 s and ~3 min after it).
	{id = "seed_reserve", parent = "seed_contract", at = Vector2(1.1, 0.3), icon = "clock", price = 200, currency = "findings",
		needs = ["standing_seed_order"], add = {farm_seed_reserve = 15}, title = "SAFETY SEED STOCK",
		body = "Running out is a planning failure. Planning has been increased.
The standing seed order buys when the crate is down to 20 seeds, not 5."},
	{id = "seed_bulk", parent = "seed_reserve", at = Vector2(1.05, 0.82), icon = "crate", price = 500, currency = "findings",
		add = {farm_seed_pack = 1}, title = "BULK SEED CONTRACT",
		body = "The supplier prefers fewer, larger invoices.
The standing seed order buys the 50-seed pack instead of the 10."},
	# GREEN THUMB (desk card green_thumb): the hand harvest's multiplier and replanting (FarmScreen.harvest).
	{id = "thumb_yield", parent = "", at = Vector2(0.0, -1.0), icon = "hand", price = 600, currency = "findings",
		needs = ["green_thumb"], add = {hand_yield = 1.0}, title = "EMPLOYEE OF THE MONTH",
		body = "Your photograph is on the barn wall.\nA square you pull by hand yields 3× instead of 2×."},
	{id = "thumb_replant", parent = "thumb_yield", at = Vector2(0.0, -1.45), icon = "sprout", price = 900, currency = "findings",
		add = {hand_replant = 1}, title = "ONE IN, ONE OUT",
		body = "The hole is never left empty. It is policy.\nA square you pull out yourself is replanted at once from the crate. A farm square only when you pull its last batch. Tractor harvests still wait for a farm hand."},
	# ONE IN, ONE OUT on farm squares (FarmScreen.FARM_REPLANT, harvest): without it only the pull that
	# empties a farm square puts a seed back; with it every hand pull does (the square stays full).
	# ¶3,000 (tools/pace.py ch3: bought at ~21 min, ~5.5 min after the first farm and 73 s after the
	# previous buy, from savings).
	{id = "farm_replant", parent = "thumb_replant", at = Vector2(0.0, -1.9), icon = "sprout", price = 3000, currency = "findings",
		needs_farm = true, title = "ESTATE ROTATION POLICY",
		body = "The policy has been extended to every batch. The batches were not consulted.\nEvery farm batch you pull by hand puts one seed back from the crate, not just the last."},
	# GREEN THUMB on farm squares (save.farm_hand_share, FarmScreen.hand_factor): a farm square pulled by
	# hand gets none of GREEN THUMB's bonus until this chain, then 25%, 50%, all of it. Shown once a
	# farm is owned; the last two wait for EXTEND THE ARCHIVE (they pass ¶8,000). ¶4,000 / ¶12,000 / ¶30,000 (tools/pace.py ch3: about 2-4k ¶ a minute at farms 1-2).
	{id = "farm_hand_1", parent = "thumb_yield", at = Vector2(0.5, -1.42), icon = "hand", price = 4000, currency = "findings",
		needs_farm = true, add = {farm_hand_share = 0.25}, title = "REGIONAL RECOGNITION",
		body = "Your photograph has been forwarded to the estates.\nA farm square you pull by hand gets 25% of GREEN THUMB's bonus, not none."},
	{id = "farm_hand_2", parent = "farm_hand_1", at = Vector2(0.5, -1.87), icon = "hand", price = 12000, currency = "findings",
		needs = ["archive_capacity"], add = {farm_hand_share = 0.25}, title = "ESTATE WALKABOUT",
		body = "You are seen in the fields. The fields are informed in advance.\nA farm square you pull by hand gets 50% of GREEN THUMB's bonus, not 25%."},
	{id = "farm_hand_3", parent = "farm_hand_2", at = Vector2(0.95, -1.65), icon = "hand", price = 30000, currency = "findings",
		needs = ["archive_capacity"], add = {farm_hand_share = 0.5}, title = "FULL ENDORSEMENT",
		body = "Head office has signed your thumb.\nA farm square you pull by hand gets all of GREEN THUMB's bonus, not 50%."},
	# Golden squares (desk card golden_cabbage): how often one grows golden (save.golden_chance). What a
	# golden unit pays is the projector's (coins), not this tree's.
	{id = "gold_chance_1", parent = "", at = Vector2(0.0, 0.95), icon = "sprout", price = 1500, currency = "findings",
		needs = ["golden_cabbage"], add = {golden_chance = 0.015}, title = "SELECTIVE BREEDING",
		body = "Only the promising seeds are spoken to.\n1 square in 25 grows golden, not 1 in 40."},
	{id = "gold_chance_2", parent = "gold_chance_1", at = Vector2(0.0, 1.4), icon = "sprout", price = 4000, currency = "findings",
		add = {golden_chance = 0.0267}, title = "PEDIGREE SEED STOCK",
		body = "The seeds now have papers.\n1 square in 15 grows golden, not 1 in 25."},
	{id = "gold_chance_3", parent = "gold_chance_2", at = Vector2(0.0, 1.85), icon = "sprout", price = 9000, currency = "findings",
		needs = ["archive_capacity"], add = {golden_chance = 0.0333}, title = "GILDED STRAIN",
		body = "It is no longer entirely a vegetable.\n1 square in 10 grows golden, not 1 in 15."},
	# Farm squares only grow golden once this is bought (FarmScreen.FARM_GOLD, sow). Shown once a farm
	# is owned; ¶8,000 (tools/pace.py ch3: a few minutes of chapter 3's Findings).
	{id = "farm_gold", parent = "gold_chance_1", at = Vector2(-0.45, 1.25), icon = "sprout", price = 8000, currency = "findings",
		needs_farm = true, title = "ESTATE SEED ALLOCATION",
		body = "Promising seed is now issued to the estates, on signature.\nFarm squares can grow golden too, at the same chance as any square."},
	# COLD CHAIN: how long a ripe square waits before it rots (save.rot_after, FarmScreen.tick), shown
	# with the golden card, a minute before GameEvents "overripe" starts the rot.
	{id = "cold_frames", parent = "", at = Vector2(1.55, 0.05), icon = "crate", price = 250, currency = "findings",
		needs = ["golden_cabbage"], add = {rot_after = 120.0}, title = "COLD FRAMES",
		body = "The cabbages are kept cool. The staff are kept informed.\nA ripe square rots after 5 min instead of 3."},
	# COMPOST DETAIL (FarmScreen.COMPOST, can_work / _finish): farm hands clear a rotten square and sow
	# the seed they carry in it. ¶600 (tools/pace.py: ~2 min of ¶ at ~280 a minute, bought ~6 min after the rot starts).
	{id = "compost_detail", parent = "cold_frames", at = Vector2(2.05, 0.3), icon = "hand", price = 600,
		currency = "findings", title = "COMPOST DETAIL",
		body = "Spoilage is now someone's job. It is not yours.\nFarm hands clear rotten squares and plant them again. Until then only your click clears one."},
	{id = "refrigerated_tarpaulin", parent = "cold_frames", at = Vector2(1.6, 0.55), icon = "crate", price = 500,
		currency = "findings", add = {rot_after = 180.0}, title = "REFRIGERATED TARPAULIN",
		body = "Patent pending. Electricity extra.\nA ripe square rots after 8 min instead of 5."},
	{id = "shelf_life_review", parent = "refrigerated_tarpaulin", at = Vector2(1.6, 1.05), icon = "clock", price = 900,
		currency = "findings", add = {rot_after = 240.0}, title = "SHELF-LIFE REVIEW",
		body = "Spoilage has been reclassified as maturing.\nA ripe square rots after 12 min instead of 8."},
	# FARM OUTPUT (chapter 3): what a farm square harvests, times a plain square (save.farm_square_mult,
	# FarmScreen.harvest_yield): 10× to 15×, 20×, 30×. Shown once a farm is owned (needs_farm).
	# ¶15,000 / ¶60,000 / ¶100,000 (tools/pace.py ch3): chapter 3's Findings sink, each bought a few
	# minutes before a farm whose cabbages it helps to bring in (the 2nd, the 3rd, the 5th).
	{id = "farm_mult_1", parent = "", at = Vector2(-1.55, 0.05), icon = "sprout", price = 15000, currency = "findings",
		needs = ["archive_capacity"], needs_farm = true, add = {farm_square_mult = 5.0}, title = "YIELD TARGETS",
		body = "The farm has been informed of its potential.\nEvery farm square harvests 15× a plain square's cabbages, not 10×."},
	{id = "farm_mult_2", parent = "farm_mult_1", at = Vector2(-1.6, 0.55), icon = "sprout", price = 60000, currency = "findings",
		needs = ["structured_farm"], add = {farm_square_mult = 5.0}, title = "SHARED SERVICES",
		body = "Every farm now shares one accountant.\nEvery farm square harvests 20× a plain square's cabbages, not 15×."},
	{id = "farm_mult_3", parent = "farm_mult_2", at = Vector2(-1.6, 1.05), icon = "sprout", price = 100000, currency = "findings",
		add = {farm_square_mult = 10.0}, title = "VERTICAL INTEGRATION",
		body = "The farm now reports to itself.\nEvery farm square harvests 30× a plain square's cabbages, not 20×."},
	# ARCHIVE (the Findings limit) moved to the projector in round 2 (Projector, same ids).
	# ---- The outer ring (desk card structured_farm; `needs` on the first of each run). Prices paced
	# in tools/pace.py (`ch3`, `flow`). ----
	# SEED BEDS: seeds a farm square holds (save.farm_slots, FarmScreen.slots_of): 2 to 3, 4, 6, each
	# seed its own batch. Only felt if the farm hands can fill them: the two runs below.
	{id = "farm_slots_1", parent = "farm_mult_1", at = Vector2(-2.0, 0.05), icon = "sprout", price = 25000, currency = "findings",
		needs = ["structured_farm"], add = {farm_slots = 1}, title = "SEED BEDS",
		body = "The field has been divided on paper.\nEvery farm square holds 3 seeds instead of 2. Each seed grows its own batch."},
	{id = "farm_slots_2", parent = "farm_slots_1", at = Vector2(-2.42, 0.05), icon = "sprout", price = 50000, currency = "findings",
		add = {farm_slots = 1}, title = "SEED BEDS II",
		body = "The paths between the beds were found to be unproductive.\nEvery farm square holds 4 seeds instead of 3."},
	{id = "farm_slots_3", parent = "farm_slots_2", at = Vector2(-2.42, 0.55), icon = "sprout", price = 110000, currency = "findings",
		add = {farm_slots = 2}, title = "SEED BEDS III",
		body = "A second layer has been approved.\nEvery farm square holds 6 seeds instead of 4."},
	# The farm hands follow: farm squares first (save.farm_hand_route 2, FarmScreen.target_for), then
	# more seeds a trip (farm_hand_shift), so the beds above are filled.
	{id = "hand_route_2", parent = "estate_permit", at = Vector2(-2.05, -0.5), icon = "lens", price = 20000, currency = "findings",
		needs = ["structured_farm"], add = {farm_hand_route = 1}, title = "FARM ROUNDS",
		body = "The roster now has a first page.\nFarm hands plant the farm squares first, and plain squares only when every farm is full."},
	{id = "hand_shift_2", parent = "hand_shift", at = Vector2(-1.0, -1.5), icon = "crate", price = 45000, currency = "findings",
		needs = ["structured_farm"], add = {farm_hand_shift = 2}, title = "SEED SATCHELS",
		body = "A bag is issued. Its weight is deducted.\nFarm hands carry two more seeds per trip and plant two more before returning to the yard."},
	# THINNING (desk card mini_thinning): FIELD THINNING minis out at once (save.thinning_cap,
	# MiniDrop._thin) 6 to 8, 10; the timed drop keeps its own 6. Felt, not an economy step (a mini is
	# a quarter cabbage): ¶1,500 / ¶4,000, ~3 and ~8 min of late chapter 2's ¶ (tools/pace.py: ~500 a
	# minute; the sim buys the first ~30 min after the card, the second early in chapter 3).
	{id = "thinning_cap_1", parent = "", at = Vector2(0.55, 1.17), icon = "sprout", price = 1500, currency = "findings",
		needs = ["mini_thinning"], add = {thinning_cap = 2}, title = "THINNING QUOTA",
		body = "Thinning is now measured. It was found lacking.\nUp to 8 mini cabbages from farm harvests are out at once, not 6."},
	{id = "thinning_cap_2", parent = "thinning_cap_1", at = Vector2(0.55, 1.62), icon = "sprout", price = 4000, currency = "findings",
		add = {thinning_cap = 2}, title = "REVISED THINNING QUOTA",
		body = "The quota was met. The quota was revised.\nUp to 10 mini cabbages from farm harvests are out at once, not 8."},
	# ---- Chapter 4, part 0: NUCLEAR (desk cards nuclear_research to nuclear_family; `needs` on the
	# first of each run). The view settles further out once nuclear_research is stamped (ZOOM_NUCLEAR)
	# so they fit. Prices paced in tools/pace.py (`python tools/pace.py ch4`). ----
	# ENRICHED SOIL (nuclear_research): FARM OUTPUT goes on, 30× to 293× in sixteen small steps (user
	# 2026-11-19: more, smaller purchases), in four rows that snake back and forth.
	{id = "soil_1", parent = "farm_mult_3", at = Vector2(-2.00, 1.50), icon = "sprout", price = 51000, currency = "findings",
		needs = ["nuclear_research"], add = {farm_square_mult = 5.0}, title = "ENRICHED SOIL I",
		body = "Every farm square harvests 35× a plain square's cabbages, not 30×."},
	{id = "soil_2", parent = "soil_1", at = Vector2(-2.85, 1.50), icon = "sprout", price = 65000, currency = "findings",
		add = {farm_square_mult = 5.0}, title = "ENRICHED SOIL II",
		body = "The soil is enriched. The enrichment is not disclosed.\nEvery farm square harvests 40× a plain square's cabbages, not 35×."},
	{id = "soil_3", parent = "soil_2", at = Vector2(-3.70, 1.50), icon = "sprout", price = 94000, currency = "findings",
		add = {farm_square_mult = 6.0}, title = "ENRICHED SOIL III",
		body = "Every farm square harvests 46× a plain square's cabbages, not 40×."},
	{id = "soil_4", parent = "soil_3", at = Vector2(-4.55, 1.50), icon = "sprout", price = 140000, currency = "findings",
		add = {farm_square_mult = 7.0}, title = "ENRICHED SOIL IV",
		body = "Topsoil is now graded by isotope.\nEvery farm square harvests 53× a plain square's cabbages, not 46×."},
	{id = "soil_5", parent = "soil_4", at = Vector2(-4.55, 2.00), icon = "sprout", price = 170000, currency = "findings",
		add = {farm_square_mult = 8.0}, title = "ENRICHED SOIL V",
		body = "Every farm square harvests 61× a plain square's cabbages, not 53×."},
	{id = "soil_6", parent = "soil_5", at = Vector2(-3.70, 2.00), icon = "sprout", price = 200000, currency = "findings",
		add = {farm_square_mult = 9.0}, title = "ENRICHED SOIL VI",
		body = "The worms have been reassigned.\nEvery farm square harvests 70× a plain square's cabbages, not 61×."},
	{id = "soil_7", parent = "soil_6", at = Vector2(-2.85, 2.00), icon = "sprout", price = 250000, currency = "findings",
		add = {farm_square_mult = 11.0}, title = "ENRICHED SOIL VII",
		body = "Every farm square harvests 81× a plain square's cabbages, not 70×."},
	{id = "soil_8", parent = "soil_7", at = Vector2(-2.00, 2.00), icon = "sprout", price = 290000, currency = "findings",
		add = {farm_square_mult = 12.0}, title = "ENRICHED SOIL VIII",
		body = "The ground is warm in winter. Nobody asks why.\nEvery farm square harvests 93× a plain square's cabbages, not 81×."},
	{id = "soil_9", parent = "soil_8", at = Vector2(-2.00, 2.50), icon = "sprout", price = 490000, currency = "findings",
		add = {farm_square_mult = 14.0}, title = "ENRICHED SOIL IX",
		body = "Every farm square harvests 107× a plain square's cabbages, not 93×."},
	{id = "soil_10", parent = "soil_9", at = Vector2(-2.85, 2.50), icon = "sprout", price = 810000, currency = "findings",
		add = {farm_square_mult = 17.0}, title = "ENRICHED SOIL X",
		body = "Fertile is no longer a description. It is a target.\nEvery farm square harvests 124× a plain square's cabbages, not 107×."},
	{id = "soil_11", parent = "soil_10", at = Vector2(-3.70, 2.50), icon = "sprout", price = 940000, currency = "findings",
		add = {farm_square_mult = 19.0}, title = "ENRICHED SOIL XI",
		body = "Every farm square harvests 143× a plain square's cabbages, not 124×."},
	{id = "soil_12", parent = "soil_11", at = Vector2(-4.55, 2.50), icon = "sprout", price = 1100000, currency = "findings",
		add = {farm_square_mult = 22.0}, title = "ENRICHED SOIL XII",
		body = "The furrows glow at dusk. Yields are up.\nEvery farm square harvests 165× a plain square's cabbages, not 143×."},
	{id = "soil_13", parent = "soil_12", at = Vector2(-4.55, 3.00), icon = "sprout", price = 1200000, currency = "findings",
		add = {farm_square_mult = 25.0}, title = "ENRICHED SOIL XIII",
		body = "Every farm square harvests 190× a plain square's cabbages, not 165×."},
	{id = "soil_14", parent = "soil_13", at = Vector2(-3.70, 3.00), icon = "sprout", price = 1400000, currency = "findings",
		add = {farm_square_mult = 30.0}, title = "ENRICHED SOIL XIV",
		body = "The field now has a half-life. It is long enough.\nEvery farm square harvests 220× a plain square's cabbages, not 190×."},
	{id = "soil_15", parent = "soil_14", at = Vector2(-2.85, 3.00), icon = "sprout", price = 1400000, currency = "findings",
		add = {farm_square_mult = 34.0}, title = "ENRICHED SOIL XV",
		body = "Every farm square harvests 254× a plain square's cabbages, not 220×."},
	{id = "soil_16", parent = "soil_15", at = Vector2(-2.00, 3.00), icon = "sprout", price = 1700000, currency = "findings",
		add = {farm_square_mult = 39.0}, title = "ENRICHED SOIL XVI",
		body = "The soil is now mostly product.\nEvery farm square harvests 293× a plain square's cabbages, not 254×."},
	# ACCELERATED RIPENING (isotope_seed): every square's ripening time ×0.866 a step
	# (save.farm_grow_mult, FarmScreen.grow_time), 15 s to 3.6 s, under the greenhouse.
	{id = "ripening_1", parent = "greenhouse", at = Vector2(-1.05, 1.27), icon = "clock", price = 640000, currency = "findings",
		needs = ["isotope_seed"], mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING I",
		body = "Squares ripen in 13 s instead of 15 s."},
	{id = "ripening_2", parent = "ripening_1", at = Vector2(-1.05, 1.69), icon = "clock", price = 810000, currency = "findings",
		mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING II",
		body = "The cabbages have been told they are late.\nSquares ripen in 11.2 s instead of 13 s."},
	{id = "ripening_3", parent = "ripening_2", at = Vector2(-1.05, 2.11), icon = "clock", price = 940000, currency = "findings",
		mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING III",
		body = "Squares ripen in 9.7 s instead of 11.2 s."},
	{id = "ripening_4", parent = "ripening_3", at = Vector2(-1.05, 2.53), icon = "clock", price = 1100000, currency = "findings",
		mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING IV",
		body = "The grow lamps are now reactor lamps.\nSquares ripen in 8.4 s instead of 9.7 s."},
	{id = "ripening_5", parent = "ripening_4", at = Vector2(-1.05, 2.95), icon = "clock", price = 1200000, currency = "findings",
		mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING V",
		body = "Squares ripen in 7.3 s instead of 8.4 s."},
	{id = "ripening_6", parent = "ripening_5", at = Vector2(-1.05, 3.37), icon = "clock", price = 1400000, currency = "findings",
		mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING VI",
		body = "The seasons are now scheduled weekly.\nSquares ripen in 6.3 s instead of 7.3 s."},
	{id = "ripening_7", parent = "ripening_6", at = Vector2(-0.55, 3.37), icon = "clock", price = 1400000, currency = "findings",
		mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING VII",
		body = "Squares ripen in 5.5 s instead of 6.3 s."},
	{id = "ripening_8", parent = "ripening_7", at = Vector2(-0.05, 3.37), icon = "clock", price = 1700000, currency = "findings",
		mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING VIII",
		body = "Ripening has been moved to a faster process.\nSquares ripen in 4.7 s instead of 5.5 s."},
	{id = "ripening_9", parent = "ripening_8", at = Vector2(0.45, 3.37), icon = "clock", price = 1800000, currency = "findings",
		mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING IX",
		body = "Squares ripen in 4.1 s instead of 4.7 s."},
	{id = "ripening_10", parent = "ripening_9", at = Vector2(0.95, 3.37), icon = "clock", price = 2000000, currency = "findings",
		mul = {farm_grow_mult = 0.866}, title = "FORCED RIPENING X",
		body = "A cabbage now ripens in the time it takes to sign for it.\nSquares ripen in 3.6 s instead of 4.1 s."},
	# MUTATION (isotope_seed): the golden chance goes on, 10% to 25% in eight steps, under GILDED STRAIN.
	{id = "mutation_1", parent = "gold_chance_3", at = Vector2(0.00, 2.30), icon = "sprout", price = 510000, currency = "findings",
		needs = ["isotope_seed"], add = {golden_chance = 0.012}, title = "MUTATION I",
		body = "11.2% of squares grow golden, not 10%."},
	{id = "mutation_2", parent = "mutation_1", at = Vector2(0.60, 2.30), icon = "sprout", price = 650000, currency = "findings",
		add = {golden_chance = 0.013}, title = "MUTATION II",
		body = "Some seeds come out different. Different sells.\n12.5% of squares grow golden, not 11.2%."},
	{id = "mutation_3", parent = "mutation_2", at = Vector2(1.20, 2.30), icon = "sprout", price = 790000, currency = "findings",
		add = {golden_chance = 0.016}, title = "MUTATION III",
		body = "14.1% of squares grow golden, not 12.5%."},
	{id = "mutation_4", parent = "mutation_3", at = Vector2(1.80, 2.30), icon = "sprout", price = 940000, currency = "findings",
		add = {golden_chance = 0.019}, title = "MUTATION IV",
		body = "The difference has been made standard.\n16% of squares grow golden, not 14.1%."},
	{id = "mutation_5", parent = "mutation_4", at = Vector2(2.40, 2.30), icon = "sprout", price = 1100000, currency = "findings",
		add = {golden_chance = 0.019}, title = "MUTATION V",
		body = "17.9% of squares grow golden, not 16%."},
	{id = "mutation_6", parent = "mutation_5", at = Vector2(3.00, 2.30), icon = "sprout", price = 1200000, currency = "findings",
		add = {golden_chance = 0.021}, title = "MUTATION VI",
		body = "Mutation is now a line item.\n20% of squares grow golden, not 17.9%."},
	{id = "mutation_7", parent = "mutation_6", at = Vector2(3.60, 2.30), icon = "sprout", price = 1400000, currency = "findings",
		add = {golden_chance = 0.024}, title = "MUTATION VII",
		body = "22.4% of squares grow golden, not 20%."},
	{id = "mutation_8", parent = "mutation_7", at = Vector2(4.20, 2.30), icon = "sprout", price = 1500000, currency = "findings",
		add = {golden_chance = 0.026}, title = "MUTATION VIII",
		body = "The seed has stopped asking what it is.\n25% of squares grow golden, not 22.4%."},
	# REACTOR DRIVES (reactor_machinery): the farm hands' and the tractors' speed, ×1.18 a step (eight each),
	# each a column up from the fourth hand and the fourth tractor.
	{id = "hand_drive_1", parent = "hand_4", at = Vector2(-1.95, -1.80), icon = "clock", price = 810000, currency = "findings",
		needs = ["reactor_machinery"], mul = {farm_hand_speed = 1.1832}, title = "REACTOR STRIDE I",
		body = "Farm hands walk 18% faster."},
	{id = "hand_drive_2", parent = "hand_drive_1", at = Vector2(-1.95, -2.25), icon = "clock", price = 1000000, currency = "findings",
		mul = {farm_hand_speed = 1.1832}, title = "REACTOR STRIDE II",
		body = "The boots now have a core.\nFarm hands walk 18% faster."},
	{id = "hand_drive_3", parent = "hand_drive_2", at = Vector2(-1.95, -2.70), icon = "clock", price = 1200000, currency = "findings",
		mul = {farm_hand_speed = 1.1832}, title = "REACTOR STRIDE III",
		body = "Farm hands walk 18% faster."},
	{id = "hand_drive_4", parent = "hand_drive_3", at = Vector2(-1.95, -3.15), icon = "clock", price = 1400000, currency = "findings",
		mul = {farm_hand_speed = 1.1832}, title = "REACTOR STRIDE IV",
		body = "Walking is now a powered activity.\nFarm hands walk 18% faster."},
	{id = "hand_drive_5", parent = "hand_drive_4", at = Vector2(-1.95, -3.60), icon = "clock", price = 1400000, currency = "findings",
		mul = {farm_hand_speed = 1.1832}, title = "REACTOR STRIDE V",
		body = "Farm hands walk 18% faster."},
	{id = "hand_drive_6", parent = "hand_drive_5", at = Vector2(-1.50, -3.60), icon = "clock", price = 1700000, currency = "findings",
		mul = {farm_hand_speed = 1.1832}, title = "REACTOR STRIDE VI",
		body = "Each step is logged as output.\nFarm hands walk 18% faster."},
	{id = "hand_drive_7", parent = "hand_drive_6", at = Vector2(-1.05, -3.60), icon = "clock", price = 1900000, currency = "findings",
		mul = {farm_hand_speed = 1.1832}, title = "REACTOR STRIDE VII",
		body = "Farm hands walk 18% faster."},
	{id = "hand_drive_8", parent = "hand_drive_7", at = Vector2(-0.60, -3.60), icon = "clock", price = 2000000, currency = "findings",
		mul = {farm_hand_speed = 1.1832}, title = "REACTOR STRIDE VIII",
		body = "The farm hands no longer feel their legs. This is recorded as efficiency.\nFarm hands walk 18% faster."},
	{id = "tractor_drive_1", parent = "tractor_4", at = Vector2(1.95, -1.80), icon = "clock", price = 810000, currency = "findings",
		needs = ["reactor_machinery"], mul = {farm_tractor_speed = 1.1832}, title = "REACTOR DRIVE I",
		body = "Tractors drive 18% faster."},
	{id = "tractor_drive_2", parent = "tractor_drive_1", at = Vector2(1.95, -2.25), icon = "clock", price = 1000000, currency = "findings",
		mul = {farm_tractor_speed = 1.1832}, title = "REACTOR DRIVE II",
		body = "The diesel was replaced. So was the exhaust.\nTractors drive 18% faster."},
	{id = "tractor_drive_3", parent = "tractor_drive_2", at = Vector2(1.95, -2.70), icon = "clock", price = 1200000, currency = "findings",
		mul = {farm_tractor_speed = 1.1832}, title = "REACTOR DRIVE III",
		body = "Tractors drive 18% faster."},
	{id = "tractor_drive_4", parent = "tractor_drive_3", at = Vector2(1.95, -3.15), icon = "clock", price = 1400000, currency = "findings",
		mul = {farm_tractor_speed = 1.1832}, title = "REACTOR DRIVE IV",
		body = "The governor was removed again. It came back on its own.\nTractors drive 18% faster."},
	{id = "tractor_drive_5", parent = "tractor_drive_4", at = Vector2(1.95, -3.60), icon = "clock", price = 1400000, currency = "findings",
		mul = {farm_tractor_speed = 1.1832}, title = "REACTOR DRIVE V",
		body = "Tractors drive 18% faster."},
	{id = "tractor_drive_6", parent = "tractor_drive_5", at = Vector2(1.50, -3.60), icon = "clock", price = 1700000, currency = "findings",
		mul = {farm_tractor_speed = 1.1832}, title = "REACTOR DRIVE VI",
		body = "Top speed is now a reactor setting.\nTractors drive 18% faster."},
	{id = "tractor_drive_7", parent = "tractor_drive_6", at = Vector2(1.05, -3.60), icon = "clock", price = 1900000, currency = "findings",
		mul = {farm_tractor_speed = 1.1832}, title = "REACTOR DRIVE VII",
		body = "Tractors drive 18% faster."},
	{id = "tractor_drive_8", parent = "tractor_drive_7", at = Vector2(0.60, -3.60), icon = "clock", price = 2000000, currency = "findings",
		mul = {farm_tractor_speed = 1.1832}, title = "REACTOR DRIVE VIII",
		body = "The tractors are now faster than the roads.\nTractors drive 18% faster."},
	# NUCLEAR FAMILY (nuclear_family): the sixth to eighth hand and tractor, a hut or a bay each in the
	# yard (FarmScreen.SLOTS), on from the fifth.
	{id = "hand_6", parent = "hand_5", at = Vector2(-2.85, -1.92), icon = "hand", price = 3400000, currency = "findings",
		needs = ["nuclear_family"], add = {farm_hands = 1}, title = "SIXTH FARM HAND",
		body = "Each hut comes with a dosimeter. Rent is waived.\nOne more farm hand plants empty squares: 5 to 6 hands."},
	{id = "hand_7", parent = "hand_6", at = Vector2(-3.3, -2.22), icon = "hand", price = 4500000, currency = "findings",
		add = {farm_hands = 1}, title = "SEVENTH FARM HAND",
		body = "The sixth hand's family has been hired.\nOne more farm hand plants empty squares: 6 to 7 hands."},
	{id = "hand_8", parent = "hand_7", at = Vector2(-3.75, -2.52), icon = "hand", price = 5600000, currency = "findings",
		add = {farm_hands = 1}, title = "EIGHTH FARM HAND",
		body = "The eighth hut was built from the seventh's paperwork.\nOne more farm hand plants empty squares: 7 to 8 hands."},
	{id = "tractor_6", parent = "tractor_5", at = Vector2(2.85, -1.92), icon = "tractor", price = 3400000, currency = "findings",
		needs = ["nuclear_family"], add = {farm_tractors = 1}, title = "SIXTH TRACTOR",
		body = "Reactor-powered, leased, and insured against itself.\nOne more tractor harvests ripe squares: 5 to 6 tractors."},
	{id = "tractor_7", parent = "tractor_6", at = Vector2(3.3, -2.22), icon = "tractor", price = 4500000, currency = "findings",
		add = {farm_tractors = 1}, title = "SEVENTH TRACTOR",
		body = "The fleet clause now has a fleet clause.\nOne more tractor harvests ripe squares: 6 to 7 tractors."},
	{id = "tractor_8", parent = "tractor_7", at = Vector2(3.75, -2.52), icon = "tractor", price = 5600000, currency = "findings",
		add = {farm_tractors = 1}, title = "EIGHTH TRACTOR",
		body = "Eight tractors. The gate was widened by a tractor.\nOne more tractor harvests ripe squares: 7 to 8 tractors."},
]
## Each theme's heading: [title, spot (as a node's `at`), its first nodes], part of its branch (the
## edges to its first nodes run through it; spots by tools/_theme_place.gd), and its category's
## description for the heading's hover popup (a flavour line, then what the branch improves).
const THEMES := [
	["FARM HANDS", Vector2(-0.30, -0.21), ["hand_2"],
		"Seasonal in name only.\nMore farm hands planting empty squares, faster and further per trip."],
	["TRACTORS", Vector2(0.30, -0.21), ["tractor_2"],
		"Harvesting, mechanised and leased.\nMore tractors harvesting ripe squares, faster and more squares per trip."],
	["SOIL", Vector2(-0.30, 0.24), ["fertiliser"],
		"The ground is held to targets.\nSquares ripen sooner, and every harvest gives more cabbages."],
	["SUPPLY", Vector2(0.30, 0.24), ["seed_contract"],
		"Seeds, procured without questions.\nCheaper seed packs, and a standing order that buys sooner and in bulk."],
	["BY HAND", Vector2(0.0, -0.55), ["thumb_yield"],
		"Your own work, recognised in writing.\nSquares you pull by hand yield more and are replanted at once."],
	["GOLDEN", Vector2(0.0, 0.55), ["gold_chance_1"],
		"Some seeds are more promising than others.\nMore squares grow golden."],
	["COLD CHAIN", Vector2(0.77, 0.00), ["cold_frames"],
		"Spoilage is a scheduling issue.\nRipe squares wait longer before they rot."],
	["FARM OUTPUT", Vector2(-0.77, 0.00), ["farm_mult_1"],
		"Acquired farms are held to the same targets.\nEvery farm square harvests more cabbages."],
	["THINNING", Vector2(0.33, 0.70), ["thinning_cap_1"],
		"The field is thinned for its own good.\nMore mini cabbages from farm harvests out at once."],
]

@export var approve_sound: AudioStream
@export var denied_sound: AudioStream
## The view opening up, the first time it shows after WIDE_CARD (the projector sheet's widening).
@export var widen_sound: AudioStream

@onready var _tree: UpgradeTree = $Tree
@onready var _locked: Control = $Locked
## The cream of the Findings counter, for the budget line's ¶ figure.
@export var findings_color: Color
## The budget line: one rich text line, so the ¶ figure (its bold font is the Findings counter's
## Oswald Bold) and the terminal words share a baseline whatever the fonts' ascents.
@onready var _budget: RichTextLabel = $BudgetLine
@onready var _sfx: AudioStreamPlayer = $Sfx


func _ready() -> void:
	_tree.rules = FarmTree
	_tree.bought.connect(_approved)
	_tree.denied.connect(_play.bind(denied_sound))


func _process(_delta: float) -> void:
	var save := SaveManager.save
	var open := unlocked(save)
	_locked.visible = not open
	_tree.visible = open
	# STRUCTURED FARM: the view settles zoomed out; the first time it is watched (the TV's viewport
	# renders) it eases out with the widening sound, after that it is simply there.
	var tv := get_viewport() as SubViewport
	var settle := home_zoom(save)
	if open and wide(save) and _tree.zoom_home != settle and is_visible_in_tree() \
			and (tv == null or tv.render_target_update_mode != SubViewport.UPDATE_DISABLED):
		_tree.zoom_min = ZOOM_MIN_WIDE
		if not save.farm_tree_wide:
			_play(widen_sound)
		_tree.home(settle, 0.0 if save.farm_tree_wide else WIDEN_TIME)
		save.farm_tree_wide = true
	var line := tr("BUDGET  $%s   |   FINDINGS") % Num.text(save.coins) \
			+ " [b][color=%s]¶%s[/color][/b]" % [findings_color.to_html(false), Num.text(save.findings)]
	if _budget.text != line:
		_budget.text = line


func _approved(id: String, paid: int) -> void:
	SaveManager.log_event("farm", id, paid, UpgradeTree.currency_of(node_data(id)))
	_play(approve_sound)


func _play(stream: AudioStream) -> void:
	if stream != null:
		_sfx.stream = stream
		_sfx.play()


## CH2 is subscribed to: desk card farm_terminal is stamped.
static func unlocked(save: SaveGame) -> bool:
	return save.stamped.has(CARD)


static func node_data(id: String) -> Dictionary:
	for node: Dictionary in NODES:
		if node.id == id:
			return node
	return {}


## The zoom the opened-up view settles at: ZOOM_WIDE, ZOOM_NUCLEAR once NUCLEAR_CARD is stamped.
static func home_zoom(save: SaveGame) -> float:
	return ZOOM_NUCLEAR if save.stamped.has(NUCLEAR_CARD) else ZOOM_WIDE


## Whether the save has the opened-up tree: the desk card WIDE_CARD is stamped.
static func wide(save: SaveGame) -> bool:
	return save.stamped.has(WIDE_CARD)


## The terminal is in, every desk card node `id` names in `needs` is stamped, and a farm is owned if
## it is `needs_farm`.
static func _cards_in(node: Dictionary, save: SaveGame) -> bool:
	return unlocked(save) and node.get("needs", []).all(func(card: String) -> bool: return save.stamped.has(card)) \
			and (not node.get("needs_farm", false) or not save.farms_owned.is_empty())


## Shown: it and its ancestors have their cards (a whole branch shows with its feature), or the
## save bought it (an old save keeps a node that has since moved behind a card).
static func is_shown(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	if node.is_empty() or not unlocked(save):
		return false
	return is_bought(id, save) or (_cards_in(node, save) and (node.parent == "" or is_shown(node.parent, save)))


## Reachable: its cards are stamped and its parent bought.
static func is_reachable(id: String, save: SaveGame) -> bool:
	var node := node_data(id)
	return not node.is_empty() and _cards_in(node, save) and (node.parent == "" or is_bought(node.parent, save))


static func is_open(id: String, save: SaveGame) -> bool:
	return is_bought(id, save)


## The farm tree has no departments and no research gates.
static func is_dept(_id: String) -> bool:
	return false


static func locked_by(_id: String, _save: SaveGame) -> String:
	return ""


static func is_bought(id: String, save: SaveGame) -> bool:
	return save.farm_bought.has(id)


static func price_of(id: String, _save: SaveGame) -> int:
	return node_data(id).get("price", 0)


static func can_hold(id: String, save: SaveGame) -> bool:
	return is_reachable(id, save) and not is_bought(id, save)


## Holdable, and the save has its price in its currency (coins or Findings).
static func can_buy(id: String, save: SaveGame) -> bool:
	return can_hold(id, save) and save.get(UpgradeTree.currency_of(node_data(id))) >= price_of(id, save)


## Pays for node `id` in its currency and applies it; false (and nothing changes) if it can't be bought.
static func buy(id: String, save: SaveGame) -> bool:
	if not can_buy(id, save):
		return false
	var currency := UpgradeTree.currency_of(node_data(id))
	save.set(currency, save.get(currency) - price_of(id, save))
	save.farm_bought.append(id)
	UpgradeTree.apply_effect(node_data(id), save)
	return true


## What node `id` waits for, as [heading, name] for its popup, or [] if nothing.
static func requirement(id: String, save: SaveGame) -> Array:
	if is_bought(id, save):
		return []  # Old saves bought from the flat list, parents or not.
	var node := node_data(id)
	if node.parent != "" and not is_bought(node.parent, save):
		return ["REQUIRES:", node_data(node.parent).title]
	for card: String in node.get("needs", []):
		if not save.stamped.has(card):
			return ["REQUIRES DESK CARD:", UpgradeDesk.card_data(card).get("title", card)]
	return []


## Nothing is marked NEW on the farm tree. ponytail: needs a farm_seen save list to add.
static func fresh(_save: SaveGame) -> Array[String]:
	return []


static func themes_shown(save: SaveGame) -> Array[bool]:
	var out: Array[bool] = []
	for heading: Array in THEMES:
		out.append(heading[2].any(func(id: String) -> bool: return is_shown(id, save)))
	return out


## Besides zoom and size, what changes the tree's drawing: cards, nodes bought, what the budget covers.
static func drawn_key(save: SaveGame) -> Array:
	var covered := 0
	for node: Dictionary in NODES:
		covered += int(save.get(UpgradeTree.currency_of(node)) >= node.price)
	return [save.stamped.size(), save.farm_bought.size(), covered, save.farms_owned.is_empty()]
