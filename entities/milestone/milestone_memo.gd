extends CanvasLayer
## Memos (also the game's Steam achievements): each entry in MEMOS has a condition on the save. Every
## CHECK_EVERY seconds the first one met and not yet earned in this save is earned (its id goes into
## save.milestones), its bonus (if any) applied once, logged, filed in the Profile (the record kept
## across new games and chapter loads, which the FILES and Steam show) and a paper memo slides up
## from the bottom edge and after HOLD seconds flies into the FILES folder. One the Profile already
## holds (a replay) comes quietly: no paper, or a short one (SHORT_HOLD) if it has a bonus to tell
## (a click on it removes it at once). Several due at once queue up. A memo filed makes the folder
## glow softly until it is clicked or GLOW_TIME seconds pass. The game keeps running; only the paper's own rect takes the mouse.
## Memos already met when the scene loads (an old save meeting new memos) are filed without the paper.
## The FILES folder, a 3D manila folder lying in the desk's bottom-right corner (once the Profile
## holds a memo, so from the start of every new game after the first memo), opens on hover a little and, clicked, shows every memo as a grid of paper cards on a dark
## shade: the filed ones newest first, then the ones not yet filed, greyed. Two tabs on top switch
## between the memos and the boss's signed notes (newest first).
## An X in the top-right corner, a click outside the cards or Esc closes it.

const FONT := preload("res://assets/fonts/Oswald.ttf")
const BODY_FONT := preload("res://assets/fonts/NunitoSans.ttf")
const PAPER := Color(0.72, 0.73, 0.69)
const INK := Color(0.13, 0.15, 0.14)
## The ink line under the stamp glyph.
const STAMP := Color(0.55, 0.12, 0.1)
## The only saturated colours: the cabbage's green, and research's cold cyan.
const CABBAGE := Color(0.42, 0.68, 0.25)
const CYAN := Color(0.35, 0.85, 0.95)
const Events := preload("res://globalScripts/game_events.gd")

## id: save key and, upper-cased, the Steam achievement API name (never rename one). re: the title.
## how: how to file it. Condition, one of: `stat` (a save number) at least `at`; `card` stamped on the
## upgrade desk ("*" every card); `node` bought on the projector. Optional bonus: the save number
## `key` multiplied by `mul` (times-only, so it stacks with upgrades) and its text `bonus`.
## note: the memo's line. icon: the glyph on its card (_draw_icon). Or `hook = true`: no condition on
## the save, filed by notify(id) from the code that sees it happen (the ending, which is never saved).
## Optional `chapter`: until the Profile has seen that chapter (Profile.reached) the unfiled memo is
## a "?" card in the FILES, so its title spoils nothing.
const MEMOS := [
	{id = "units_10", stat = "sold", at = 10, re = "10 CABBAGES MOVED", how = "Sell 10 cabbages.", icon = "cabbage",
		note = "Ten cabbages have left the building. This has been noted in triplicate."},
	{id = "units_25", stat = "sold", at = 25, key = "marketing", mul = 1.25, re = "25 CABBAGES MOVED", how = "Sell 25 cabbages.",
		icon = "cabbage", note = "Your output has been observed.", bonus = "The street accepts prices 25% higher."},
	{id = "units_100", stat = "sold", at = 100, key = "findings_per_cabbage", mul = 2, re = "100 CABBAGES MOVED",
		how = "Sell 100 cabbages.", icon = "cabbage", note = "Management notes your contribution.",
		bonus = "The research lab files twice the Findings."},
	{id = "units_250", stat = "sold", at = 250, key = "associate_speed", mul = 1.5, re = "250 CABBAGES MOVED",
		how = "Sell 250 cabbages.", icon = "cabbage", note = "Associates were reminded that walking is billable.",
		bonus = "Hired hands move 50% faster."},
	{id = "units_1000", stat = "sold", at = 1000, key = "hand_output", mul = 1.5, re = "1K CABBAGES MOVED",
		how = "Sell 1K cabbages.", icon = "cabbage", note = "The board has been informed. It did not respond.",
		bonus = "Hired hands make 50% more trips."},
	{id = "units_2500", stat = "sold", at = 2500, key = "associate_speed", mul = 1.5, re = "2.500 CABBAGES MOVED",
		how = "Sell 2.500 cabbages.", icon = "cabbage", note = "Your figures have been laminated.",
		bonus = "Hired hands move 50% faster."},
	# The street pays double from 8,500 sold (round 2 point 19: at 10,000 it came 13 min after the
	# fourth farm, too late). The id stays units_10000: saves that filed it must not get the x2 twice.
	{id = "units_10000", stat = "sold", at = 8500, key = "marketing", mul = 2.0, re = "8.500 CABBAGES MOVED",
		how = "Sell 8.500 cabbages.", icon = "cabbage", note = "A plaque is under consideration.",
		bonus = "The street accepts prices twice as high."},
	{id = "units_50000", stat = "sold", at = 50000, re = "50K CABBAGES MOVED", how = "Sell 50K cabbages.",
		icon = "cabbage", note = "The plaque has been reconsidered."},
	{id = "coins_1000", stat = "coins", at = 1000, re = "$1K ON HAND", how = "Hold $1K at once.",
		icon = "coin", note = "Liquidity has been detected at your desk."},
	{id = "coins_10000", stat = "coins", at = 10000, re = "$10K ON HAND", how = "Hold $10K at once.",
		icon = "coin", note = "Accounts asks that you stop counting it aloud."},
	{id = "coins_100000", stat = "coins", at = 100000, re = "$100K ON HAND", how = "Hold $100K at once.",
		icon = "coin", note = "This sum is now the property of a spreadsheet."},
	{id = "catches_1", stat = "catches", at = 1, re = "CABBAGE INTERCEPTED", how = "Catch a cabbage as it leaves the chute.",
		icon = "catch", note = "Gravity has been overruled. Gravity has been informed."},
	{id = "catches_50", stat = "catches", at = 50, re = "50 INTERCEPTIONS", how = "Catch 50 cabbages in mid-air.",
		icon = "catch", note = "Your reflexes are company property."},
	{id = "catches_500", stat = "catches", at = 500, re = "500 INTERCEPTIONS", how = "Catch 500 cabbages in mid-air.",
		icon = "catch", note = "The chute has filed a complaint."},
	{id = "refusals_1", stat = "refusals", at = 1, re = "CABBAGE REFUSED", how = "Have the street refuse a cabbage.",
		icon = "window", note = "The street has an opinion. It is not binding."},
	{id = "refusals_100", stat = "refusals", at = 100, re = "100 REFUSALS", how = "Have the street refuse 100 cabbages.",
		icon = "window", note = "Pricing remains your responsibility."},
	{id = "price_10", stat = "sale_price", at = 10, re = "PREMIUM POSITIONING", how = "Chalk a price of $10 or more.",
		icon = "coin", note = "The cabbage has not changed. Its story has."},
	{id = "hands_1", stat = "hands", at = 1, re = "FIRST HIRE", how = "Hire an associate.",
		icon = "hand", note = "You are now responsible for another person. Sign here."},
	{id = "hands_10", stat = "hands", at = 10, re = "FULL HEADCOUNT", how = "Employ 10 associates.",
		icon = "hand", note = "Ten associates. None of them have names on file."},
	{id = "findings_1", stat = "findings", at = 1, re = "FIRST FINDING", how = "File a Finding in the research lab.",
		icon = "lens", note = "Something has been found. Nobody asked what."},
	{id = "findings_1000", stat = "findings", at = 1000, re = "1K FINDINGS ON FILE", how = "Hold 1K Findings at once.",
		icon = "lens", note = "The filing cabinet has been extended."},
	{id = "research_directive", card = "research_inspection", re = "FIRST RESEARCH DIRECTIVE",
		how = "Stamp the first research directive.", icon = "stamp", note = "The inspection will be inspected."},
	{id = "research_units_1", stat = "research_units", at = 1, re = "RESEARCH CABBAGE ANALYSED",
		how = "Have the research lab analyse a research cabbage.", icon = "research", note = "It was blue. It is now data."},
	{id = "minis_1000", stat = "minis_sold", at = 1000, re = "1K MINIATURE CABBAGES", how = "Sell 1K mini cabbages.",
		icon = "mini", note = "The cabbages are small. So are the margins."},
	{id = "lever_split", stat = "tube_split", at = 0.5, re = "OUTPUT DIVERTED", how = "Divert tube minis to research (lever on SPLIT or RESEARCH).",
		icon = "lever", note = "Half of everything now goes somewhere else."},
	{id = "fines_1", stat = "fines", at = 1, re = "FIRST FINE", how = "Sell a rotten cabbage.",
		icon = "bin", note = "The deduction has been made. The lesson has not."},
	{id = "binned_100", stat = "binned", at = 100, re = "100 CABBAGES DISPOSED", how = "Throw 100 rotten cabbages into the bin.",
		icon = "bin", note = "Waste is a process. You are the process."},
	{id = "quotas_1", stat = "quotas_met", at = 1, re = "QUOTA MET", how = "Meet a manager's quota.",
		icon = "chart", note = "Expectations have been adjusted upward."},
	{id = "quotas_25", stat = "quotas_met", at = 25, re = "25 QUOTAS MET", how = "Meet 25 of the manager's quotas.",
		icon = "chart", note = "The manager has started to rely on you. This is not a compliment."},
	{id = "songs_20", stat = "songs_skipped", at = 20, re = "20 SONGS SKIPPED", how = "Skip 20 songs on the radio.",
		icon = "radio", note = "Your taste in music has been entered into your file."},
	{id = "radio_silent", stat = "radio_silent", at = 3600, re = "ONE HOUR OF SILENCE",
		how = "Keep the radio off for an hour in total.", icon = "radio", note = "Silence is also productivity."},
	{id = "double_findings", node = "double_findings", re = "METHODOLOGY DOUBLED",
		how = "Buy DOUBLE FINDINGS on the projector.", icon = "tree", note = "Twice the findings. The same questions."},
	{id = "slogan_6", node = "slogan_6", re = "MESSAGING FINALISED", how = "Buy the last slogan on the projector.",
		icon = "tree", note = "There is nothing left to say about cabbage."},
	{id = "every_card", card = "*", re = "INBOX ZERO", how = "Stamp every card on the upgrade desk.",
		icon = "stamp", note = "There is nothing left to approve. Please wait for something."},
	# ---- Chapter 2: the family farm on the TV.
	{id = "harvest_1", stat = "farm_harvests", at = 1, chapter = 2, re = "FIRST HARVEST", how = "Harvest a square on the farm.",
		icon = "field", note = "The soil has delivered. It will be asked to do so again."},
	{id = "harvest_500", stat = "farm_harvests", at = 500, chapter = 2, re = "500 HARVESTS", how = "Harvest 500 squares on the farm.",
		icon = "field", note = "The farm is now a process. It does not get weekends."},
	{id = "plots_24", stat = "farm_plots", at = 24, chapter = 2, re = "FULL ACREAGE", how = "Open all 24 squares on the farm.",
		icon = "field", note = "There is no more land. Head office is looking into that."},
	{id = "hand_harvest_500", stat = "hand_harvested", at = 500, chapter = 2, re = "MANUAL LABOUR",
		how = "Pull 500 cabbages off the farm by hand.", icon = "hand", note = "Your hands have been reclassified as farm equipment."},
	{id = "seeds_500", stat = "farm_seeds", at = 500, chapter = 2, re = "SEED CAPITAL", how = "Hold 500 seeds in the crate at once.",
		icon = "field", note = "Seeds are assets. Please plant them instead of counting them."},
	{id = "golden_1", stat = "golden_sold", at = 1, chapter = 2, re = "PREMIUM PRODUCE", how = "Sell a golden cabbage.",
		icon = "coin", note = "It was a cabbage. Accounts invoiced it as jewellery."},
	{id = "golden_lab_10", stat = "golden_analysed", at = 10, chapter = 2, re = "BULLION ANALYSED",
		how = "Have the research lab analyse 10 golden cabbages.", icon = "lens", note = "The lab confirms they are cabbages. Expensive ones."},
	{id = "rotted_1", stat = "farm_rotted", at = 1, chapter = 2, re = "COMPOST", how = "Let a ripe square rot on the farm.",
		icon = "bin", note = "Compost is not a product category. This has been explained to you."},
	{id = "promotion", card = "mechanisation", chapter = 2, re = "MIDDLE MANAGEMENT", how = "Put a tractor on the farm.",
		icon = "stamp", note = "Your title has changed. Your chair has not."},
	{id = "tractors_3", stat = "farm_tractors", at = 3, chapter = 2, re = "MOTOR POOL", how = "Run 3 tractors on the farm.",
		icon = "field", note = "Three tractors share one parking space. Sort it out among yourselves."},
	{id = "tv_1800", stat = "tv_seconds", at = 1800, chapter = 2, re = "PRIME TIME", how = "Watch the farm on the TV for 30 minutes in total.",
		icon = "tv", note = "Watching cabbage grow has been logged as overtime. It will not be paid as such."},
	{id = "chute_600", stat = "chute_shut_seconds", at = 600, chapter = 2, re = "SUPPLY INTERRUPTED",
		how = "Keep the chute shut for 10 minutes in total.", icon = "lever", note = "The chute has asked whether it did something wrong."},
	# ---- Chapters and the end: one memo per chapter entered (Profile.reach), the ending's own (notify).
	{id = "chapter_2", card = "family_farm", chapter = 2, re = "FAMILY BUSINESS", how = "Buy the family farm.",
		icon = "field", note = "Welcome to agriculture. Nepotism has been noted and approved."},
	{id = "chapter_3", card = "consolidation", chapter = 3, re = "HEAD OF ACQUISITIONS",
		how = "Stamp the consolidated growth requisition.", icon = "stamp", note = "Growth will now be bought. Receipts to accounts."},
	{id = "chapter_4", card = "stars", chapter = 4, re = "THE WORLD, OWNED", how = "Own every farm in the world.",
		icon = "globe", note = "The world is now an asset. Its depreciation is under review."},
	{id = "chapter_5", card = Events.GUN_CARD, chapter = 5, re = "FINAL REQUISITION", how = "Stamp the last form.",
		icon = "stamp", note = "There are no more forms. There is only cabbage."},
	{id = "game_end", hook = true, chapter = 5, re = "EVERYTHING IS CABBAGE", how = "Finish the game.",
		icon = "cabbage", note = "The office has been converted. The file is closed. Thank you for your service."},
	{id = "end_radio_first", hook = true, chapter = 5, re = "THE MUSIC STOPS", how = "In the end, shoot the radio before anything else on the desk.",
		icon = "radio", note = "The radio went first. Someone had to set priorities."},
	{id = "end_misses", hook = true, chapter = 5, re = "COLLATERAL", how = "Miss 25 shots in the end.",
		icon = "target", note = "The walls were not the target. Facilities will invoice you for them anyway."},
	{id = "end_marksman", hook = true, chapter = 5, re = "ZERO WASTAGE", how = "Finish the end without missing a single shot.",
		icon = "target", note = "Every round was accounted for. Accounts would like to shake your hand."},
	{id = "end_hold", hook = true, chapter = 5, re = "SECOND THOUGHTS", how = "Wait a full minute before the last click.",
		icon = "clock", note = "Your hesitation was noted in your file. The file is now cabbage."},
	# ---- Chapter 3: the map table, the farms bought and haggled for, the laws, the war. Counters from
	# FarmRegister (owners_insulted, floor_buys) and WarSheet.tally (the wars).
	{id = "farms_1", stat = "farms_owned", at = 1, chapter = 3, re = "FIRST ACQUISITION", how = "Buy a farm at the map table.",
		icon = "field", note = "The farm has been informed that it is now a subsidiary."},
	{id = "farms_12", stat = "farms_owned", at = 12, chapter = 3, re = "12 FARMS OWNED", how = "Own 12 farms.",
		icon = "field", note = "Half the farms on the map now report to Desk 4."},
	{id = "floor_price", stat = "floor_buys", at = 1, chapter = 3, re = "BOTTOM OF THE MARKET",
		how = "Haggle a farm down to its lowest price, then buy it.", icon = "coin", note = "The owner signed with dignity. The dignity was not itemised."},
	{id = "insults_5", stat = "owners_insulted", at = 5, chapter = 3, re = "FIRM OPENING POSITION",
		how = "Insult farm owners with 5 offers.", icon = "hand", note = "Five owners have been offended on the company's behalf."},
	{id = "no_taxes", card = "no_taxes", chapter = 3, re = "LEGISLATIVE ALIGNMENT", how = "Approve NO MORE TAXES ON CABBAGES.",
		icon = "stamp", note = "The law has been amended to reflect our position."},
	{id = "wars_won_1", stat = "wars_won", at = 1, chapter = 3, re = "FIRST HOSTILE ACQUISITION", how = "Win a war.",
		icon = "flag", note = "The farm accepted our offer. It was not offered an alternative."},
	{id = "wars_won_10", stat = "wars_won", at = 10, chapter = 3, re = "10 HOSTILE ACQUISITIONS", how = "Win 10 wars.",
		icon = "flag", note = "Legal has stopped asking which country."},
	{id = "wars_lost_1", stat = "wars_lost", at = 1, chapter = 3, re = "ACQUISITION DEFERRED", how = "Lose a war.",
		icon = "flag", note = "The farm remains independent for now. This is being looked into."},
	{id = "war_exemplary", stat = "wars_exemplary", at = 1, chapter = 3, re = "EXEMPLARY CONDUCT",
		how = "Win a war graded EXEMPLARY.", icon = "chart", note = "Your engagement will be used in training material."},
	{id = "annexed_1", stat = "countries_annexed", at = 1, chapter = 3, re = "FIRST ANNEXATION",
		how = "Take every farm of a country abroad.", icon = "flag", note = "A border has been reclassified as an internal wall."},
	{id = "annexed_4", stat = "countries_annexed", at = 4, chapter = 3, re = "REGIONAL OFFICE",
		how = "Take every farm of 4 countries abroad.", icon = "flag", note = "Four governments now route their mail through Desk 4."},
	{id = "war_skeleton_crew", stat = "solo_wins", at = 1, chapter = 3, re = "SKELETON CREW", how = "Win a war with a single figure.",
		icon = "hand", note = "Headcount was reduced to one. Results were not."},
	{id = "war_associates_only", stat = "associate_wins", at = 1, chapter = 3, re = "BACK TO BASICS",
		how = "Win a war with field associates only, after hiring cabbage-pult crews.", icon = "hand",
		note = "Senior staff were available. They were not consulted."},
	{id = "war_quick_retreat", stat = "quick_retreats", at = 1, chapter = 3, re = "STRATEGIC REALIGNMENT",
		how = "Retreat within 3 seconds of START.", icon = "flag", note = "The engagement was reviewed and found premature."},
	{id = "war_lost_untouched", stat = "untouched_losses", at = 1, chapter = 3, re = "NON-AGGRESSION PACT",
		how = "Lose a war without destroying a single defence.", icon = "flag", note = "The defences were left exactly as we found them."},
	{id = "condense_32", stat = "condense", at = 32, chapter = 3, re = "MAXIMUM DENSITY", how = "Condense 32 cabbages into one.",
		icon = "cabbage", note = "It is the size of one cabbage. Physics has been asked for comment."},
	{id = "merge_10k", stat = "merge_top", at = 10000, chapter = 3, re = "LEGAL TENDER, CONSOLIDATED",
		how = "Have the coins on the desk merge up to $10K.", icon = "coin", note = "Accounts has requested a larger wallet."},
]
## Ending memos: misses for end_misses, seconds facing the gun for end_hold.
const END_MISSES := 25
const END_HOLD := 60.0
## The paper's line under a memo without a bonus.
const NO_BONUS := "No action is required. None will be taken."
## Seconds between checks for a memo come due.
const CHECK_EVERY := 0.5
const SIZE := Vector2(560, 250)
const IN_TIME := 0.35
## Seconds the paper takes to fly into the folder, and its scale on arrival.
const FLY_TIME := 0.55
const FLY_SCALE := 0.08
const HOLD := 6.0
## A replayed memo's paper (its bonus earned again): up this long.
const SHORT_HOLD := 2.5
## One card in the FILES grid.
const CARD := Vector2(540, 150)
## One signed boss report in the FILES (its tab, two to a row): wide and tall, for its whole text in readable type.
const REPORT_CARD := Vector2(822, 420)
## The FILES view's close button (px square), in its top-right corner.
const CLOSE := 40.0
## The FILES folder on the desk: hover animation seconds, how far the cover opens (rad), the
## papers rise (m) and it grows hovered, and its glow band's brightest emission.
const HOVER_TIME := 0.15
const COVER_OPEN := 0.3
const PAPERS_RISE := 0.006
const HOVER_GROW := 0.06
const GLOW_ENERGY := 2.4
const GLOW := Color(0.85, 0.86, 0.78)
## Seconds the folder glows after a memo is filed, and one pulse's seconds.
const GLOW_TIME := 45.0
const GLOW_PULSE := 1.8

var _queue: Array[Dictionary] = []
var _memo := {}
var _t := 0.0
## Where the paper's centre rests once up, and where the folder takes it (screen px).
var _rest := Vector2.ZERO
var _glow_left := 0.0
var _clock := 0.0
## Whether the mouse is on the folder (what the hover eases back to after a flick).
var _hovered := 0.0
var _check_in := 0.0
## 0 rest .. 1 hovered: the folder's cover lifts, its papers rise, it grows a little.
var _hover := 0.0
var _hovering: Tween
## The glow band's own material (the model's surface 1), its emission driven by glow_at().
var _glow: StandardMaterial3D

@onready var _paper: Control = $Paper
@onready var _folder: Node3D = $Folder
@onready var _folder_model: Node3D = $Folder/Model
@onready var _skeleton: Skeleton3D = $Folder/Model/Armature/Skeleton3D
@onready var _cover := _skeleton.find_bone("CoverHinge")
@onready var _papers := _skeleton.find_bone("Papers")
@onready var _files: CanvasLayer = $Files
@onready var _shade: Control = $Files/Shade
@onready var _list: Control = $Files/Shade/List
@onready var _column: Control = $Files/Shade/List/Column
## The boss's signed reports, newest first, above the memos.
@onready var _reports: Control = $Files/Shade/List/Column/Reports
@onready var _grid: Control = $Files/Shade/List/Column/Grid
@onready var _boss_tab: Button = $Files/Shade/Tabs/Boss
## Its label carries the count of memos filed (memos_tab_text).
@onready var _memos_tab: Button = $Files/Shade/Tabs/Memos


func _ready() -> void:
	_paper.size = SIZE
	_paper.pivot_offset = SIZE / 2.0
	_paper.rotation = deg_to_rad(-1.5)
	_paper.visible = false
	_paper.draw.connect(_draw_paper)
	_paper.gui_input.connect(_on_paper_input)
	var hit: Interactable = $Folder/Hit/Interactable
	hit.grabbed.connect(_open_files)
	hit.hovered.connect(_on_folder_hover.bind(1.0))
	hit.unhovered.connect(_on_folder_hover.bind(0.0))
	var band: MeshInstance3D = $Folder/Model/Armature/Skeleton3D/files_folder
	_glow = band.get_active_material(1).duplicate()
	_glow.emission_enabled = true
	_glow.emission = GLOW
	band.set_surface_override_material(1, _glow)
	_set_hover(0.0)
	_shade.draw.connect(_draw_shade)
	_shade.gui_input.connect(_on_shade_input)
	_boss_tab.toggled.connect(_show_tab)
	_files.visible = false
	Profile.migrate(SaveManager.save.milestones)
	_file_due(false)
	SteamAchievements.sync(Profile.filed())


func _process(delta: float) -> void:
	_clock += delta
	if _glow_left > 0.0:
		_glow_left -= delta
	_glow.emission_energy_multiplier = GLOW_ENERGY * glow_at(_glow_left, _clock)
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = CHECK_EVERY
		_file_due(true)
		_folder.visible = not Profile.filed().is_empty()
		$Folder/Hit/Interactable.enabled = _folder.visible and not _files.visible
	if _memo.is_empty():
		if _queue.is_empty():
			_paper.visible = false
			return
		_memo = _queue.pop_front()
		_t = 0.0
		_paper.visible = true
		$Land.play()
	_t += delta
	var view := get_viewport().get_visible_rect().size
	_rest = Vector2(view.x * 0.5, view.y - SIZE.y * 0.5 - 40.0)
	var centre := _rest.lerp(_rest + Vector2(0, SIZE.y + 70.0), 1.0 - slide_at(_t))
	var p := clampf((_t - _memo.get("hold", HOLD)) / FLY_TIME, 0.0, 1.0)
	if p > 0.0:
		centre = fly_at(p, _rest, get_viewport().get_camera_3d().unproject_position(_folder.global_position))
	var size := lerpf(1.0, FLY_SCALE, ease(p, 2.0))
	_paper.scale = Vector2(size, size)
	_paper.rotation = deg_to_rad(lerpf(-1.5, 14.0, p))
	_paper.position = centre - SIZE * 0.5
	_paper.queue_redraw()
	if p >= 1.0:
		# Tucked in: the folder's cover flicks open and shut.
		_memo = {}
		$Rustle.play()
		_hover_to(1.0, func() -> void: _hover_to(_hovered))


## Earns every memo come due: applied, logged, filed and sent to Steam, and queued for the paper if
## `with_paper` (new to the Profile; a replayed one only if it has a bonus, and short).
func _file_due(with_paper: bool) -> void:
	var save := SaveManager.save
	Profile.reach(chapter_of(save))
	var m := due(save)
	while not m.is_empty():
		apply(save, m)
		SaveManager.log_event("milestone", m.id)
		var new := Profile.file(PackedStringArray([m.id]))
		if new:
			SteamAchievements.unlock(m.id)
		if with_paper and (new or m.has("bonus")):
			var paper := m.duplicate()
			if not new:
				paper["hold"] = SHORT_HOLD
			_queue.append(paper)
			_glow_left = GLOW_TIME
		m = due(save)


## Esc closes it, in _input so it gets Esc before the in-game menu (later in the tree, unhandled) opens.
func _input(event: InputEvent) -> void:
	if _files.visible and event.is_action_pressed("ui_cancel"):
		_files.visible = false
		get_viewport().set_input_as_handled()


## Queues a memo from elsewhere (the manager's performance concern): `re`, `note` and `bonus` as in
## MEMOS, nothing applied.
func post(m: Dictionary) -> void:
	_queue.append(m)


func _on_paper_input(event: InputEvent) -> void:
	if _clicked(event):
		_memo = {}
		_paper.visible = false
		_paper.accept_event()


## The folder clicked: every memo as a card on the dark shade.
func _open_files() -> void:
	_glow_left = 0.0
	for card in _grid.get_children() + _reports.get_children():
		card.free()
	for id in reports_order(SaveManager.save):
		var card := Control.new()
		card.custom_minimum_size = REPORT_CARD
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.draw.connect(_draw_report.bind(card, BossReport.report(id)))
		_reports.add_child(card)
	for m in files_order(Profile.filed()):
		var card := Control.new()
		card.custom_minimum_size = CARD
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.draw.connect(_draw_card.bind(card, m))
		_grid.add_child(card)
	_memos_tab.text = memos_tab_text(tr("MEMOS"), Profile.filed())
	_show_tab(_boss_tab.button_pressed)
	_files.visible = true


## Shows the boss notes (`boss`) or the memos, from the top.
func _show_tab(boss: bool) -> void:
	_reports.visible = boss
	_grid.visible = not boss
	_list.scroll_vertical = 0
	_shade.queue_redraw()


## A click on the X or on the shade outside the cards closes the files (the shade keeps it from the desk).
func _on_shade_input(event: InputEvent) -> void:
	var at := _shade.get_global_mouse_position()
	if _clicked(event) and (_close_rect().has_point(at) or not _list.get_global_rect().intersection(_column.get_global_rect()).has_point(at)):
		_files.visible = false


## The close X's rect on the shade, top right.
func _close_rect() -> Rect2:
	return Rect2(_shade.size.x - CLOSE - 24.0, 24.0, CLOSE, CLOSE)


static func _clicked(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	return button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT


## Files hook memo `id` (MEMOS `hook`) in the Profile and on Steam at once, no paper: the ending is
## never saved and stops this layer, so it cannot wait for the save.
static func notify(id: String) -> void:
	if Profile.file(PackedStringArray([id])):
		SteamAchievements.unlock(id)


## The ending's last click: the game is finished, with `missed` shots that hit nothing and `held`
## seconds facing the gun before the click. Files what that earns (ending_memos).
static func file_ending(missed: int, held: float) -> void:
	for id in ending_memos(missed, held):
		notify(id)


## The hook memos the last click earns: game_end always, and end_misses, end_marksman, end_hold.
static func ending_memos(missed: int, held: float) -> PackedStringArray:
	var ids := PackedStringArray(["game_end"])
	if missed >= END_MISSES:
		ids.append("end_misses")
	if missed == 0:
		ids.append("end_marksman")
	if held >= END_HOLD:
		ids.append("end_hold")
	return ids


## The chapter `save` is in: 1 at the start, 2 from the family farm, 3 from the consolidation card,
## 4 from the stars card, 5 (the ending) from the gun card.
static func chapter_of(save: SaveGame) -> int:
	if Events.chapter_5(save):
		return 5
	if Events.chapter_3_done(save):
		return 4
	if Events.chapter_3(save):
		return 3
	return 2 if save.stamped.has("family_farm") else 1


## Whether memo `m` shows as a "?" card: not `filed` yet and its chapter beyond the one `reached`.
static func hidden(m: Dictionary, filed: PackedStringArray, reached: int) -> bool:
	return not filed.has(m.id) and m.get("chapter", 1) > reached


## Whether memo `m`'s condition holds in `save` (a hook memo's never: notify files it).
static func met(save: SaveGame, m: Dictionary) -> bool:
	if m.has("hook"):
		return false
	if m.has("card"):
		if m.card == "*":
			return UpgradeDesk.CARDS.all(func(card: Dictionary) -> bool: return save.stamped.has(card.id))
		return save.stamped.has(m.card)
	if m.has("node"):
		return save.tree_bought.has(m.node)
	var value: Variant = save.get(m.get("stat", ""))
	if value == null:
		return false  # No condition on the save (or no such number): never met here.
	return (value.size() if value is PackedStringArray else value) >= m.at  # A list counts its entries (farms_owned).


## The first memo met in `save` and not yet earned in it, or {} if none (the Profile aside: a bonus
## is earned again in every run).
static func due(save: SaveGame) -> Dictionary:
	for m: Dictionary in MEMOS:
		if not save.milestones.has(m.id) and met(save, m):
			return m
	return {}


## Earns memo `m` in `save`: multiplies its save number by its mul, if it has a bonus, and records it.
static func apply(save: SaveGame, m: Dictionary) -> void:
	if m.has("key"):
		var value: Variant = save.get(m.key)
		save.set(m.key, roundi(value * m.mul) if value is int else value * m.mul)
	save.milestones.append(m.id)


## The FILES grid's order: the `filed` memos (Profile.filed) newest first, then the rest in MEMOS order.
static func files_order(filed: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(filed.size() - 1, -1, -1):
		var m := memo(filed[i])
		if not m.is_empty():
			out.append(m)
	for m: Dictionary in MEMOS:
		if not filed.has(m.id):
			out.append(m)
	return out


## The boss reports in the FILES: the signed ones, newest first (ids BossReport.report knows).
static func reports_order(save: SaveGame) -> Array[String]:
	var out: Array[String] = []
	for i in range(save.reports.size() - 1, -1, -1):
		var id := save.reports[i]
		if id in ["closing", "welcome", "demo_end"] or BossReport.Events.EVENTS.has(id):
			out.append(id)
	return out


## How many of the achievements (MEMOS) are in `filed` (Profile.filed): retired ids and the posted
## papers (the spike memo, the closing paper) never count.
static func filed_count(filed: PackedStringArray) -> int:
	return MEMOS.filter(func(m: Dictionary) -> bool: return filed.has(m.id)).size()


## The memos tab's label: `title` (translated) and the count filed of all, "MEMOS  12 / 34".
static func memos_tab_text(title: String, filed: PackedStringArray) -> String:
	return "%s  %d / %d" % [title, filed_count(filed), MEMOS.size()]


## The memo with id `id`, or {} if there is none.
static func memo(id: String) -> Dictionary:
	for m: Dictionary in MEMOS:
		if m.id == id:
			return m
	return {}


## 0 hidden .. 1 fully up: eases up over IN_TIME.
static func slide_at(t: float) -> float:
	return 1.0 - pow(1.0 - clampf(t / IN_TIME, 0.0, 1.0), 3.0)


## The paper's centre `p` (0..1) of the way from `from` into the folder at `to`: eased in and out,
## bowing up over a curve (a quadratic Bezier through a point above the midpoint).
static func fly_at(p: float, from: Vector2, to: Vector2) -> Vector2:
	var e := smoothstep(0.0, 1.0, p)
	var bow := (from + to) * 0.5 + Vector2(0, -0.35 * from.distance_to(to))
	return from.lerp(bow, e).lerp(bow.lerp(to, e), e)


## The folder's glow (0..1) with `left` seconds of it remaining, at clock `t`: a soft pulse that
## fades out over its last second; 0 once over.
static func glow_at(left: float, t: float) -> float:
	if left <= 0.0:
		return 0.0
	return (0.6 + 0.4 * sin(t * TAU / GLOW_PULSE)) * clampf(left, 0.0, 1.0)


func _draw_paper() -> void:
	if _memo.is_empty():
		return
	var w := SIZE.x
	_paper.draw_rect(Rect2(Vector2(10, 10), SIZE), Color(0, 0, 0, 0.4))
	_paper.draw_rect(Rect2(Vector2.ZERO, SIZE), PAPER)
	_paper.draw_string(FONT, Vector2(28, 52), tr("MEMORANDUM"), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, INK)
	_paper.draw_string(FONT, Vector2(28, 52), tr("INTERNAL  |  DO NOT REPLY"), HORIZONTAL_ALIGNMENT_RIGHT, w - 56, 14, Color(INK, 0.6))
	_paper.draw_line(Vector2(28, 66), Vector2(w - 28, 66), INK, 2.0)
	_paper.draw_string(FONT, Vector2(28, 92), tr("TO: DESK 4     FROM: MANAGEMENT     RE: ") + tr(_memo.re), HORIZONTAL_ALIGNMENT_LEFT, w - 56, 16, Color(INK, 0.8))
	_paper.draw_string(FONT, Vector2(28, 132), tr(_memo.note), HORIZONTAL_ALIGNMENT_LEFT, w - 56, 21, INK)
	var line: String = tr("Effective immediately: ") + tr(_memo.bonus) if _memo.has("bonus") else tr(NO_BONUS)
	_paper.draw_string(FONT, Vector2(28, 168), line, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 21, INK)
	_paper.draw_line(Vector2(28, 196), Vector2(w - 28, 196), Color(INK, 0.3), 1.0)
	_paper.draw_string(FONT, Vector2(28, 222), tr("Retain for your records. Records are retained regardless."), HORIZONTAL_ALIGNMENT_LEFT, w - 56, 13, Color(INK, 0.55))


## The mouse on (1) or off (0) the folder: it eases open or shut, a paper rustle as it opens.
func _on_folder_hover(to: float) -> void:
	_hovered = to
	if to > 0.5:
		$Rustle.play()
	_hover_to(to)


## Eases the folder's hover towards `to` (1 open, 0 rest), then calls `then` if given.
func _hover_to(to: float, then := Callable()) -> void:
	if _hovering != null:
		_hovering.kill()
	_hovering = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hovering.tween_method(_set_hover, _hover, to, HOVER_TIME)
	if then.is_valid():
		_hovering.tween_callback(then)


## Poses the folder `h` of the way open: the cover tips up about its back edge, the papers rise,
## the whole folder grows a little.
func _set_hover(h: float) -> void:
	_hover = h
	_skeleton.set_bone_pose_rotation(_cover, Quaternion(Vector3.RIGHT, -COVER_OPEN * h))
	_skeleton.set_bone_pose_position(_papers, _skeleton.get_bone_rest(_papers).origin + Vector3.UP * PAPERS_RISE * h)
	_folder_model.scale = Vector3.ONE * (1.0 + HOVER_GROW * h)


## The shade's header: what this is and how much of it is filed.
func _draw_shade() -> void:
	var w := _shade.size.x
	_shade.draw_string(FONT, Vector2(0, 70), tr("PERSONNEL FILE  |  DESK 4"), HORIZONTAL_ALIGNMENT_CENTER, w, 40, PAPER)
	# The close button: a dark stamped square with an X, as on the projector.
	var close := _close_rect()
	_shade.draw_rect(close, Color(INK, 0.9))
	var x := close.grow(-12.0)
	_shade.draw_line(x.position, x.end, PAPER, 3.0, true)
	_shade.draw_line(Vector2(x.end.x, x.position.y), Vector2(x.position.x, x.end.y), PAPER, 3.0, true)


## One memo's card: its icon in a box on the left, title, how to file it, and the bonus (or, once
## filed, its note). Not yet filed: grey paper.
func _draw_card(card: Control, m: Dictionary) -> void:
	var filed := Profile.filed().has(m.id)
	var secret := hidden(m, Profile.filed(), Profile.reached())
	var ink := INK if filed else Color(INK, 0.75)
	card.draw_rect(Rect2(Vector2(6, 6), CARD), Color(0, 0, 0, 0.4))
	card.draw_rect(Rect2(Vector2.ZERO, CARD), PAPER if filed else PAPER.darkened(0.4))
	var box := Rect2(16, 16, CARD.y - 32, CARD.y - 32)
	card.draw_rect(box, Color(INK, 0.1))
	card.draw_rect(box, Color(INK, 0.45), false, 2.0)
	_draw_icon(card, "?" if secret else m.icon, box.get_center(), box.size.x * 0.32, ink, filed)
	var x := box.end.x + 18.0
	var w := CARD.x - x - 18.0
	if secret:
		card.draw_string(FONT, Vector2(x, 42), "?", HORIZONTAL_ALIGNMENT_LEFT, w, 24, ink)
		return
	card.draw_string(FONT, Vector2(x, 42), tr(m.re), HORIZONTAL_ALIGNMENT_LEFT, w, 24, ink)
	card.draw_multiline_string(BODY_FONT, Vector2(x, 72), tr(m.how), HORIZONTAL_ALIGNMENT_LEFT, w, 17, 2, Color(ink, 0.85))
	var foot: String = tr("Effective: ") + tr(m.bonus) if m.has("bonus") else (tr(m.note) if filed else "")
	card.draw_multiline_string(FONT, Vector2(x, 122), foot, HORIZONTAL_ALIGNMENT_LEFT, w, 15, 2, Color(ink, 0.7))


## A signed boss report `r` as a card in the FILES: its headline and its whole text.
func _draw_report(card: Control, r: Dictionary) -> void:
	card.draw_rect(Rect2(Vector2(6, 6), REPORT_CARD), Color(0, 0, 0, 0.4))
	card.draw_rect(Rect2(Vector2.ZERO, REPORT_CARD), PAPER)
	var w := REPORT_CARD.x - 36.0
	card.draw_string(FONT, Vector2(18, 30), tr("MEMORANDUM"), HORIZONTAL_ALIGNMENT_LEFT, w, 16, Color(INK, 0.6))
	card.draw_multiline_string(FONT, Vector2(18, 66), tr(r.re), HORIZONTAL_ALIGNMENT_LEFT, w, 30, 2, INK)
	card.draw_line(Vector2(18, 108), Vector2(REPORT_CARD.x - 18, 108), Color(INK, 0.4), 1.5)
	card.draw_multiline_string(BODY_FONT, Vector2(18, 144), tr(r.body), HORIZONTAL_ALIGNMENT_LEFT, w, 22, 9, INK)


## Simple glyphs on `item`, centred on `at`, about `s` from the centre to the edge. The cabbage
## glyphs turn green and research cyan once `lit` (filed).
static func _draw_icon(item: CanvasItem, icon: String, at: Vector2, s: float, ink: Color, lit: bool) -> void:
	match icon:
		"cabbage", "mini":
			# A head seen from above: a ring of outer leaves, the tight core, its veins.
			var r := s * (0.95 if icon == "cabbage" else 0.5)
			var green := CABBAGE if lit else ink
			for i in 6:
				item.draw_circle(at + Vector2.from_angle(i * TAU / 6.0 + 0.3) * r * 0.45, r * 0.55, green.darkened(0.3))
			item.draw_circle(at, r * 0.62, green.lightened(0.15))
			for i in 3:
				var a := i * TAU / 3.0
				item.draw_arc(at + Vector2.from_angle(a) * r * 0.3, r * 0.45, a + PI * 0.6, a + PI * 1.3, 8, green.darkened(0.45), 1.5, true)
			if icon == "mini":
				item.draw_string(FONT, at + Vector2(-s, s * 1.05), "MINI", HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 0.5), ink)
		"research":
			item.draw_circle(at, s * 0.9, CYAN if lit else ink)
			item.draw_arc(at, s * 0.55, 0.0, TAU, 20, Color(INK, 0.5), 2.0, true)
		"coin":
			for i in 3:
				var c := at + Vector2(0, s * (0.5 - i * 0.35))
				item.draw_circle(c, s * 0.8, ink)
				item.draw_arc(c, s * 0.8, 0.0, TAU, 24, Color(PAPER, 0.6), 1.5, true)
			item.draw_string(FONT, at + Vector2(-s, -s * 0.05), "$", HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 0.9), PAPER)
		"catch":
			item.draw_arc(at + Vector2(0, s * 0.9), s * 1.1, PI * 1.1, PI * 1.9, 16, ink, 2.5, true)
			item.draw_circle(at + Vector2(s * 0.75, -s * 0.05), s * 0.3, CABBAGE if lit else ink)
			item.draw_rect(Rect2(at + Vector2(-s * 0.9, s * 0.4), Vector2(s * 0.5, s * 0.5)), ink)
		"window":
			var pane := Rect2(at - Vector2(s, s) * 0.85, Vector2(s, s) * 1.7)
			item.draw_rect(pane, ink, false, 3.0)
			item.draw_line(Vector2(at.x, pane.position.y), Vector2(at.x, pane.end.y), ink, 2.5)
			item.draw_line(Vector2(pane.position.x, at.y), Vector2(pane.end.x, at.y), ink, 2.5)
		"hand":
			item.draw_rect(Rect2(at + Vector2(-s * 0.5, -s * 0.15), Vector2(s, s * 0.85)), ink)
			for i in 4:
				var tall := s * (0.55 if i in [0, 3] else 0.7)
				item.draw_rect(Rect2(at + Vector2(-s * 0.5 + i * s * 0.26, -s * 0.15 - tall), Vector2(s * 0.2, tall)), ink)
		"lens":
			item.draw_arc(at + Vector2(-s * 0.2, -s * 0.2), s * 0.55, 0.0, TAU, 20, ink, 3.0, true)
			item.draw_line(at + Vector2(s * 0.2, s * 0.2), at + Vector2(s * 0.85, s * 0.85), ink, 5.0)
		"stamp":
			item.draw_rect(Rect2(at + Vector2(-s * 0.2, -s * 0.9), Vector2(s * 0.4, s * 0.8)), ink)
			item.draw_rect(Rect2(at + Vector2(-s * 0.75, -s * 0.15), Vector2(s * 1.5, s * 0.45)), ink)
			item.draw_line(at + Vector2(-s * 0.9, s * 0.75), at + Vector2(s * 0.9, s * 0.75), STAMP, 3.0)
		"lever":
			item.draw_rect(Rect2(at + Vector2(-s * 0.8, s * 0.45), Vector2(s * 1.6, s * 0.4)), ink)
			item.draw_line(at + Vector2(0, s * 0.5), at + Vector2(s * 0.55, -s * 0.75), ink, 4.0)
			item.draw_circle(at + Vector2(s * 0.55, -s * 0.75), s * 0.22, ink)
		"bin":
			item.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.7, -s * 0.6), at + Vector2(s * 0.7, -s * 0.6),
					at + Vector2(s * 0.5, s * 0.85), at + Vector2(-s * 0.5, s * 0.85)]), ink)
			item.draw_rect(Rect2(at + Vector2(-s * 0.85, -s * 0.85), Vector2(s * 1.7, s * 0.18)), ink)
		"chart":
			for i in 4:
				var tall := s * (0.45 + i * 0.4)
				item.draw_rect(Rect2(at + Vector2(-s * 0.9 + i * s * 0.48, s * 0.85 - tall), Vector2(s * 0.34, tall)), ink)
		"radio":
			item.draw_rect(Rect2(at + Vector2(-s * 0.9, -s * 0.45), Vector2(s * 1.8, s * 1.2)), ink)
			item.draw_circle(at + Vector2(-s * 0.35, s * 0.15), s * 0.32, PAPER.darkened(0.3))
			item.draw_line(at + Vector2(s * 0.5, -s * 0.45), at + Vector2(s * 0.9, -s * 1.0), ink, 2.5)
		"field":
			# Farm squares from above, one of them growing.
			for i in 9:
				var c := at + Vector2((i % 3 - 1) * s * 0.62, (floori(i / 3.0) - 1) * s * 0.62)
				item.draw_rect(Rect2(c - Vector2(s, s) * 0.26, Vector2(s, s) * 0.52), ink, false, 2.0)
			item.draw_circle(at, s * 0.2, CABBAGE if lit else PAPER.darkened(0.3))
		"tv":
			item.draw_rect(Rect2(at + Vector2(-s * 0.95, -s * 0.6), Vector2(s * 1.9, s * 1.3)), ink, false, 3.0)
			item.draw_rect(Rect2(at + Vector2(-s * 0.7, -s * 0.38), Vector2(s * 1.1, s * 0.86)), ink)
			item.draw_circle(at + Vector2(s * 0.68, -s * 0.2), s * 0.1, ink)
			item.draw_line(at + Vector2(-s * 0.3, -s * 0.6), at + Vector2(-s * 0.65, -s * 1.0), ink, 2.0)
			item.draw_line(at + Vector2(s * 0.1, -s * 0.6), at + Vector2(s * 0.45, -s * 1.0), ink, 2.0)
		"globe":
			item.draw_arc(at, s * 0.9, 0.0, TAU, 28, ink, 3.0, true)
			item.draw_line(at + Vector2(-s * 0.9, 0), at + Vector2(s * 0.9, 0), ink, 2.0)
			item.draw_line(at + Vector2(0, -s * 0.9), at + Vector2(0, s * 0.9), ink, 2.0)
			item.draw_arc(at + Vector2(0, -s * 0.9), s * 0.95, PI * 0.3, PI * 0.7, 10, ink, 2.0, true)
			item.draw_arc(at + Vector2(0, s * 0.9), s * 0.95, PI * 1.3, PI * 1.7, 10, ink, 2.0, true)
		"target":
			item.draw_arc(at, s * 0.85, 0.0, TAU, 28, ink, 3.0, true)
			item.draw_arc(at, s * 0.4, 0.0, TAU, 20, ink, 2.0, true)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				item.draw_line(at + d * s * 0.55, at + d * s * 1.05, ink, 2.5)
		"clock":
			item.draw_arc(at, s * 0.85, 0.0, TAU, 28, ink, 3.0, true)
			item.draw_line(at, at + Vector2(0, -s * 0.6), ink, 3.0)
			item.draw_line(at, at + Vector2(s * 0.45, 0), ink, 3.0)
		"?":
			item.draw_string(FONT, at + Vector2(-s, s * 0.45), "?", HORIZONTAL_ALIGNMENT_CENTER, s * 2.0, int(s * 1.6), ink)
		"tree":
			var nodes := [at + Vector2(0, -s * 0.6), at + Vector2(-s * 0.65, s * 0.55), at + Vector2(s * 0.65, s * 0.55)]
			for n: Vector2 in nodes.slice(1):
				item.draw_line(nodes[0], n, ink, 2.5)
			for n: Vector2 in nodes:
				item.draw_circle(n, s * 0.28, ink)
		"flag":
			# A pennant on a pole in a little mound, as the war maps plant them.
			item.draw_line(at + Vector2(-s * 0.45, s * 0.8), at + Vector2(-s * 0.45, -s * 0.9), ink, 3.0)
			item.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.45, -s * 0.9), at + Vector2(s * 0.85, -s * 0.55),
					at + Vector2(-s * 0.45, -s * 0.2)]), ink)
			item.draw_rect(Rect2(at + Vector2(-s * 0.9, s * 0.7), Vector2(s * 1.0, s * 0.2)), ink)
