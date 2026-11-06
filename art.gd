extends RefCounted
## Ritfunktioner i "pappersfigur"-stil: platta färger, svarta konturer, runda huvuden med stora
## ögon och vantar till händer. Allt ritas i spelets låga upplösning (320 x 180), så det blir
## pixligt av sig självt. `off` är skärmens förskjutning (bredare skärmar har kanter).

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
	"krasch": {"hands": [Vector2(-11, 2), Vector2(10, -6)], "feet": [Vector2(-8, 9), Vector2(6, 11)], "y": 0.0},
}


static func ellipse(c: CanvasItem, ctr: Vector2, rx: float, ry: float, col: Color, seg := 14) -> void:
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
static func kid(c: CanvasItem, off: Vector2, k: Dictionary, pos: Vector2, pose: String, rot: float, sx: float,
		wind: float, lift: float, t: float, face := "glad") -> void:
	var p: Dictionary = POSES.get(pose, POSES.sta)
	var hip := pos + Vector2(0, -11 + p.y)
	var sy := 1.0
	if pose == "ligg" or pose == "superman":
		pass
	var back := sx < 0.0
	c.draw_set_transform(off + hip, rot, Vector2(maxf(absf(sx), 0.15), sy))
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
		c.draw_line(Vector2(0, -5), Vector2(0, 3), (k.jacka as Color).darkened(0.35))   # dragkedja
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
				c.draw_line(h + Vector2(2.7 * s - 1, -2), h + Vector2(2.7 * s + 1, 0), INK)
				c.draw_line(h + Vector2(2.7 * s + 1, -2), h + Vector2(2.7 * s - 1, 0), INK)
			else:
				c.draw_rect(Rect2(h + Vector2(2.7 * s - 0.5 + s * 0.6, -1.2) + look, Vector2(1.2, 1.4)), INK)
		match face:
			"oo", "aj":
				blob(c, h + Vector2(0, 4), 1.4, 1.6, Color("#5a1414"))
			"glad":
				c.draw_line(h + Vector2(-2.5, 3.5), h + Vector2(-1, 4.5), INK)
				c.draw_line(h + Vector2(-1, 4.5), h + Vector2(1, 4.5), INK)
				c.draw_line(h + Vector2(1, 4.5), h + Vector2(2.5, 3.5), INK)
			_:
				c.draw_line(h + Vector2(-2, 4), h + Vector2(2, 4), INK)
	# frisyren eller huvudbonaden ovanpå
	match style:
		"flator", "svans":
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
				c.draw_line(h + Vector2(-0.2, -1), h + Vector2(0.2, -1), INK)
		"mossa":
			ellipse(c, h + Vector2(0, -4), 9, 5.5, INK)
			ellipse(c, h + Vector2(0, -4), 8.2, 4.8, k.extra)
			c.draw_rect(Rect2(h + Vector2(-8.5, -2), Vector2(17, 2.5)), INK)
			c.draw_rect(Rect2(h + Vector2(-8, -1.6), Vector2(16, 1.8)), (k.extra as Color).lightened(0.3))
			var pom := h + Vector2(0, -10) + Vector2(drift.x * 0.4, -lift * 1.5)
			blob(c, pom, 2.3, 2.3, Color.WHITE)
			if not back:
				c.draw_rect(Rect2(h + Vector2(-5, 0.3), Vector2(4, 1)), hair)
	# i storm fladdrar några hårstrån
	if absf(wind) > 0.55 and style != "keps" and style != "mossa":
		for i in 3:
			var base := h + Vector2(-3 + i * 3, -7)
			c.draw_line(base, base + Vector2(wind * 4 + flutter * (1 + i * 0.3), -2 - i % 2), hair)


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
			c.draw_line(mouth + Vector2(-2, 0), mouth + Vector2(2, 0), INK)
		_:
			c.draw_line(mouth + Vector2(-2.5, -0.5), mouth + Vector2(0, 0.5), INK)
			c.draw_line(mouth + Vector2(0, 0.5), mouth + Vector2(2.5, -0.5), INK)
	return card_at


# ================================================================ trampolinen och trädgården
## Trampolinen sedd från sidan. dip: hur mycket duken trycks ned (0..10) vid x.
static func trampoline(c: CanvasItem, cx: float, y: float, dip: float, dip_x: float) -> void:
	var half := 46.0
	# benen och ramen under
	for x in [-38.0, -14.0, 14.0, 38.0]:
		c.draw_line(Vector2(cx + x, y + 3), Vector2(cx + x * 1.05, y + 19), INK, 2)
	c.draw_line(Vector2(cx - 40, y + 17), Vector2(cx + 40, y + 17), INK, 1)
	# dynan runt kanten (en blå ring) och den svarta duken, lite snett ovanifrån
	ellipse(c, Vector2(cx, y + 1), half + 2, 8, INK, 28)
	ellipse(c, Vector2(cx, y + 1), half + 1, 7, Color("#2a7ae0"), 28)
	ellipse(c, Vector2(cx, y + 1), half - 4, 4.5, Color("#1c1c26"), 28)
	if dip > 0.5:
		# där barnet landar trycks duken ned
		ellipse(c, Vector2(cx + dip_x, y + 1 + dip * 0.6), 18, 3 + dip * 0.35, Color("#101016"), 20)
	ellipse(c, Vector2(cx, y + 4), half + 1, 4, Color("#1f60b8"), 28)      # dynans framkant i skugga


static func garden_back(c: CanvasItem, wind: float, t: float, nt: float) -> void:
	# kullar långt bort
	for i in 6:
		var x := i * 70.0 - 20.0
		ellipse(c, Vector2(x, 128), 55, 22, Color("#3e8a4a").lerp(Color("#5aa060"), (i % 2) * 0.5), 20)
	# granar på kullarna
	for i in 9:
		var x := 18.0 + i * 37.0
		var h := 14.0 + (i * 7) % 9
		var top := Vector2(x + wind * 1.5 * sin(t * 2 + i), 112 - h)
		c.draw_colored_polygon(PackedVector2Array([top, Vector2(x - 6, 114), Vector2(x + 6, 114)]), Color("#1f5a34"))
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
	# björken
	var bx := 222.0
	c.draw_rect(Rect2(bx - 3, 76, 6, 75), INK)
	c.draw_rect(Rect2(bx - 2, 76, 4, 75), Color("#f2f2ea"))
	for y in [84, 97, 108, 121, 135]:
		c.draw_rect(Rect2(bx - 2 + (y % 3), y, 3, 1), INK)
	var sway := wind * 5.0 + sin(t * (2.0 + absf(wind) * 6.0)) * (0.5 + absf(wind) * 2.5)
	for i in 7:
		var a := i * 0.9
		var p := Vector2(bx + cos(a) * 14 + sway * (0.6 + i * 0.07), 70 + sin(a) * 9 - i)
		blob(c, p, 9, 7, Color("#3e9a3a").lerp(Color("#5ab848"), (i % 3) * 0.3))
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
	var tip := PackedVector2Array([r.position + Vector2(r.size.x - 14, r.size.y - 1), r.position + Vector2(r.size.x - 6, r.size.y - 1), tail])
	c.draw_colored_polygon(PackedVector2Array([tip[0] + Vector2(-1, 0), tip[1] + Vector2(1, 0), tail + Vector2(0, 1)]), INK)
	c.draw_rect(r.grow(1), INK)
	c.draw_rect(r, Color.WHITE)
	c.draw_colored_polygon(tip, Color.WHITE)
