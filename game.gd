extends RefCounted
## En runda på trampolinen: studsen, tricken, landningen, poängen och föräldern som tittar.
## main.gd skickar knapptryck (press) och vilka riktningar som hålls (held), och ritar resultatet.

const Data := preload("res://data.gd")

const MAT_Y := 140.0            # dukens höjd på skärmen
const CX := 150.0               # trampolinens mitt
const G := 420.0                # tyngdkraft, pixlar/s²
const HEIGHTS := [24.0, 38.0, 54.0, 70.0, 88.0]   # hoppets höjd vid varje studsnivå
const DUK := 0.17               # hur länge barnet är nere i duken
const WINDOW := 0.14            # hur långt innan landningen ett STUDS-tryck räknas
const ROUND := 60.0

var kid := 0
var par := 0
var level := 1                  # spelarens nivå (vilka trick som är upplåsta)

var phase := "sta"              # sta | luft | duk | krasch | slut
var y := 0.0                    # höjd över duken
var vy := 0.0
var hojd := 0                   # studsnivå 0..4
var duk_t := 0.0
var dip := 0.0
var last_studs := -10.0
var clock := 0.0                # sekunder sedan rundan började
var time_left := ROUND
var crash_t := 0.0

# trick i luften
var cur := ""                   # tricket som pågår
var cur_t := 0.0
var cur_dur := 0.0
var rot := 0.0                  # volternas rotation
var spin := 0.0                 # snurr (0..varv)
var done: Array = []            # trick klara i det här hoppet
var buffer: Array = []          # [riktning, tid] tryckta i luften
var pose := "sta"
var land_style := ""            # hur barnet landade: rumpa, kna, mage, rygg eller ""

# landningar och poäng
var rumpkedja := 0
var styles: Array = []          # senaste landningssätten (för rumpa-mage-rygg)
var history: Array = []         # trick i de senaste hoppen
var total := 0                  # trickpoäng under rundan (blir XP)
var cards: Array = []           # förälderns poänglappar
var attention := 0.7            # 0..1: tittar föräldern, eller är det mobilen?
var best_jump := 0

# vad som syns och hörs
var popups: Array = []          # {text, t, col}
var line := ""                  # förälderns replik
var line_t := 0.0
var kid_line := ""              # barnets egen replik
var kid_line_t := 0.0
var card := 0
var card_t := 0.0
var react := "tittar"
var react_t := 0.0
var perfect_t := 0.0
var sounds: Array = []
var weather := "sol"
# duellen mot grannen: storebror dömer, ingen tid, först till Data.DUELL_MAL poäng
var duel := false
var poang := 0                  # storebrors poänglappar ihop


func start(k: int, p: int, lvl: int, w: String) -> void:
	kid = k
	par = p
	level = lvl
	weather = w
	phase = "sta"
	time_left = ROUND if not duel else INF


func unlocked(id: String) -> bool:
	return Data.TRICKS[id].niva <= level


# ================================================================ inmatning
func press(btn: String, held: Dictionary) -> void:
	match btn:
		"studs":
			last_studs = clock
			if phase == "sta":
				phase = "duk"
				duk_t = 0.0
				hojd = 0
				sounds.append("studs")
		"trick":
			if phase == "luft":
				_start_trick(held)
		"upp", "ned", "vanster", "hoger":
			if phase == "luft":
				buffer.append([btn, clock])


func _start_trick(held: Dictionary) -> void:
	var id := ""
	var recent := buffer.filter(func(b): return clock - b[1] < 0.6)
	var dirs: Array = recent.map(func(b): return b[0])
	if dirs.size() >= 2 and dirs[-2] == "hoger" and dirs[-1] == "hoger":
		id = "superman"
	elif dirs.size() >= 2 and dirs[-2] == "ned" and dirs[-1] == "upp":
		id = "pannkaka"
	elif held.get("vanster"):
		id = "volt_bak"
	elif held.get("hoger"):
		id = "volt_fram"
	elif held.get("upp"):
		id = "snurr"
	elif held.get("ned"):
		id = "kanonkula"
	else:
		id = "stjarna"
	if id in ["superman", "pannkaka"] and not unlocked(id):
		id = "volt_fram" if id == "superman" else "snurr"
	# samma volt eller snurr igen mitt i: dubbel-, trippelvolt och helikoptern
	if cur != "":
		var up := ""
		if (cur == "volt_bak" or cur == "volt_fram") and id == cur:
			up = "dubbelvolt"
		elif cur == "dubbelvolt" and (id == "volt_bak" or id == "volt_fram"):
			up = "trippelvolt"
		elif cur == "snurr" and id == "snurr":
			up = "helikopter"
		if up != "" and unlocked(up):
			var dir := signf(rot) if rot != 0.0 else 1.0
			cur = up
			cur_dur = Data.TRICKS[up].tid
			buffer.clear()
			sounds.append("trick")
			if up == "dubbelvolt" or up == "trippelvolt":
				set_meta("dir", dir)
		return
	if not unlocked(id):
		_popup("LÅST TRICK", Color("#a0a0a0"))
		return
	cur = id
	cur_t = 0.0
	cur_dur = Data.TRICKS[id].tid
	set_meta("dir", -1.0 if id == "volt_bak" else 1.0)
	buffer.clear()
	sounds.append("trick")


# ================================================================ varje bildruta
func update(dt: float, held: Dictionary) -> void:
	clock += dt
	if phase != "sta" and phase != "slut":
		time_left = maxf(0.0, time_left - dt)
	attention = clampf(attention - dt * 0.05, 0.0, 1.0) if not duel else 1.0
	perfect_t = maxf(0.0, perfect_t - dt)
	line_t = maxf(0.0, line_t - dt)
	kid_line_t = maxf(0.0, kid_line_t - dt)
	card_t = maxf(0.0, card_t - dt)
	react_t = maxf(0.0, react_t - dt)
	for p in popups:
		p.t += dt
	popups = popups.filter(func(p): return p.t < 1.4)
	if react_t <= 0.0:
		react = "mobil" if attention < 0.15 else ("gapar" if phase == "luft" and hojd >= 3 else "tittar")
	match phase:
		"sta":
			pose = "sta"
			dip = 0.0
		"luft":
			vy -= G * dt
			y += vy * dt
			if cur != "":
				cur_t += dt
				var dir: float = get_meta("dir", 1.0)
				var tr: Dictionary = Data.TRICKS[cur]
				if tr.has("varv"):
					rot = dir * TAU * tr.varv * minf(1.0, cur_t / cur_dur)
				if tr.has("snurr"):
					spin = tr.snurr * minf(1.0, cur_t / cur_dur)
				if cur_t >= cur_dur:
					done.append(cur)
					cur = ""
					rot = 0.0
					spin = 0.0
			pose = _air_pose(held)
			if y <= 0.0 and vy < 0.0:
				_land(held)
		"duk":
			pose = {"rumpa": "rumpa", "kna": "kna", "mage": "ligg", "rygg": "ligg"}.get(land_style, "huka")
			duk_t += dt
			dip = sin(PI * clampf(duk_t / DUK, 0, 1)) * (4.0 + hojd * 1.6)
			if duk_t >= DUK:
				_launch()
		"krasch":
			crash_t += dt
			dip = maxf(0.0, dip - dt * 20)
			pose = "krasch"
			if crash_t > 1.1:
				if time_left <= 0.0:
					phase = "slut"
				else:
					phase = "duk"
					duk_t = 0.0
					hojd = 0


func _air_pose(held: Dictionary) -> String:
	match cur:
		"stjarna": return "stjarna"
		"kanonkula", "volt_bak", "volt_fram", "dubbelvolt", "trippelvolt": return "boll"
		"superman": return "superman"
		"pannkaka": return "stjarna"
		"snurr", "helikopter": return "upp"
	if vy < -60 and y < 22:
		if held.get("ned") and unlocked("rumpa"): return "rumpa"
		if held.get("vanster") and unlocked("kna"): return "kna"
		if held.get("hoger") and unlocked("mage"): return "ligg"
		if held.get("upp") and unlocked("rygg"): return "ligg"
	return "upp" if vy > 0 else "sta"


func _launch() -> void:
	var timed := clock - last_studs <= DUK + WINDOW
	if timed:
		hojd = mini(4, hojd + 1)
		perfect_t = 0.5
	else:
		hojd = maxi(0, hojd - 1)
	vy = sqrt(2.0 * G * HEIGHTS[hojd])
	y = 0.0
	phase = "luft"
	land_style = ""
	done.clear()
	buffer.clear()
	cur = ""
	rot = 0.0
	spin = 0.0
	sounds.append("studs")


func _land(held: Dictionary) -> void:
	y = 0.0
	if cur != "":                     # mitt i ett trick: krasch
		phase = "krasch"
		land_style = ""
		crash_t = 0.0
		dip = 10.0
		rumpkedja = 0
		cur = ""
		rot = 0.0
		spin = 0.0
		sounds.append("krasch")
		_say(Data.REPLIKER["bror_krasch" if duel else "krasch"].pick_random())
		card = 0
		card_t = 1.4
		cards.append(0)
		react = "gapar"
		react_t = 1.2
		attention = minf(1.0, attention + 0.2)
		_popup("AJ!", Color("#ff5a4a"))
		history.append([])
		return
	var style := ""
	if held.get("ned") and unlocked("rumpa"): style = "rumpa"
	elif held.get("vanster") and unlocked("kna"): style = "kna"
	elif held.get("hoger") and unlocked("mage"): style = "mage"
	elif held.get("upp") and unlocked("rygg"): style = "rygg"
	land_style = style
	var ids: Array = done.duplicate()
	if style != "":
		ids.append(style)
	rumpkedja = rumpkedja + 1 if style == "rumpa" else 0
	styles.append(style)
	if styles.size() > 3:
		styles.pop_front()
	if styles == ["rumpa", "mage", "rygg"] and unlocked("rmr"):
		ids.append("rmr")
		styles.clear()
	if ids.is_empty():
		ids = ["rakt"]
	# poängen
	var pts := 0.0
	var stale := 0
	for id in ids:
		var base: float = Data.TRICKS[id].poang
		if id == "rumpa":
			pts += base * rumpkedja                 # rumpstudsar i rad blir bara roligare
			continue
		var seen := 0
		for h in history.slice(-5):
			if id in h:
				seen += 1
		stale = maxi(stale, seen)
		pts += base * pow(0.6, seen)
	var distinct := ids.filter(func(i): return i != "rakt").size()
	if distinct >= 2:
		pts *= 1.0 + 0.3 * (distinct - 1)
	pts *= 1.0 + 0.2 * hojd
	var likes: Array = Data.PARENTS[par].gillar if not duel else []
	for id in ids:
		if id in likes:
			pts *= 1.2
			break
	var looking := attention >= 0.15
	if not looking:
		pts *= 0.5
	var p := int(round(pts))
	total += p
	best_jump = maxi(best_jump, p)
	history.append(ids)
	if history.size() > 8:
		history.pop_front()
	for id in ids:
		if id != "rakt":
			_popup(Data.TRICKS[id].namn + (" x%d" % rumpkedja if id == "rumpa" and rumpkedja > 1 else ""), Color("#ffe14d"))
	if ids != ["rakt"]:
		_popup("+%d" % p, Color.WHITE)
	# föräldern reagerar och håller upp en lapp
	sounds.append("rumpa" if style == "rumpa" else "land")
	if style == "rumpa":
		kid_line = "DET ÄR ETT TRICK!"
		kid_line_t = 1.3
		sounds.append("ett_trick")
	if ids == ["rakt"]:
		attention = maxf(0.0, attention - 0.08)
		if randf() < 0.2:
			_say(Data.REPLIKER["bror_lag" if duel else ("lag" if looking else "mobil")].pick_random())
	else:
		card = clampi(int(round(pts / (24.0 if duel else 16.0))), 1, 10)
		poang += card if duel else 0
		card_t = 1.5
		cards.append(card)
		attention = clampf(attention + card * 0.06, 0.0, 1.0)
		react = "kort"
		react_t = 1.2
		var say := ""
		if duel:
			var bk := "bror_lag" if card <= 3 else ("bror_mellan" if card <= 6 else ("bror_hog" if card <= 9 else "bror_tio"))
			if style == "rumpa" and rumpkedja >= 2:
				bk = "bror_rumpa"
			elif stale >= 2:
				bk = "bror_rutten"
			say = Data.REPLIKER[bk].pick_random() if randf() < 0.6 else ""
		elif not looking:
			say = Data.REPLIKER.mobil.pick_random()
		elif style == "rumpa" and rumpkedja >= 2:
			say = Data.REPLIKER.rumpa.pick_random()
		elif stale >= 2:
			say = Data.REPLIKER.rutten.pick_random()
		elif weather == "storm" and randf() < 0.15:
			say = Data.REPLIKER.storm.pick_random()
		elif card >= 6 and randf() < 0.3:
			say = Data.REPLIKER[Data.PARENTS[par].namn].pick_random()
		else:
			var key := "lag" if card <= 3 else ("mellan" if card <= 6 else ("hog" if card <= 9 else "tio"))
			say = Data.REPLIKER[key].pick_random()
		if say != "":
			_say(say)
		if card >= 7:
			sounds.append("applad")
		elif card >= 5:
			sounds.append("oj")
		sounds.append("lapp")
	if time_left <= 0.0:
		phase = "slut"
		return
	phase = "duk"
	duk_t = 0.0


func _say(s: String) -> void:
	line = s
	line_t = 1.8


func _popup(s: String, col: Color) -> void:
	popups.append({"text": s, "t": 0.0, "col": col, "n": popups.size()})


func average() -> float:
	if cards.is_empty():
		return 0.0
	var s := 0.0
	for c in cards:
		s += c
	return s / cards.size()
