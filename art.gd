extends RefCounted
## Ritfunktioner i "pappersfigur"-stil: platta färger, svarta konturer, runda huvuden med stora
## ögon och vantar till händer. Bakgrunden ritas i låg upplösning så att den blir pixlig, medan
## figurerna ritas i skärmens fulla upplösning och blir släta. `off` är skärmens förskjutning
## (bredare skärmar har kanter).

const INK := Color("#141018")

## Kroppsställningar: händer och fötter i förhållande till höften, och hur högt kroppen sitter.
const POSES := {
	"sta": {"hands": [Vector2(-8, 3), Vector2(8, 3)], "feet": [Vector2(-3, 11), Vector2(3, 11)], "y": 0.0},
	"upp": {"hands": [Vector2(-8, -10), Vector2(8, -10)], "feet": [Vector2(-3, 11), Vector2(3, 11)], "y": 0.0},
	"huka": {"hands": [Vector2(-9, 1), Vector2(9, 1)], "feet": [Vector2(-4, 8), Vector2(4, 8)], "y": 3.0},
	"stjarna": {"hands": [Vector2(-13, -9), Vector2(13, -9)], "feet": [Vector2(-9, 11), Vector2(9, 11)], "y": 0.0},
	"boll": {"hands": [Vector2(-5, 3), Vector2(5, 3)], "feet": [Vector2(-3, 4), Vector2(3, 4)], "y": -2.0},
	"rumpa": {"hands": [Vector2(-9, 4), Vector2(9, 4)], "feet": [Vector2(-7, 6), Vector2(7, 6)], "y": 5.0},
	"kna": {"hands": [Vector2(-9, -2), Vector2(9, -2)], "feet": [Vector2(-3, 6), Vector2(3, 6)], "y": 4.0},
	"ligg": {"hands": [Vector2(-9, -6), Vector2(9, -6)], "feet": [Vector2(-3, 11), Vector2(3, 11)], "y": 0.0},
	"superman": {"hands": [Vector2(-4, -15), Vector2(4, -15)], "feet": [Vector2(-2, 12), Vector2(2, 12)], "y": 0.0},
	"ga1": {"hands": [Vector2(-7, 5), Vector2(8, 1)], "feet": [Vector2(-6, 11), Vector2(4, 10)], "y": 0.0},
	"ga2": {"hands": [Vector2(-8, 1), Vector2(7, 5)], "feet": [Vector2(-4, 10), Vector2(6, 11)], "y": 0.0},
	"kortV": {"hands": [Vector2(-9, -15), Vector2(8, 3)], "feet": [Vector2(-3, 11), Vector2(3, 11)], "y": 0.0},
	"kortH": {"hands": [Vector2(-8, 3), Vector2(9, -15)], "feet": [Vector2(-3, 11), Vector2(3, 11)], "y": 0.0},
	"kortB": {"hands": [Vector2(-9, -15), Vector2(9, -15)], "feet": [Vector2(-3, 11), Vector2(3, 11)], "y": 0.0},
	"armkors": {"hands": [Vector2(4, -1), Vector2(-4, -1)], "feet": [Vector2(-4, 11), Vector2(4, 11)], "y": 0.0},
	"krasch": {"hands": [Vector2(-11, 2), Vector2(10, -6)], "feet": [Vector2(-8, 9), Vector2(6, 11)], "y": 0.0},
}


static func ellipse(c: CanvasItem, ctr: Vector2, rx: float, ry: float, col: Color, seg := 28) -> void:
	var pts := PackedVector2Array()
	for i in seg:
		var a := TAU * i / seg
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, col)


## En del med svart kontur: först en större svart, sedan färgen.
static func blob(c: CanvasItem, ctr: Vector2, rx: float, ry: float, col: Color) -> void:
	ellipse(c, ctr, rx + 1, ry + 1, INK)
	ellipse(c, ctr, rx, ry, col)


static func limb(c: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 3.0) -> void:
	c.draw_line(a, b, INK, w + 2)
	c.draw_line(a, b, col, w)


# ================================================================ barnet
## pos: var fötterna står (på duken). rot: rotation i luften. sx: -1..1 när barnet snurrar
## (negativt = ryggen mot oss). wind: vinden, lift: hur fort barnet faller (håret flyger upp).
## size: storleken (storebror är större).
static func kid(c: CanvasItem, off: Vector2, k: Dictionary, pos: Vector2, pose: String, rot: float, sx: float,
		wind: float, lift: float, t: float, face := "glad", size := 1.0) -> void:
	var p: Dictionary = POSES.get(pose, POSES.sta)
	var hip := pos + Vector2(0, -11 + p.y) * size
	var sy := 1.0
	if pose == "ligg" or pose == "superman":
		pass
	var back := sx < 0.0
	c.draw_set_transform(off + hip, rot, Vector2(maxf(absf(sx), 0.15), sy) * size)
	var hands: Array = p.hands
	var feet: Array = p.feet
	if pose == "krasch":
		face = "aj"
	# ben och fötter bakom kroppen
	for i in 2:
		limb(c, Vector2(-2.5 + i * 5, 3), feet[i], k.byxor, 3.0)
		blob(c, feet[i] + Vector2(0, 1), 2.6, 1.6, INK)
	# kroppen: en jacka som en kort trapets
	var body := PackedVector2Array([Vector2(-5.5, -6), Vector2(5.5, -6), Vector2(6.5, 4), Vector2(-6.5, 4)])
	var outline := PackedVector2Array([Vector2(-6.5, -7), Vector2(6.5, -7), Vector2(7.5, 5), Vector2(-7.5, 5)])
	c.draw_colored_polygon(outline, INK)
	c.draw_colored_polygon(body, k.jacka)
	if not back:
		c.draw_line(Vector2(0, -5), Vector2(0, 3), (k.jacka as Color).darkened(0.35), 1.0)   # dragkedja
	for i in 2:
		var sh := Vector2(-5 + i * 10, -4)
		limb(c, sh, hands[i], k.jacka, 3.0)
		blob(c, hands[i], 2.2, 2.2, (k.jacka as Color).darkened(0.25))   # vantar
	_head(c, k, Vector2(0, -14), back, wind * (1 if rot == 0.0 else 1), lift, t, face)
	c.draw_set_transform(off)


static func _head(c: CanvasItem, k: Dictionary, h: Vector2, back: bool, wind: float, lift: float, t: float, face: String) -> void:
	var hair: Color = k.harfarg
	var style: String = k.har
	var flutter := sin(t * (6.0 + absf(wind) * 14.0)) * (0.5 + absf(wind) * 1.5)
	var drift := Vector2(wind * 6.0 + flutter, -lift * 4.0)
	# flätor och hästsvans bakom huvudet
	if style == "flator":
		for s in [-1.0, 1.0]:
			var a := h + Vector2(6.5 * s, 2)
			var m := a + Vector2(1.5 * s, 4) + drift * 0.5
			var e := m + Vector2(0.5 * s, 4) + drift
			limb(c, a, m, hair, 3.0)
			limb(c, m, e, hair, 3.0)
			blob(c, e, 1.5, 1.2, Color("#e8423a"))
	elif style == "tofsar":
		# två höga tofsar som spretar åt sidorna
		for s in [-1.0, 1.0]:
			var a := h + Vector2(6.0 * s, -5)
			var e := a + Vector2(5.0 * s, 3) + drift * 0.6
			limb(c, a, e, hair, 4.0)
			blob(c, e + Vector2(0.5 * s, 1), 2.0, 2.4, hair)
			blob(c, a, 1.5, 1.5, k.extra)
	elif style == "svans":
		var a := h + Vector2(0, -7)
		var dir := -1.0 if wind >= 0.0 else 1.0
		var m := a + Vector2(-dir * -0.0 + (wind * 7.0 + flutter) - 4.0 * dir * -1.0, 3) + Vector2(0, -lift * 3.0)
		var e := m + Vector2(wind * 8.0 + flutter * 1.5 + 3.0 * signf(wind if wind != 0.0 else 1.0), 5) + Vector2(0, -lift * 4.0)
		limb(c, a, m, hair, 4.0)
		limb(c, m, e, hair, 3.0)
		blob(c, a + Vector2(0, 0.5), 1.6, 1.3, k.extra)
	blob(c, h, 8.5, 7.5, k.hy)
	if back:
		ellipse(c, h + Vector2(0, -1), 8.5, 6.8, hair if style != "keps" and style != "mossa" else (k.extra as Color))
	else:
		# ögonen: två stora ovaler som möts, pupillerna tittar lite uppåt i luften
		var look := Vector2(0, -0.5 if lift < 0 else 0.5)
		for s in [-1.0, 1.0]:
			blob(c, h + Vector2(2.7 * s, -1), 2.6, 3.0, Color.WHITE)
			if face == "aj":
				c.draw_line(h + Vector2(2.7 * s - 1, -2), h + Vector2(2.7 * s + 1, 0), INK, 1.0)
				c.draw_line(h + Vector2(2.7 * s + 1, -2), h + Vector2(2.7 * s - 1, 0), INK, 1.0)
			else:
				c.draw_rect(Rect2(h + Vector2(2.7 * s - 0.5 + s * 0.6, -1.2) + look, Vector2(1.2, 1.4)), INK)
		match face:
			"oo", "aj":
				blob(c, h + Vector2(0, 4), 1.4, 1.6, Color("#5a1414"))
			"arg", "fnys":
				c.draw_line(h + Vector2(-2.5, 5), h + Vector2(0, 4), INK, 1.0)
				c.draw_line(h + Vector2(0, 4), h + Vector2(2.5, 5), INK, 1.0)
			"flin":
				c.draw_line(h + Vector2(-2.5, 4), h + Vector2(2.5, 3), INK, 1.0)
			"glad":
				c.draw_line(h + Vector2(-2.5, 3.5), h + Vector2(-1, 4.5), INK, 1.0)
				c.draw_line(h + Vector2(-1, 4.5), h + Vector2(1, 4.5), INK, 1.0)
				c.draw_line(h + Vector2(1, 4.5), h + Vector2(2.5, 3.5), INK, 1.0)
			_:
				c.draw_line(h + Vector2(-2, 4), h + Vector2(2, 4), INK, 1.0)
	# frisyren eller huvudbonaden ovanpå
	match style:
		"flator", "svans", "tofsar":
			_cap(c, h, hair, back)
		"keps":
			ellipse(c, h + Vector2(0, -4.5), 8.5, 4.5, INK)
			ellipse(c, h + Vector2(0, -4.5), 7.6, 3.8, k.extra)
			if not back:
				c.draw_rect(Rect2(h + Vector2(-1, -2.5), Vector2(11, 2)), INK)
				c.draw_rect(Rect2(h + Vector2(0, -2.2), Vector2(9.5, 1.2)), (k.extra as Color).darkened(0.2))
			c.draw_rect(Rect2(h + Vector2(-8, -2), Vector2(2, 2)), hair)
		"lockar":
			for i in 9:
				var a := PI + PI * i / 8.0
				blob(c, h + Vector2(cos(a) * 7.5, sin(a) * 6.5 - 1) + Vector2(drift.x * 0.15, 0), 2.4, 2.4, hair)
			if not back:
				for s in [-1.0, 1.0]:
					c.draw_rect(Rect2(h + Vector2(2.7 * s - 2.6, -3.8), Vector2(5.2, 5.6)), INK, false, 1.0)
				c.draw_line(h + Vector2(-0.2, -1), h + Vector2(0.2, -1), INK, 1.0)
		"rufs":
			# kort hår med volym och en lugg som sveper snett över pannan
			_cap(c, h, hair, back)
			if back:
				ellipse(c, h + Vector2(0, -1.5), 9.2, 7.0, hair)
			else:
				var sw := drift.x * 0.15
				var fringe := PackedVector2Array([h + Vector2(-9.2, -1.5), h + Vector2(-7.5, -7.5), h + Vector2(-1, -9.2),
					h + Vector2(6.5, -7.8), h + Vector2(9.2, -3.5), h + Vector2(7.5 + sw, -0.6), h + Vector2(5.0 + sw, -3.2),
					h + Vector2(1.0, -3.6), h + Vector2(-3.5, -3.0), h + Vector2(-6.8, -1.0)])
				var outline := PackedVector2Array()
				for p in fringe:
					outline.append(h + (p - h) * 1.08)
				c.draw_colored_polygon(outline, INK)
				c.draw_colored_polygon(fringe, hair)
				# några mörkare hårslingor som följer luggen
				var dark := hair.darkened(0.35)
				c.draw_polyline(PackedVector2Array([h + Vector2(-6, -6), h + Vector2(-1, -5.5), h + Vector2(4, -4.6), h + Vector2(6.8 + sw, -2.0)]), dark, 0.7)
				c.draw_polyline(PackedVector2Array([h + Vector2(-4, -8), h + Vector2(1.5, -7.6), h + Vector2(6.5, -5.8)]), dark, 0.6)
				c.draw_line(h + Vector2(-8.3, -2), h + Vector2(-8.0, 1.5), hair, 1.4)     # polisonger
				c.draw_line(h + Vector2(8.3, -2), h + Vector2(8.0, 1.5), hair, 1.4)
				c.draw_colored_polygon(PackedVector2Array([h + Vector2(-1, -9.2), h + Vector2(4, -8.8), h + Vector2(2.5, -6.8)]), hair.lightened(0.15))
		"mossa":
			ellipse(c, h + Vector2(0, -4), 9, 5.5, INK)
			ellipse(c, h + Vector2(0, -4), 8.2, 4.8, k.extra)
			c.draw_rect(Rect2(h + Vector2(-8.5, -2), Vector2(17, 2.5)), INK)
			c.draw_rect(Rect2(h + Vector2(-8, -1.6), Vector2(16, 1.8)), (k.extra as Color).lightened(0.3))
			var pom := h + Vector2(0, -10) + Vector2(drift.x * 0.4, -lift * 1.5)
			blob(c, pom, 2.3, 2.3, Color.WHITE)
			if not back:
				c.draw_rect(Rect2(h + Vector2(-5, 0.3), Vector2(4, 1)), hair)
	# arga ögonbryn, ovanpå luggen
	if not back and face in ["arg", "fnys"]:
		for s in [-1.0, 1.0]:
			c.draw_line(h + Vector2(5.5 * s, -6.0), h + Vector2(1.0 * s, -4.0), INK, 1.5)
	# i storm fladdrar några hårstrån
	if absf(wind) > 0.55 and style != "keps" and style != "mossa" and style != "rufs":
		for i in 3:
			var base := h + Vector2(-3 + i * 3, -7)
			c.draw_line(base, base + Vector2(wind * 4 + flutter * (1 + i * 0.3), -2 - i % 2), hair, 1.0)


static func _cap(c: CanvasItem, h: Vector2, hair: Color, back: bool) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(h + Vector2(cos(a) * 9.0, sin(a) * 8.0 - 0.5))
	pts.append(h + Vector2(8.5, -1))
	pts.append(h + Vector2(-8.5, -1))
	c.draw_colored_polygon(pts, INK)
	var inner := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		inner.append(h + Vector2(cos(a) * 8.0, sin(a) * 7.0 - 0.5))
	inner.append(h + Vector2(7.5, -2))
	inner.append(h + Vector2(-7.5, -2))
	c.draw_colored_polygon(inner, hair)
	if not back:
		c.draw_colored_polygon(PackedVector2Array([h + Vector2(-6, -3), h + Vector2(0, -3), h + Vector2(-3, -1)]), hair)   # lugg


# ================================================================ föräldern
## Sitter i en trädgårdsstol, vänd mot trampolinen (åt vänster). state: tittar, gapar,
## klappar, mobil, kort. look: var barnet är. Returnerar var poänglappen ska ritas.
static func parent(c: CanvasItem, off: Vector2, p: Dictionary, pos: Vector2, state: String, look: Vector2, t: float, wind: float) -> Vector2:
	c.draw_set_transform(off)
	var pappa: bool = p.namn == "PAPPA"
	# stolen: en vit plaststol
	var chair := Color("#eeeeea")
	c.draw_rect(Rect2(pos + Vector2(-10, -16), Vector2(22, 4)), INK)
	c.draw_rect(Rect2(pos + Vector2(-9, -15), Vector2(20, 2)), chair)
	c.draw_rect(Rect2(pos + Vector2(8, -40), Vector2(5, 27)), INK)
	c.draw_rect(Rect2(pos + Vector2(9, -39), Vector2(3, 25)), chair)
	for x in [-9, 9]:
		c.draw_line(pos + Vector2(x, -13), pos + Vector2(x - 2, 0), INK, 2)
	# benen: låren vågrätt mot vänster, smalbenen ned
	limb(c, pos + Vector2(4, -17), pos + Vector2(-8, -17), p.byxor, 5)
	limb(c, pos + Vector2(-8, -17), pos + Vector2(-9, -3), p.byxor, 4)
	blob(c, pos + Vector2(-11, -2), 3.5, 2, INK)
	# överkroppen
	var torso := Rect2(pos + Vector2(-4, -33), Vector2(13, 17))
	c.draw_rect(torso.grow(1), INK)
	c.draw_rect(torso, p.trojan)
	var head := pos + Vector2(1, -42)
	var card_at := Vector2.ZERO
	var phone := state == "mobil"
	if phone:
		head += Vector2(-1, 2)
	# armarna
	match state:
		"klappar":
			var k := absf(sin(t * 14.0)) * 3.0
			limb(c, pos + Vector2(-2, -30), pos + Vector2(-10, -36 + k), p.trojan, 3)
			limb(c, pos + Vector2(6, -30), pos + Vector2(-8, -38 - k), p.trojan, 3)
			blob(c, pos + Vector2(-10, -37 + k), 2.3, 2.3, p.hy)
			blob(c, pos + Vector2(-8, -39 - k), 2.3, 2.3, p.hy)
		"kort":
			limb(c, pos + Vector2(-2, -30), pos + Vector2(-12, -52), p.trojan, 3)
			card_at = pos + Vector2(-13, -62)
			limb(c, pos + Vector2(6, -30), pos + Vector2(-4, -20), p.trojan, 3)
			blob(c, pos + Vector2(-4, -20), 2.3, 2.3, p.hy)
		"mobil":
			limb(c, pos + Vector2(-2, -29), pos + Vector2(-7, -22), p.trojan, 3)
			limb(c, pos + Vector2(6, -29), pos + Vector2(-4, -21), p.trojan, 3)
			c.draw_rect(Rect2(pos + Vector2(-9, -27), Vector2(5, 7)), INK)
			c.draw_rect(Rect2(pos + Vector2(-8, -26), Vector2(3, 5)), Color("#7ad0ff"))
			blob(c, pos + Vector2(-6, -21), 2.3, 2.3, p.hy)
		_:
			limb(c, pos + Vector2(-2, -30), pos + Vector2(-6, -20), p.trojan, 3)
			limb(c, pos + Vector2(6, -30), pos + Vector2(-2, -19), p.trojan, 3)
			blob(c, pos + Vector2(-6, -19), 2.3, 2.3, p.hy)
			blob(c, pos + Vector2(-2, -18), 2.3, 2.3, p.hy)
	# huvudet
	if not pappa:     # mammas page, bakom huvudet
		blob(c, head + Vector2(2, 1), 11, 10, p.har)
	blob(c, head, 9.5, 9, p.hy)
	var gaze := (look - head).normalized() if not phone else Vector2(-0.4, 1.0)
	for s in [-1.0, 1.0]:
		var e := head + Vector2(2.8 * s - 2, -1)
		blob(c, e, 2.8, 3.2 if state != "gapar" else 3.8, Color.WHITE)
		c.draw_rect(Rect2(e + gaze * 1.3 - Vector2(0.6, 0.6), Vector2(1.4, 1.5)), INK)
	if pappa:
		ellipse(c, head + Vector2(-1, 5), 8, 4.5, INK)
		ellipse(c, head + Vector2(-1, 5), 7.2, 3.8, p.har)        # skägget
		for s in [-1.0, 1.0]:
			c.draw_rect(Rect2(head + Vector2(2.8 * s - 2 - 3, -4.5), Vector2(6, 6.5)), INK, false, 1.0)
		ellipse(c, head + Vector2(0, -7), 9.5, 4, INK)
		ellipse(c, head + Vector2(0, -7), 8.8, 3.2, p.har)
	else:
		var fringe := PackedVector2Array([head + Vector2(-9, -3), head + Vector2(-6, -9), head + Vector2(3, -10), head + Vector2(9, -5), head + Vector2(3, -6)])
		c.draw_colored_polygon(fringe, p.har)
	var mouth := head + Vector2(-2, 5 if not pappa else 3.5)
	match state:
		"gapar", "klappar":
			blob(c, mouth, 2, 2.4, Color("#5a1414"))
		"mobil":
			c.draw_line(mouth + Vector2(-2, 0), mouth + Vector2(2, 0), INK, 1.0)
		_:
			c.draw_line(mouth + Vector2(-2.5, -0.5), mouth + Vector2(0, 0.5), INK, 1.0)
			c.draw_line(mouth + Vector2(0, 0.5), mouth + Vector2(2.5, -0.5), INK, 1.0)
	return card_at


# ================================================================ trampolinen och trädgården
## Trampolinen sedd från sidan. dip: hur mycket duken trycks ned (0..10) vid x.
static func trampoline(c: CanvasItem, cx: float, y: float, dip: float, dip_x: float, pad := Color("#2a7ae0")) -> void:
	var half := 46.0
	# benen och ramen under
	for x in [-38.0, -14.0, 14.0, 38.0]:
		c.draw_line(Vector2(cx + x, y + 3), Vector2(cx + x * 1.05, y + 19), INK, 2)
	c.draw_line(Vector2(cx - 40, y + 17), Vector2(cx + 40, y + 17), INK, 1)
	# dynan runt kanten (en blå ring) och den svarta duken, lite snett ovanifrån
	ellipse(c, Vector2(cx, y + 1), half + 2, 8, INK, 28)
	ellipse(c, Vector2(cx, y + 1), half + 1, 7, pad, 28)
	ellipse(c, Vector2(cx, y + 1), half - 4, 4.5, Color("#1c1c26"), 28)
	if dip > 0.5:
		# där barnet landar trycks duken ned
		ellipse(c, Vector2(cx + dip_x, y + 1 + dip * 0.6), 18, 3 + dip * 0.35, Color("#101016"), 20)
	ellipse(c, Vector2(cx, y + 4), half + 1, 4, pad.darkened(0.25), 28)      # dynans framkant i skugga


static func garden_back(c: CanvasItem, wind: float, t: float, nt: float) -> void:
	# kullar långt bort
	for i in 6:
		var x := i * 70.0 - 20.0
		ellipse(c, Vector2(x, 128), 55, 22, Color("#3e8a4a").lerp(Color("#5aa060"), (i % 2) * 0.5), 20)
	# granar på kullarna
	for i in 9:
		var x := 18.0 + i * 37.0
		spruce(c, Vector2(x, 115), 15.0 + (i * 7) % 9, wind, t + i)
	# huset: rött med vita knutar, svart tak
	var hx := 10.0
	c.draw_rect(Rect2(hx - 1, 94, 70, 57), INK)
	c.draw_rect(Rect2(hx, 95, 68, 55), Color("#a8231c"))
	for x in range(int(hx) + 4, int(hx) + 66, 5):
		c.draw_line(Vector2(x, 96), Vector2(x, 149), Color("#8e1c16"))      # panelen
	c.draw_rect(Rect2(hx, 95, 4, 55), Color("#f4f0e4"))
	c.draw_rect(Rect2(hx + 64, 95, 4, 55), Color("#f4f0e4"))
	c.draw_colored_polygon(PackedVector2Array([Vector2(hx - 6, 96), Vector2(hx + 34, 70), Vector2(hx + 74, 96)]), INK)
	c.draw_colored_polygon(PackedVector2Array([Vector2(hx - 3, 95), Vector2(hx + 34, 72), Vector2(hx + 71, 95)]), Color("#2c2a30"))
	c.draw_rect(Rect2(hx + 48, 74, 6, 12), Color("#a8231c"))       # skorstenen
	for wx in [hx + 10, hx + 44]:
		c.draw_rect(Rect2(wx - 1, 104, 16, 14), Color("#f4f0e4"))
		c.draw_rect(Rect2(wx + 1, 106, 5, 4), Color("#3a5a8a"))
		c.draw_rect(Rect2(wx + 8, 106, 5, 4), Color("#3a5a8a"))
		c.draw_rect(Rect2(wx + 1, 111, 5, 5), Color("#3a5a8a"))
		c.draw_rect(Rect2(wx + 8, 111, 5, 5), Color("#3a5a8a"))
	c.draw_rect(Rect2(hx + 28, 124, 12, 26), Color("#f4f0e4"))
	c.draw_rect(Rect2(hx + 30, 126, 8, 24), Color("#2a6a4a"))
	birch(c, Vector2(222, 151), 1.0, wind, t)
	# flaggstången med svenska flaggan
	var fx := 302.0
	c.draw_rect(Rect2(fx - 1, 40, 2, 111), Color("#f4f0e4"))
	c.draw_circle(Vector2(fx, 39), 1.5, Color("#ffd23f"))
	_flag(c, Vector2(fx, 42), wind, t)
	# staketet
	for x in range(80, 320, 7):
		c.draw_rect(Rect2(x, 128, 4, 23), INK)
		c.draw_rect(Rect2(x + 1, 129, 2, 21), Color("#f4f0e4"))
	c.draw_rect(Rect2(78, 134, 242, 2), Color("#d8d4c8"))
	c.draw_rect(Rect2(78, 143, 242, 2), Color("#d8d4c8"))


static func _flag(c: CanvasItem, at: Vector2, wind: float, t: float) -> void:
	var dir := -1.0 if wind < -0.05 else 1.0
	var strength := clampf(absf(wind) * 1.4 + 0.25, 0.25, 1.0)
	var length := 22.0
	var hang := (1.0 - strength) * 14.0
	var cols := 8
	for i in cols:
		var u0 := float(i) / cols
		var u1 := float(i + 1) / cols
		var w0 := sin(t * (5 + strength * 8) - u0 * 5) * 2.0 * strength * u0
		var w1 := sin(t * (5 + strength * 8) - u1 * 5) * 2.0 * strength * u1
		var a := at + Vector2(dir * u0 * length * strength, w0 + u0 * hang)
		var b := at + Vector2(dir * u1 * length * strength, w1 + u1 * hang)
		var blue := Color("#1a5ab8")
		var yellow := Color("#ffd23f")
		var mid := u0 >= 0.3 and u0 < 0.45
		c.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 14), a + Vector2(0, 14)]), yellow if mid else blue)
		c.draw_colored_polygon(PackedVector2Array([a + Vector2(0, 5.5), b + Vector2(0, 5.5), b + Vector2(0, 8.5), a + Vector2(0, 8.5)]), yellow)


static func ground(c: CanvasItem) -> void:
	c.draw_rect(Rect2(-200, 150, 720, 30), Color("#4a9a3a"))
	for i in 24:
		c.draw_rect(Rect2(i * 14 - 4, 150 + (i % 3) * 7, 6, 2), Color("#5ab848"))
	c.draw_rect(Rect2(-200, 150, 720, 1), Color("#3a7a2e"))


## Lampor i husets fönster på kvällen (ritas efter mörkret, så de lyser).
static func lights(c: CanvasItem, nt: float) -> void:
	if nt < 0.3:
		return
	var a := clampf((nt - 0.3) * 2.0, 0, 1)
	for wx in [20.0, 54.0]:
		c.draw_rect(Rect2(wx + 1, 106, 12, 10), Color(1.0, 0.85, 0.35, a))


## En pratbubbla med svans mot munnen.
static func bubble(c: CanvasItem, r: Rect2, tail: Vector2) -> void:
	var bx := clampf(tail.x - 4, r.position.x + 4, r.end.x - 14)     # svansen börjar ovanför munnen
	var tip := PackedVector2Array([Vector2(bx, r.end.y - 1), Vector2(bx + 8, r.end.y - 1), tail])
	c.draw_colored_polygon(PackedVector2Array([tip[0] + Vector2(-1, 0), tip[1] + Vector2(1, 0), tail + Vector2(0, 1)]), INK)
	c.draw_rect(r.grow(1), INK)
	c.draw_rect(r, Color.WHITE)
	c.draw_colored_polygon(tip, Color.WHITE)


## Staketet mellan trädgårdarna i duellen, från bakre staketet och fram mot oss.
static func side_fence(c: CanvasItem, x: float) -> void:
	for i in 7:
		var k := i / 6.0
		var px := x - k * 8.0
		var foot := 151.0 + k * 27.0
		var hgt := 23.0 + k * 10.0
		c.draw_rect(Rect2(px - 2, foot - hgt, 5, hgt), INK)
		c.draw_rect(Rect2(px - 1, foot - hgt + 1, 3, hgt - 1), Color("#f4f0e4"))
	for rail in [0.3, 0.7]:
		c.draw_line(Vector2(x, 151 - 23 * (1 - rail)), Vector2(x - 8, 178 - 33 * (1 - rail)), Color("#d8d4c8"), 2.0)



# ================================================================ träd
## Ett litet tal 0..1 som alltid blir samma för samma i (för träd som ser slumpade ut men står still).
static func _hash(i: float) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)


## En gran: våningar av hängande grenar, mörkare på skuggsidan, och en liten stam.
static func spruce(c: CanvasItem, foot: Vector2, h: float, wind: float, t: float, scale := 1.0) -> void:
	h *= scale
	var w := h * 0.42
	c.draw_rect(Rect2(foot + Vector2(-0.75, -2.5) * scale, Vector2(1.5, 3) * scale), Color("#3a2a1c"))
	var tiers := 5
	var sway := (wind * 1.2 + sin(t * 2.0) * 0.3) * scale
	for k in tiers:
		var u := float(k) / tiers                     # 0 i toppen
		var top := foot + Vector2(sway * (1.0 - u), -h + h * u * 0.78)
		var bot := foot.y - h * 0.08 - (tiers - 1 - k) * h * 0.17
		var half := w * (0.35 + 0.65 * (u + 1.0 / tiers))
		var droop := 1.6 * scale
		var dark := Color("#173f28")
		var mid := Color("#245a36").lerp(Color("#2f6e40"), _hash(k + foot.x) * 0.5)
		var notch := Vector2(foot.x, bot - droop * 0.5)
		c.draw_colored_polygon(PackedVector2Array([top, Vector2(foot.x - half, bot + droop), notch]), dark)
		c.draw_colored_polygon(PackedVector2Array([top, notch, Vector2(foot.x + half, bot + droop)]), dark)
		c.draw_colored_polygon(PackedVector2Array([top, Vector2(foot.x - half + 1.0 * scale, bot + droop * 0.6), Vector2(foot.x - half * 0.15, bot - droop * 0.3)]), mid)


## En björk: vit stam med svarta fläckar, några grenar och en luftig krona av lövklumpar i flera
## gröna toner, som gungar i vinden (mer i toppen än nära stammen).
static func birch(c: CanvasItem, foot: Vector2, scale: float, wind: float, t: float) -> void:
	var h := 100.0 * scale
	var sway := wind * 5.0 + sin(t * (2.0 + absf(wind) * 6.0)) * (0.5 + absf(wind) * 2.5)
	var top := foot + Vector2(sway * 0.3, -h)
	# stammen smalnar av uppåt
	var trunk := PackedVector2Array([foot + Vector2(-3.2, 0) * scale, foot + Vector2(3.2, 0) * scale, top + Vector2(0.8, 0), top + Vector2(-0.8, 0)])
	c.draw_colored_polygon(PackedVector2Array([trunk[0] + Vector2(-1, 0), trunk[1] + Vector2(1, 0), trunk[2] + Vector2(1, 0), trunk[3] + Vector2(-1, 0)]), INK)
	c.draw_colored_polygon(trunk, Color("#eeeee4"))
	for k in 14:
		var u := 0.05 + k * 0.064
		var p := foot.lerp(top, u)
		var hw := lerpf(3.0 * scale, 0.8, u)
		var mx := p.x - hw + _hash(k) * hw * 1.4
		c.draw_rect(Rect2(mx, p.y, maxf(1.0, hw * 0.8), 1.0), INK)
	# grenar
	for k in 6:
		var u := 0.42 + k * 0.09
		var s := -1.0 if k % 2 == 0 else 1.0
		var p := foot.lerp(top, u)
		var tip := p + Vector2(s * (10 + _hash(k + 3) * 8) * scale + sway * u, -6 * scale)
		c.draw_line(p, tip, Color("#4a3a30"), 1.0)
	# kronan: först skuggiga klumpar, sedan mellangröna, sist ljusa där solen tar
	var ctr := foot + Vector2(0, -h * 0.68)
	var layers := [[Color("#285e26"), Vector2(1.0, 1.6), 1.0], [Color("#3e8a34"), Vector2.ZERO, 0.9], [Color("#6fb24c"), Vector2(-1.2, -1.4), 0.55]]
	for L in layers:
		for k in 46:
			var a := _hash(k * 1.7) * TAU
			var r := sqrt(_hash(k * 3.1))
			var off := Vector2(cos(a) * 22.0, sin(a) * 27.0) * r * scale
			if L[2] < 0.6 and off.y > 0.0:
				continue                              # ljuset bara i övre halvan
			if off.y > 8.0 * scale:
				off.y += (off.y - 8.0 * scale) * 0.6  # nedre grenar hänger
			var bend := sway * (0.4 + (1.0 - (off.y + 27.0) / 54.0) * 0.6)
			var flutter := sin(t * 5.0 + k) * 0.4 * (0.3 + absf(wind))
			var size: float = (2.2 + _hash(k * 5.3) * 2.0) * scale * L[2]
			c.draw_circle(ctr + off + L[1] * scale + Vector2(bend + flutter, 0), size, L[0])


# ================================================================ duellens bakgrund
## Utsikten i duellen: hav, en kulle med ett hus långt bort, en väg med trafik och en gräsäng.
## traffic: [{x, lane, dir, typ ("bil"/"lastbil"), col}].
static func duel_back(c: CanvasItem, wind: float, t: float, nt: float, traffic: Array) -> void:
	# havet vid horisonten, med glitter
	c.draw_rect(Rect2(-200, 100, 720, 14), Color("#3a6ea8").lerp(Color("#1a2a48"), nt))
	c.draw_rect(Rect2(-200, 100, 720, 1), Color("#8ab8e0").lerp(Color("#2a3a58"), nt))
	for k in 18:
		var gx := fposmod(_hash(k) * 520.0 + t * (2.0 + _hash(k + 9) * 3.0), 520.0) - 100.0
		var gy := 102.0 + _hash(k * 2.3) * 10.0
		if sin(t * 3.0 + k * 1.9) > 0.3:
			c.draw_rect(Rect2(gx, gy, 2, 1), Color(1, 1, 1, 0.6 * (1.0 - nt)))
	# en ö långt ut
	ellipse(c, Vector2(40, 101), 18, 3, Color("#4a6a5a").lerp(Color("#1a2a2a"), nt), 20)
	# kullen med huset
	ellipse(c, Vector2(250, 116), 92, 30, Color("#4e8a4a"), 40)
	ellipse(c, Vector2(250, 118), 92, 28, Color("#58984e"), 40)
	var hp := Vector2(250, 88)
	c.draw_rect(Rect2(hp + Vector2(-7, -6), Vector2(14, 7)), Color("#f0e6c8"))
	c.draw_colored_polygon(PackedVector2Array([hp + Vector2(-9, -6), hp + Vector2(0, -12), hp + Vector2(9, -6)]), Color("#7a2a22"))
	c.draw_rect(Rect2(hp + Vector2(-4, -4), Vector2(2, 2)), Color("#ffd870") if nt > 0.3 else Color("#3a5a8a"))
	c.draw_rect(Rect2(hp + Vector2(2, -4), Vector2(2, 2)), Color("#ffd870") if nt > 0.3 else Color("#3a5a8a"))
	c.draw_rect(Rect2(hp + Vector2(-1, -3), Vector2(2, 4)), Color("#5a3a2a"))
	for k in 5:
		spruce(c, Vector2(214 + k * 9 + _hash(k) * 4, 98 + absf(k - 2) * 1.5), 9.0 + _hash(k + 2) * 5, wind, t + k, 1.0)
	spruce(c, Vector2(282, 96), 12.0, wind, t + 7)
	birch(c, Vector2(296, 100), 0.18, wind, t)
	# ängen fram till vägen
	c.draw_rect(Rect2(-200, 113, 720, 7), Color("#5a9a48"))
	# vägen
	c.draw_rect(Rect2(-200, 120, 720, 9), Color("#4a4a52"))
	c.draw_rect(Rect2(-200, 120, 720, 1), Color("#8a8a90"))
	c.draw_rect(Rect2(-200, 128, 720, 1), Color("#8a8a90"))
	for x in range(-200, 520, 14):
		c.draw_rect(Rect2(x, 124, 7, 1), Color("#e8e4d0"))
	var lanes := [traffic.filter(func(v): return v.dir > 0), traffic.filter(func(v): return v.dir < 0)]
	for lane in lanes:
		for v in lane:
			_vehicle(c, v, nt)
	# gräset närmast, med tuvor
	c.draw_rect(Rect2(-200, 129, 720, 22), Color("#4f9a3e"))
	for k in 30:
		var gx := -60.0 + _hash(k * 4.1) * 440.0
		var gy := 131.0 + _hash(k * 6.7) * 18.0
		c.draw_rect(Rect2(gx, gy, 3, 1), Color("#64b04c"))


## En bil eller lastbil på vägen. Bilar kör i den bortre filen åt höger, i den närmre åt vänster.
static func _vehicle(c: CanvasItem, v: Dictionary, nt: float) -> void:
	var dir: float = v.dir
	var y := 123.0 if dir > 0 else 127.0
	var x: float = v.x
	var col: Color = v.col
	var wheel := Color("#141418")
	if v.typ == "lastbil":
		# släpet bakom, hytten fram
		var trailer := Rect2(x - 9 - dir * 3, y - 7, 15, 6)
		c.draw_rect(trailer.grow(0.5), INK)
		c.draw_rect(trailer, col)
		var cab := Rect2(x + (4.5 if dir > 0 else -9.5), y - 6, 5, 5)
		c.draw_rect(cab.grow(0.5), INK)
		c.draw_rect(cab, Color("#d84a3a") if col != Color("#d84a3a") else Color("#3a6ad8"))
		c.draw_rect(Rect2(cab.position.x + (3 if dir > 0 else 0), cab.position.y + 1, 2, 2), Color("#a8d8f0"))
		for wx in [-8.0, -4.0, 2.0, 6.0]:
			c.draw_rect(Rect2(x + wx * dir - 1, y - 1, 2, 1.5), wheel)
		if nt > 0.3:
			c.draw_rect(Rect2(x + (9.5 if dir > 0 else -10.5), y - 2, 1, 1), Color("#fff2a0"))
	else:
		c.draw_rect(Rect2(x - 5, y - 3.5, 10, 3).grow(0.5), INK)
		c.draw_rect(Rect2(x - 5, y - 3.5, 10, 3), col)
		c.draw_rect(Rect2(x - 2.5 - dir * 0.5, y - 6, 5, 2.5), col.darkened(0.15))
		c.draw_rect(Rect2(x - 2 - dir * 0.5, y - 5.5, 4, 1.5), Color("#a8d8f0"))
		c.draw_rect(Rect2(x - 4, y - 1, 2, 1.5), wheel)
		c.draw_rect(Rect2(x + 2, y - 1, 2, 1.5), wheel)
		if nt > 0.3:
			c.draw_rect(Rect2(x + 5 * dir - (0 if dir > 0 else 1), y - 3, 1, 1), Color("#fff2a0"))
			c.draw_rect(Rect2(x - 5 * dir - (1 if dir > 0 else 0), y - 3, 1, 1), Color("#ff3a3a"))
