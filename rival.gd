extends RefCounted
## Grannen i duellen: studsar på sin egen rosa studsmatta och gör trick av sig själv. Storebror
## ger henne poänglappar precis som spelaren. `skill` gör henne lite bättre för varje vunnen duell.

const Game := preload("res://game.gd")
const Data := preload("res://data.gd")

## Tricken hon kan: [namn, grundbetyg, vikt]. Tomt namn = ett vanligt hopp utan lapp.
const MOVES := [["", 0, 9], ["STJÄRNHOPP", 4, 3], ["RUMPSTUDS", 4, 2], ["VOLT BAKÅT", 6, 2],
	["SNURR 360", 5, 2], ["KANONKULAN", 4, 2], ["DUBBELVOLT", 8, 1]]

var skill := 0.0
var phase := "sta"              # sta | luft | duk
var y := 0.0
var vy := 0.0
var air := 0.0                  # sekunder i luften
var air_dur := 1.0
var duk_t := 0.0
var dip := 0.0
var hojd := 2
var move := 0                   # index i MOVES
var pose := "sta"
var rot := 0.0
var sx := 1.0
var score := 0
var card := 0
var card_t := 0.0
var line := ""
var line_t := 0.0
var popups: Array = []
var sounds: Array = []
var wait := 1.2                 # hon börjar en liten stund efter spelaren


func update(dt: float) -> void:
	card_t = maxf(0.0, card_t - dt)
	line_t = maxf(0.0, line_t - dt)
	for p in popups:
		p.t += dt
	popups = popups.filter(func(p): return p.t < 1.4)
	match phase:
		"sta":
			pose = "sta"
			wait -= dt
			if wait <= 0.0:
				_launch()
		"luft":
			air += dt
			vy -= Game.G * dt
			y += vy * dt
			var k := clampf((air / air_dur - 0.15) / 0.65, 0.0, 1.0)
			rot = 0.0
			sx = 1.0
			pose = "upp" if vy > 0 else "sta"
			match MOVES[move][0]:
				"STJÄRNHOPP":
					if k > 0.0 and k < 1.0: pose = "stjarna"
				"RUMPSTUDS":
					if vy < 0: pose = "rumpa"
				"VOLT BAKÅT":
					rot = -TAU * k
					if k > 0.0 and k < 1.0: pose = "boll"
				"DUBBELVOLT":
					rot = TAU * 2.0 * k
					if k > 0.0 and k < 1.0: pose = "boll"
				"SNURR 360":
					sx = cos(k * TAU)
				"KANONKULAN":
					if k > 0.0 and k < 1.0: pose = "boll"
			if y <= 0.0 and vy < 0.0:
				_land()
		"duk":
			duk_t += dt
			dip = sin(PI * clampf(duk_t / Game.DUK, 0, 1)) * (4.0 + hojd * 1.6)
			if duk_t >= Game.DUK:
				_launch()


func _launch() -> void:
	hojd = clampi(hojd + [-1, 0, 1, 1].pick_random(), 1, 4)
	vy = sqrt(2.0 * Game.G * Game.HEIGHTS[hojd])
	air_dur = 2.0 * vy / Game.G
	air = 0.0
	y = 0.0
	phase = "luft"
	# välj ett trick efter vikterna; dubbelvolt bara från höga hopp
	var total := 0
	for m in MOVES:
		total += m[2]
	var r := randi() % total
	move = 0
	for i in MOVES.size():
		r -= MOVES[i][2]
		if r < 0:
			move = i
			break
	if MOVES[move][0] == "DUBBELVOLT" and hojd < 3:
		move = 3
	sounds.append("studs")


func _land() -> void:
	y = 0.0
	phase = "duk"
	duk_t = 0.0
	pose = "rumpa" if MOVES[move][0] == "RUMPSTUDS" else "huka"
	rot = 0.0
	sx = 1.0
	if move == 0:
		return
	card = clampi(int(MOVES[move][1]) + randi_range(-2, 2) + int(round(skill)) + (1 if hojd >= 4 else 0), 1, 10)
	card_t = 1.5
	score += card
	popups.append({"text": MOVES[move][0], "t": 0.0, "col": Color("#ff8ac8"), "n": popups.size()})
	if randf() < 0.3:
		line = Data.REPLIKER.granne.pick_random()
		line_t = 1.4
	sounds.append("lapp")
