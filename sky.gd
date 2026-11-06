extends RefCounted
## Himlen bakom trädgården: dygnet (soluppgång, dag, solnedgång, natt), sol, måne och stjärnor,
## moln som driver, fåglar, ett flygplan ibland, och vädret: sol, moln, regn, snö eller storm med
## blixtar. `wind` (-1..1, negativt = blåser åt vänster) läses av allt som fladdrar.

const W := 320.0
const H := 180.0
## Himlens färg (topp, horisont) vid olika klockslag.
const SKY := [
	[0.0, Color("#0a0c24"), Color("#1c1a44")],
	[4.5, Color("#101436"), Color("#2a2456")],
	[6.0, Color("#3a3c7a"), Color("#f08a5a")],
	[7.5, Color("#5aa0e8"), Color("#ffd2a0")],
	[10.0, Color("#3c8ae8"), Color("#a8d8ff")],
	[16.5, Color("#3c8ae8"), Color("#a8d8ff")],
	[19.0, Color("#4a5ab0"), Color("#ff9a4a")],
	[20.5, Color("#2a2460"), Color("#d0506a")],
	[22.0, Color("#0e1030"), Color("#2a2050")],
	[24.0, Color("#0a0c24"), Color("#1c1a44")],
]

var hour := 12.0
var weather := "sol"
var wind := 0.1              # -1..1
var wind_target := 0.1
var clouds: Array = []       # {x, y, w, speed, dark}
var birds: Array = []        # {x, y, n, dir, t}
var plane := {}              # {x, y, dir}
var drops: Array = []        # regn eller snö {x, y, v}
var stars: Array = []
var flash := 0.0             # blixt (vitt över skärmen)
var bolt: Array = []         # blixtens punkter
var thunder_in := -1.0       # sekunder kvar till åskan hörs
var next_bolt := 4.0
var t := 0.0
var events: Array = []       # ljud att spela: "aska"


func _init() -> void:
	for i in 40:
		stars.append(Vector2(randf() * W, randf() * 90.0))


func setup(h: float, w: String) -> void:
	hour = h
	weather = w
	clouds.clear()
	var n: int = {"sol": 3, "moln": 7, "regn": 9, "sno": 8, "storm": 11}[w]
	for i in n:
		clouds.append(_cloud(randf() * W))
	wind_target = randf_range(-0.25, 0.35)
	if w == "storm":
		wind_target = 0.9 if randf() < 0.5 else -0.9
	elif w == "regn" or w == "sno":
		wind_target *= 1.6
	wind = wind_target
	drops.clear()
	birds.clear()
	plane = {}


func _cloud(x: float) -> Dictionary:
	return {"x": x, "y": randf_range(8, 60), "w": randf_range(18, 46), "speed": randf_range(0.6, 1.4), "seed": randf() * 10.0}


## Mörker 0..1 (natt = 1).
func night() -> float:
	var h := hour
	if h >= 7.0 and h <= 18.5:
		return 0.0
	if h > 18.5 and h < 21.5:
		return (h - 18.5) / 3.0
	if h > 4.5 and h < 7.0:
		return 1.0 - (h - 4.5) / 2.5
	return 1.0


func gloom() -> float:
	return {"sol": 0.0, "moln": 0.25, "regn": 0.45, "sno": 0.3, "storm": 0.65}[weather]


func update(dt: float, time_speed: float) -> void:
	t += dt
	hour = fposmod(hour + dt * time_speed, 24.0)
	# vinden slår om ibland, och i storm byar
	if randf() < dt * 0.15:
		wind_target = clampf(wind_target + randf_range(-0.4, 0.4), -1.0, 1.0) if weather != "storm" else signf(wind_target) * randf_range(0.6, 1.0)
	var gust := 0.25 * sin(t * 2.3) * (1.0 if weather == "storm" else 0.3)
	wind = lerpf(wind, clampf(wind_target + gust, -1.0, 1.0), dt * 1.5)
	for c in clouds:
		c.x += (6.0 + absf(wind) * 26.0) * signf(wind if wind != 0.0 else 1.0) * c.speed * dt
		if c.x > W + 60:
			c.x = -60
		elif c.x < -60:
			c.x = W + 60
	# fåglar och flygplan
	if birds.is_empty() and weather != "storm" and night() < 0.6 and randf() < dt * 0.12:
		var dir := 1.0 if randf() < 0.5 else -1.0
		birds.append({"x": -30.0 if dir > 0 else W + 30.0, "y": randf_range(20, 60), "n": randi_range(3, 7), "dir": dir})
	for b in birds:
		b.x += b.dir * 22.0 * dt
	birds = birds.filter(func(b): return b.x > -60 and b.x < W + 60)
	if plane.is_empty() and randf() < dt * 0.03:
		var d := 1.0 if randf() < 0.5 else -1.0
		plane = {"x": -20.0 if d > 0 else W + 20.0, "y": randf_range(12, 30), "dir": d}
	if not plane.is_empty():
		plane.x += plane.dir * 14.0 * dt
		if plane.x < -40 or plane.x > W + 40:
			plane = {}
	# regn och snö
	var rate: int = {"sol": 0, "moln": 0, "regn": 90, "sno": 40, "storm": 160}[weather]
	for i in int(rate * dt + randf()):
		drops.append({"x": randf_range(-40, W + 40), "y": -4.0, "v": randf_range(0.8, 1.2)})
	var snow := weather == "sno"
	for d in drops:
		if snow:
			d.y += 18.0 * d.v * dt
			d.x += (wind * 20.0 + sin(t * 2.0 + d.v * 9.0) * 6.0) * dt
		else:
			d.y += 170.0 * d.v * dt
			d.x += wind * 70.0 * dt
	drops = drops.filter(func(d): return d.y < H)
	# blixtar
	flash = maxf(0.0, flash - dt * 4.0)
	if weather == "storm":
		next_bolt -= dt
		if next_bolt <= 0.0:
			next_bolt = randf_range(3.0, 8.0)
			flash = 1.0
			bolt.clear()
			var p := Vector2(randf_range(20, W - 20), 0)
			while p.y < 110:
				bolt.append(p)
				p += Vector2(randf_range(-10, 10), randf_range(8, 16))
			bolt.append(p)
			thunder_in = randf_range(0.2, 0.9)
	if thunder_in >= 0.0:
		thunder_in -= dt
		if thunder_in < 0.0:
			events.append("aska")


func sky_colors() -> Array:
	var h := hour
	for i in SKY.size() - 1:
		var a: Array = SKY[i]
		var b: Array = SKY[i + 1]
		if h >= a[0] and h <= b[0]:
			var k: float = (h - a[0]) / (b[0] - a[0])
			var top: Color = (a[1] as Color).lerp(b[1], k)
			var hor: Color = (a[2] as Color).lerp(b[2], k)
			var grey := Color("#5a6070").lerp(Color("#202630"), night())
			return [top.lerp(grey, gloom() * 0.8), hor.lerp(grey.lightened(0.15), gloom() * 0.8)]
	return [SKY[0][1], SKY[0][2]]


## Himlen i band (8-bit-känsla), stjärnor, sol eller måne, moln, fåglar och flygplan.
func draw_back(c: CanvasItem) -> void:
	var cols := sky_colors()
	var bands := 14
	for i in bands:
		var k := float(i) / (bands - 1)
		c.draw_rect(Rect2(0, i * 9.0, W, 9.0), (cols[0] as Color).lerp(cols[1], k))
	var nt := night()
	if nt > 0.2:
		for i in stars.size():
			var s: Vector2 = stars[i]
			if fmod(t * 0.7 + i * 1.3, 4.0) > 0.4:
				c.draw_rect(Rect2(s, Vector2.ONE), Color(1, 1, 0.9, (nt - 0.2) * (1.0 - gloom())))
	# solen går i en båge från 5 till 21, månen resten av dygnet
	var day := clampf((hour - 5.0) / 16.0, 0.0, 1.0)
	if hour > 5.0 and hour < 21.0 and gloom() < 0.6:
		var sp := Vector2(lerpf(-10, W + 10, day), 110 - sin(day * PI) * 92)
		var sc := Color("#ffe060").lerp(Color("#ff7a30"), 1.0 - sin(day * PI))
		c.draw_circle(sp, 12, Color(sc, 0.25))
		c.draw_circle(sp, 8, sc)
	else:
		var mk := fposmod(hour - 21.0, 24.0) / 8.0
		var mp := Vector2(lerpf(20, W - 20, mk), 70 - sin(mk * PI) * 45)
		c.draw_circle(mp, 6, Color("#f4f0d0"))
		c.draw_circle(mp + Vector2(3, -2), 5, (cols[0] as Color))       # månskära
	if not plane.is_empty():
		var p := Vector2(plane.x, plane.y)
		c.draw_rect(Rect2(p - Vector2(4, 0), Vector2(9, 2)), Color("#d8dce8"))
		c.draw_rect(Rect2(p + Vector2(-1 * plane.dir, -2), Vector2(2, 5)), Color("#b8bcc8"))
		if fmod(t, 1.0) < 0.5:
			c.draw_rect(Rect2(p + Vector2(5 * plane.dir, 0), Vector2.ONE), Color("#ff3030"))
	for b in birds:
		for k in b.n:
			var row: int = (k + 1) / 2
			var side: int = 1 if k % 2 else -1
			var bp := Vector2(b.x - b.dir * row * 7.0, b.y + row * 4.0 * side + (0 if k == 0 else 0))
			var flap := sin(t * 10.0 + k) > 0
			var wing := Color("#202028") if nt < 0.6 else Color("#606070")
			c.draw_line(bp + Vector2(-3, -1 if flap else 1), bp, wing)
			c.draw_line(bp, bp + Vector2(3, -1 if flap else 1), wing)
	var cloud_col := Color("#ffffff").lerp(Color("#6a7080"), gloom()).lerp(Color("#3a3c58"), nt * 0.7)
	for cl in clouds:
		_draw_cloud(c, cl, cloud_col)


func _draw_cloud(c: CanvasItem, cl: Dictionary, col: Color) -> void:
	var x: float = cl.x
	var y: float = cl.y
	var w: float = cl.w
	var dark := col.darkened(0.18)
	for k in 5:
		var px := x - w * 0.5 + w * k / 4.0
		var r := w * (0.16 + 0.1 * sin(cl.seed + k * 1.7))
		c.draw_circle(Vector2(px, y + 2), r, dark)
	for k in 5:
		var px := x - w * 0.5 + w * k / 4.0
		var r := w * (0.14 + 0.1 * sin(cl.seed + k * 1.7))
		c.draw_circle(Vector2(px, y), r, col)


## Regn, snö och blixtar, ovanpå trädgården.
func draw_front(c: CanvasItem) -> void:
	if weather == "sno":
		for d in drops:
			c.draw_rect(Rect2(d.x, d.y, 1, 1), Color("#ffffff"))
	elif weather == "regn" or weather == "storm":
		var slant := Vector2(wind * 3.0, 4.0)
		for d in drops:
			c.draw_line(Vector2(d.x, d.y), Vector2(d.x, d.y) + slant, Color(0.7, 0.8, 1.0, 0.7))
	if flash > 0.0:
		if flash > 0.6 and bolt.size() > 1:
			c.draw_polyline(PackedVector2Array(bolt), Color("#fffbd0"), 2.0)
		c.draw_rect(Rect2(-200, 0, W + 400, H), Color(1, 1, 1, flash * 0.55))
