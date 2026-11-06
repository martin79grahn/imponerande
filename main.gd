extends Node2D
## Imponerande! – ett trampolinspel. Det här skriptet sköter skärmarna (titel, val, spel, resultat,
## trickbok), inmatningen (tangentbord, handkontroll och pekskärm), ljudet och sparningen, och
## ritar allt. Själva studsandet finns i game.gd, himlen i sky.gd och figurerna i art.gd.

const Data := preload("res://data.gd")
const Art := preload("res://art.gd")
const Game := preload("res://game.gd")
const SkyScript := preload("res://sky.gd")

const W := 320.0
const H := 180.0
const SAVE := "user://save.cfg"
const GOLD := Color("#ffe14d")
const PANEL := Color(0.06, 0.05, 0.12, 0.86)

var font: Texture2D = preload("res://assets/font.png")
var font_order := ""

var state := "titel"            # titel | val | spel | paus | resultat | trickbok
var sel := 0                    # markerad rad i menyer
var kid := 0
var par := 0
var xp := 0
var level := 1
var muted := false
var game
var sky
var ox := 0.0
var t := 0.0
var result := {}
var demo_y := 0.0
var demo_v := 0.0
var demo_pose := "upp"

# inmatning: vad som hålls nu och vad som trycktes i den här bildrutan
var held := {}
var pressed := {}
var touch_on := false
var fingers := {}               # pekindex -> knapp

var music: AudioStreamPlayer
var rain: AudioStreamPlayer
var wind_snd: AudioStreamPlayer
var sfx: Array[AudioStreamPlayer] = []
var sounds := {}


func _ready() -> void:
	font_order = FileAccess.get_file_as_string("res://assets/font_order.txt")
	randomize()
	_load()
	sky = SkyScript.new()
	sky.setup(randf_range(5.0, 20.0), "sol")
	touch_on = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	_setup_audio()
	_play_music("musik_meny")
	get_tree().set_auto_accept_quit(false)


# ================================================================ sparning
func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		xp = cf.get_value("spel", "xp", 0)
		kid = clampi(cf.get_value("spel", "barn", 0), 0, 4)
		par = clampi(cf.get_value("spel", "foralder", 0), 0, 1)
		muted = cf.get_value("spel", "tyst", false)
	level = level_for(xp)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("spel", "xp", xp)
	cf.set_value("spel", "barn", kid)
	cf.set_value("spel", "foralder", par)
	cf.set_value("spel", "tyst", muted)
	cf.save(SAVE)


func level_for(x: int) -> int:
	var l := 1
	for i in Data.NIVA_XP.size():
		if x >= Data.NIVA_XP[i]:
			l = i + 1
	return l


# ================================================================ ljud
func _setup_audio() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -8.0
	add_child(music)
	rain = AudioStreamPlayer.new()
	wind_snd = AudioStreamPlayer.new()
	for p in [rain, wind_snd]:
		p.volume_db = -80.0
		add_child(p)
	for i in 5:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx.append(p)
	for n in ["studs", "rumpa", "trick", "land", "krasch", "applad", "oj", "aska", "regn", "vind", "niva", "meny", "valj", "lapp", "musik_meny", "musik_spel"]:
		var s: AudioStreamWAV = load("res://assets/sfx/%s.wav" % n)
		if n in ["regn", "vind", "musik_meny", "musik_spel"]:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		sounds[n] = s
	rain.stream = sounds.regn
	wind_snd.stream = sounds.vind
	rain.play()
	wind_snd.play()


func play(n: String) -> void:
	if muted:
		return
	for p in sfx:
		if not p.playing:
			p.stream = sounds[n]
			p.play()
			return
	sfx[0].stream = sounds[n]
	sfx[0].play()


func _play_music(n: String) -> void:
	if music.stream == sounds[n] and music.playing:
		return
	music.stream = sounds[n]
	if not muted:
		music.play()


func _weather_audio() -> void:
	var w: String = sky.weather
	var r := -80.0
	var v := -80.0
	if not muted:
		if w == "regn": r = -10.0
		elif w == "storm": r = -6.0
		v = linear_to_db(clampf(absf(sky.wind) * 0.9, 0.001, 1.0)) - 6.0
	rain.volume_db = lerpf(rain.volume_db, r, 0.05)
	wind_snd.volume_db = lerpf(wind_snd.volume_db, v, 0.05)


# ================================================================ inmatning
const KEYS := {
	"upp": [KEY_UP, KEY_W], "ned": [KEY_DOWN, KEY_S], "vanster": [KEY_LEFT, KEY_A], "hoger": [KEY_RIGHT, KEY_D],
	"studs": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], "trick": [KEY_X, KEY_Z, KEY_SHIFT], "paus": [KEY_ESCAPE, KEY_P, KEY_BACKSPACE],
}
const JOY := {
	"upp": [JOY_BUTTON_DPAD_UP], "ned": [JOY_BUTTON_DPAD_DOWN], "vanster": [JOY_BUTTON_DPAD_LEFT], "hoger": [JOY_BUTTON_DPAD_RIGHT],
	"studs": [JOY_BUTTON_A], "trick": [JOY_BUTTON_B, JOY_BUTTON_X], "paus": [JOY_BUTTON_START],
}


func _read_input() -> void:
	var now := {}
	for k in KEYS:
		var on := false
		for key in KEYS[k]:
			if Input.is_physical_key_pressed(key):
				on = true
		for d in Input.get_connected_joypads():
			for b in JOY[k]:
				if Input.is_joy_button_pressed(d, b):
					on = true
		now[k] = on
	for d in Input.get_connected_joypads():
		var ax := Input.get_joy_axis(d, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)
		if ax < -0.5: now.vanster = true
		if ax > 0.5: now.hoger = true
		if ay < -0.5: now.upp = true
		if ay > 0.5: now.ned = true
	for f in fingers.values():
		for k in f:
			now[k] = true
	pressed = {}
	for k in now:
		if now[k] and not held.get(k, false):
			pressed[k] = true
	for k in tap_pulse:
		pressed[k] = true
	tap_pulse.clear()
	held = now


var tap_pulse := {}


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_T:
			touch_on = not touch_on
		elif event.physical_keycode == KEY_M:
			_toggle_sound()
		elif event.physical_keycode == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.device != InputEvent.DEVICE_ID_EMULATION:
				touch_on = true          # en riktig pekskärm (inte musen)
			_touch_down(event.index, event.position)
		else:
			fingers.erase(event.index)
	elif event is InputEventScreenDrag and fingers.has(event.index) and fingers[event.index].has("pad"):
		fingers[event.index] = _pad_dirs(event.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		tap_pulse["paus"] = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "spel":
		state = "paus"


func _toggle_sound() -> void:
	muted = not muted
	if muted:
		music.stop()
	else:
		music.play()
	_save()


# ---------------------------------------------------------------- pekskärmen
func pad_center() -> Vector2:
	return Vector2(maxf(30.0, ox * 0.5 + 6.0), 142)


## STUDS och TRICK i en kolumn längst till höger, så att de inte täcker föräldern.
func btn_studs() -> Vector2:
	return Vector2(get_viewport_rect().size.x - maxf(22.0, ox * 0.5 + 4.0), 152)


func btn_trick() -> Vector2:
	return btn_studs() + Vector2(0 if ox < 50 else -30, -36 if ox < 50 else -20)


func btn_paus() -> Rect2:
	return Rect2(get_viewport_rect().size.x / 2 - 15, 3, 30, 12)


func _pad_dirs(pos: Vector2) -> Dictionary:
	var v := pos - pad_center()
	var d := {"pad": true}
	if v.length() < 5.0:
		return d
	var a := fposmod(v.angle(), TAU)
	var sector := int(round(a / (TAU / 8.0))) % 8
	var map := [["hoger"], ["hoger", "ned"], ["ned"], ["ned", "vanster"], ["vanster"], ["vanster", "upp"], ["upp"], ["upp", "hoger"]]
	for k in map[sector]:
		d[k] = true
	return d


func _touch_down(index: int, pos: Vector2) -> void:
	var playing := state == "spel"
	if playing:
		if btn_paus().grow(4).has_point(pos):
			tap_pulse["paus"] = true
			return
		if pos.distance_to(pad_center()) < 40:
			fingers[index] = _pad_dirs(pos)
			return
		if pos.distance_to(btn_studs()) < 21:
			fingers[index] = {"studs": true}
			return
		if pos.distance_to(btn_trick()) < 18:
			fingers[index] = {"trick": true}
			return
		return
	_menu_tap(Vector2(pos.x - ox, pos.y))


## Tryck i menyerna: varje meny har sina rutor.
func _menu_tap(p: Vector2) -> void:
	match state:
		"titel":
			for i in 3:
				if title_item(i).has_point(p):
					sel = i
					tap_pulse["studs"] = true
		"val":
			for i in 5:
				if Rect2(kid_x(i) - 22, 44, 44, 52).has_point(p):
					kid = i
					sel = 0
					play("meny")
			for i in 2:
				if parent_btn(i).has_point(p):
					par = i
					sel = 1
					play("meny")
			if start_btn().has_point(p):
				sel = 2
				tap_pulse["studs"] = true
			if p.y < 20 and p.x < 60:
				tap_pulse["trick"] = true
		"paus":
			tap_pulse["paus"] = true
		"resultat", "trickbok":
			tap_pulse["studs"] = true


# ================================================================ huvudloopen
func _physics_process(dt: float) -> void:
	t += dt
	ox = (get_viewport_rect().size.x - W) / 2.0
	_read_input()
	var time_speed := 0.35 if state != "spel" else 0.05
	if state != "paus":
		sky.update(dt, time_speed)
	for e in sky.events:
		if e == "aska":
			play("aska")
	sky.events.clear()
	_weather_audio()
	match state:
		"titel": _title(dt)
		"val": _choose()
		"spel": _play(dt)
		"paus":
			if pressed.get("paus") or pressed.get("studs"):
				state = "spel"
			elif pressed.get("trick"):
				_to_title()
		"resultat":
			if pressed.get("studs") or pressed.get("paus"):
				_to_title()
		"trickbok":
			if pressed.get("studs") or pressed.get("paus") or pressed.get("trick"):
				state = "titel"
				play("meny")
	queue_redraw()


func _to_title() -> void:
	state = "titel"
	sel = 0
	sky.setup(randf_range(5.0, 20.0), ["sol", "sol", "moln"].pick_random())
	_play_music("musik_meny")


func _title(dt: float) -> void:
	# ett barn studsar i bakgrunden
	demo_v -= Game.G * dt
	demo_y += demo_v * dt
	if demo_y <= 0.0:
		demo_y = 0.0
		demo_v = sqrt(2.0 * Game.G * randf_range(30, 70))
		demo_pose = ["upp", "stjarna", "boll", "upp"].pick_random()
	if pressed.get("upp"):
		sel = posmod(sel - 1, 3)
		play("meny")
	if pressed.get("ned"):
		sel = posmod(sel + 1, 3)
		play("meny")
	if pressed.get("studs"):
		play("valj")
		match sel:
			0:
				state = "val"
				sel = 0
			1:
				state = "trickbok"
			2:
				_toggle_sound()
	if pressed.get("paus"):
		_save()
		if not OS.has_feature("web"):
			get_tree().quit()


func _choose() -> void:
	if pressed.get("upp"):
		sel = posmod(sel - 1, 3)
		play("meny")
	if pressed.get("ned"):
		sel = posmod(sel + 1, 3)
		play("meny")
	var step := (1 if pressed.get("hoger") else 0) - (1 if pressed.get("vanster") else 0)
	if step != 0:
		if sel == 0:
			kid = posmod(kid + step, 5)
		elif sel == 1:
			par = posmod(par + step, 2)
		play("meny")
	if pressed.get("studs"):
		if sel < 2:
			sel += 1
			play("meny")
		else:
			_start_game()
	if pressed.get("trick") or pressed.get("paus"):
		state = "titel"
		sel = 0
		play("meny")


func _start_game() -> void:
	play("valj")
	_save()
	var w: String = Data.VADER.pick_random()
	sky.setup(randf_range(5.0, 21.0), w)
	game = Game.new()
	game.start(kid, par, level, w)
	game._say("")
	state = "spel"
	_play_music("musik_spel")


func _play(dt: float) -> void:
	if pressed.get("paus"):
		state = "paus"
		return
	for k in ["studs", "trick", "upp", "ned", "vanster", "hoger"]:
		if pressed.get(k):
			game.press(k, held)
	game.weather = sky.weather
	game.update(dt, held)
	# vädret kan slå om mitt i rundan
	if absf(game.time_left - 30.0) < dt and randf() < 0.35:
		sky.setup(sky.hour, Data.VADER.pick_random())
		game.weather = sky.weather
		game._popup(Data.VADER_NAMN[sky.weather], Color("#a8d8ff"))
	for s in game.sounds:
		play(s)
	game.sounds.clear()
	if game.phase == "slut":
		_finish()


func _finish() -> void:
	var before := level
	xp += game.total
	level = level_for(xp)
	var news: Array = []
	for id in Data.BOK:
		var n: int = Data.TRICKS[id].niva
		if n > before and n <= level:
			news.append(Data.TRICKS[id].namn)
	var avg: float = game.average()
	var verdict := ""
	for o in Data.OMDOME:
		if avg >= o[0]:
			verdict = o[1]
	result = {"total": game.total, "avg": avg, "verdict": verdict, "cards": game.cards.size(), "best": game.best_jump,
		"news": news, "levelup": level > before}
	if level > before:
		play("niva")
	else:
		play("applad")
	_save()
	state = "resultat"


# ================================================================ ritning
func _draw() -> void:
	var vw := get_viewport_rect().size.x
	draw_set_transform(Vector2(ox, 0))
	_scene()
	match state:
		"titel": _draw_title()
		"val": _draw_choose()
		"spel", "paus": _draw_hud()
		"resultat": _draw_result()
		"trickbok": _draw_book()
	if state == "paus":
		draw_rect(Rect2(-ox, 0, vw, H), Color(0, 0, 0, 0.55))
		text("PAUS", Vector2(160, 70), GOLD, 3, 1)
		text("STUDS: FORTSÄTT", Vector2(160, 104), Color.WHITE, 1, 1)
		text("TRICK: AVSLUTA RUNDAN", Vector2(160, 116), Color.WHITE, 1, 1)
	draw_set_transform(Vector2.ZERO)
	if touch_on:
		_draw_touch()


## Himlen, trädgården, trampolinen, föräldern och barnet, med väder och kvällsmörker.
func _scene() -> void:
	draw_rect(Rect2(-ox, 0, get_viewport_rect().size.x, H), Color("#1a1a2a"))
	sky.draw_back(self)
	var nt: float = sky.night()
	Art.garden_back(self, sky.wind, t, nt)
	Art.ground(self)
	var playing: bool = state in ["spel", "paus", "resultat"] and game != null
	var k: Dictionary = Data.KIDS[kid]
	var dip := 0.0
	var ky := 0.0
	if playing:
		dip = game.dip
		ky = game.y
	elif state == "titel":
		ky = demo_y
		dip = maxf(0.0, 6.0 - demo_y) if demo_y < 6.0 else 0.0
	Art.trampoline(self, Game.CX, Game.MAT_Y, dip, 0.0)
	var feet := Vector2(Game.CX, Game.MAT_Y - ky + dip)
	if state in ["spel", "paus", "resultat"] and game:
		var pstate: String = game.react
		var card_at: Vector2 = Art.parent(self, Vector2(ox, 0), Data.PARENTS[par], Vector2(268, 150), pstate, feet + Vector2(0, -20), t, sky.wind)
		_draw_kid_in_game(k, feet)
		if game.card_t > 0.0 and card_at != Vector2.ZERO:
			_draw_card(card_at, game.card)
	elif state == "titel":
		var face := "oo" if demo_v < 0 else "glad"
		Art.kid(self, Vector2(ox, 0), k, feet, demo_pose if demo_y > 4 else "huka", 0.0, 1.0, sky.wind, -demo_v / 300.0, t, face)
	sky.draw_front(self)
	# mörker, molnighet och lampor
	var dark := clampf(nt * 0.42 + sky.gloom() * 0.15, 0.0, 0.55)
	if dark > 0.0:
		draw_rect(Rect2(-ox, 0, get_viewport_rect().size.x, H), Color(0.04, 0.04, 0.16, dark))
	Art.lights(self, nt)


func _draw_kid_in_game(k: Dictionary, feet: Vector2) -> void:
	var g = game
	var rot: float = g.rot
	var sx := 1.0
	if g.spin > 0.0:
		sx = cos(g.spin * TAU)
	if g.cur == "pannkaka":
		sx = cos(g.cur_t * 18.0)
		rot = PI / 2
	if g.pose == "superman":
		rot = PI / 2
	if g.pose == "ligg":
		var belly: bool = g.land_style == "mage" or (g.land_style == "" and held.get("hoger", false))
		rot = PI / 2 if belly else -PI / 2
	if g.pose == "krasch":
		rot = 1.3
	var face := "oo" if g.phase == "luft" and g.hojd >= 3 else ("aj" if g.phase == "krasch" else "glad")
	var spot := feet
	if g.pose == "ligg" or g.pose == "krasch":
		spot += Vector2(0, 6)
	Art.kid(self, Vector2(ox, 0), k, spot, g.pose, rot, sx, sky.wind, clampf(-g.vy / 200.0, -1.0, 1.0), t, face)
	if g.phase == "krasch":
		for i in 3:
			var a := t * 5.0 + i * TAU / 3
			draw_rect(Rect2(spot + Vector2(cos(a) * 9 - 1, -22 + sin(a) * 3), Vector2(2, 2)), GOLD)


func _draw_card(at: Vector2, n: int) -> void:
	var r := Rect2(at + Vector2(-9, -8), Vector2(18, 14))
	draw_rect(r.grow(1), Art.INK)
	draw_rect(r, Color.WHITE)
	text(str(n), r.get_center() + Vector2(0, -3), Color("#d02a2a") if n >= 7 else Color("#141018"), 1, 1, false)


func _draw_hud() -> void:
	var g = game
	panel(Rect2(2, 2, 74, 22))
	text("TID %d" % ceili(g.time_left), Vector2(6, 5), Color.WHITE if g.time_left > 10 else Color("#ff6a5a"))
	text("POÄNG %d" % g.total, Vector2(6, 14), GOLD)
	panel(Rect2(244, 2, 74, 22))
	text("NIVÅ %d" % level, Vector2(248, 5))
	var lo: int = Data.NIVA_XP[level - 1]
	var hi: int = Data.NIVA_XP[mini(level, Data.NIVA_XP.size() - 1)]
	var frac := 1.0 if level >= Data.NIVA_XP.size() else clampf(float(xp - lo) / (hi - lo), 0, 1)
	draw_rect(Rect2(248, 15, 66, 5), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(248, 15, 66 * frac, 5), Color("#5ad86a"))
	# hur mycket föräldern tittar
	var parent_name: String = Data.PARENTS[par].namn
	text(parent_name, Vector2(268, 156), Color.WHITE, 1, 1)
	for i in 5:
		var on: bool = g.attention > i * 0.2 + 0.05
		text("~", Vector2(254 + i * 6, 166), Color("#ff4a6a") if on else Color(1, 1, 1, 0.25), 1, 0, false)
	if g.phase == "sta":
		var hint: String = Data.KIDS[kid].halsning
		var r := Rect2(118, 70, hint.length() * 6 + 8, 13)
		Art.bubble(self, r, Vector2(150, 104))
		text(hint, r.position + Vector2(4, 3), Art.INK, 1, 0, false)
		text("TRYCK STUDS I TAKT MED HOPPEN!", Vector2(160, 30), GOLD, 1, 1)
		text("RIKTNING + TRICK I LUFTEN", Vector2(160, 40), Color.WHITE, 1, 1)
	if g.line_t > 0.0 and g.line != "":
		var w: int = g.line.length() * 6 + 8
		var r2 := Rect2(clampf(246 - w, 4 - ox, 300), 60, w, 13)
		Art.bubble(self, r2, Vector2(258, 96))
		text(g.line, r2.position + Vector2(4, 3), Art.INK, 1, 0, false)
	if g.perfect_t > 0.0:
		text("PERFEKT!", Vector2(Game.CX, Game.MAT_Y + 14), Color("#7aff8a"), 1, 1)
	for p in g.popups:
		var a := clampf(1.4 - p.t, 0, 1)
		var y: float = Game.MAT_Y - g.y - 44 - p.t * 14 - p.n % 3 * 9
		text(p.text, Vector2(Game.CX, y), Color(p.col, a), 1, 1)
	if g.time_left <= 0.0 and g.phase != "slut":
		text("TIDEN ÄR UTE!", Vector2(160, 50), GOLD, 2, 1)


func _draw_title() -> void:
	var title := "IMPONERANDE!"
	var x0 := 160.0 - title.length() * 9.0
	for i in title.length():
		var wob := sin(t * 4.0 + i * 0.6) * 2.0
		text(title[i], Vector2(x0 + i * 18 + 1, 14 + wob + 2), Art.INK, 3, 0, false)
		text(title[i], Vector2(x0 + i * 18, 14 + wob), GOLD.lerp(Color("#ff8a3a"), (sin(t * 3 + i) + 1) * 0.25), 3, 0, false)
	text("ETT STUDSANDE TRAMPOLINSPEL", Vector2(160, 42), Color.WHITE, 1, 1)
	var items := ["SPELA", "TRICKBOK", "LJUD: " + ("AV" if muted else "PÅ")]
	for i in 3:
		var r := title_item(i)
		panel(r, sel == i)
		text(items[i], r.get_center() + Vector2(0, -3), GOLD if sel == i else Color.WHITE, 1, 1)
	panel(Rect2(4, 160, 92, 16))
	text("NIVÅ %d  XP %d" % [level, xp], Vector2(8, 165), Color.WHITE)


func title_item(i: int) -> Rect2:
	return Rect2(196, 62 + i * 20, 84, 16)


func kid_x(i: int) -> float:
	return 40.0 + i * 60.0


func parent_btn(i: int) -> Rect2:
	return Rect2(96 + i * 68, 112, 60, 16)


func start_btn() -> Rect2:
	return Rect2(120, 140, 80, 18)


func _draw_choose() -> void:
	draw_rect(Rect2(-ox, 0, get_viewport_rect().size.x, H), Color(0, 0, 0, 0.45))
	text("TILLBAKA", Vector2(6, 4), Color(1, 1, 1, 0.7))
	text("VÄLJ BARN", Vector2(160, 30), GOLD if sel == 0 else Color.WHITE, 1, 1)
	for i in 5:
		var k: Dictionary = Data.KIDS[i]
		var on := i == kid
		var bob := absf(sin(t * 6.0)) * 6.0 if on else 0.0
		if on:
			panel(Rect2(kid_x(i) - 24, 42, 48, 56), sel == 0)
		Art.kid(self, Vector2(ox, 0), k, Vector2(kid_x(i), 86 - bob), "upp" if on and bob > 1 else "sta", 0.0, 1.0, sky.wind, 0.0, t, "glad" if on else "rak")
		text(k.namn, Vector2(kid_x(i), 90), GOLD if on else Color.WHITE, 1, 1)
	text("VEM TITTAR?", Vector2(160, 102), GOLD if sel == 1 else Color.WHITE, 1, 1)
	for i in 2:
		var r := parent_btn(i)
		panel(r, i == par)
		text(Data.PARENTS[i].namn, r.get_center() + Vector2(0, -3), GOLD if i == par else Color.WHITE, 1, 1)
	var sr := start_btn()
	draw_rect(sr.grow(1), Art.INK)
	draw_rect(sr, Color("#3fae4a") if sel == 2 else Color("#2a6a30"))
	text("STARTA!", sr.get_center() + Vector2(0, -3), Color.WHITE, 1, 1)
	text("NIVÅ %d: %d TRICK UPPLÅSTA" % [level, Data.BOK.filter(func(id): return Data.TRICKS[id].niva <= level).size()],
		Vector2(160, 166), Color(1, 1, 1, 0.8), 1, 1)


func _draw_result() -> void:
	draw_rect(Rect2(-ox, 0, get_viewport_rect().size.x, H), Color(0, 0, 0, 0.5))
	panel(Rect2(40, 14, 240, 150))
	text("RUNDAN ÄR SLUT!", Vector2(160, 22), GOLD, 2, 1)
	text(Data.PARENTS[par].namn + " SÄGER:", Vector2(160, 44), Color.WHITE, 1, 1)
	text(result.verdict, Vector2(160, 56), Color("#7aff8a"), 1, 1)
	text("POÄNG: %d" % result.total, Vector2(60, 74))
	text("SNITT PÅ LAPPARNA: %.1f" % result.avg, Vector2(60, 84))
	text("BÄSTA HOPP: %d" % result.best, Vector2(60, 94))
	text("XP: +%d  (NIVÅ %d)" % [result.total, level], Vector2(60, 104), GOLD)
	var y := 118.0
	if result.levelup:
		text("NY NIVÅ!", Vector2(160, y), Color("#ff8a3a"), 1, 1)
		y += 10
	for n in result.news:
		text("NYTT TRICK: " + n, Vector2(160, y), Color("#a8e8ff"), 1, 1)
		y += 9
	text("TRYCK STUDS", Vector2(160, 154), Color(1, 1, 1, 0.5 + 0.5 * sin(t * 5)), 1, 1)


func _draw_book() -> void:
	draw_rect(Rect2(-ox, 0, get_viewport_rect().size.x, H), Color(0, 0, 0, 0.6))
	panel(Rect2(2, 2, 316, 176))
	text("TRICKBOK", Vector2(160, 6), GOLD, 1, 1)
	for i in Data.BOK.size():
		var id: String = Data.BOK[i]
		var tr: Dictionary = Data.TRICKS[id]
		var y := 17.0 + i * 9.6
		var open: bool = tr.niva <= level
		var c := Color.WHITE if open else Color(1, 1, 1, 0.4)
		text(tr.namn if open else "???", Vector2(6, y), GOLD if open else c)
		text(tr.kombo if open else "LÅSES UPP PÅ NIVÅ %d" % tr.niva, Vector2(104, y), c)
		text(str(tr.poang), Vector2(314, y), c, 1, 2)


func _draw_touch() -> void:
	var vw := get_viewport_rect().size.x
	if state != "spel":
		return
	var pc := pad_center()
	draw_circle(pc, 26, Color(1, 1, 1, 0.12))
	draw_arc(pc, 26, 0, TAU, 32, Color(1, 1, 1, 0.4), 1)
	var arrows := {"upp": [Vector2.UP, "^"], "ned": [Vector2.DOWN, "_"], "vanster": [Vector2.LEFT, "{"], "hoger": [Vector2.RIGHT, "}"]}
	for k in arrows:
		var d: Vector2 = arrows[k][0]
		text(arrows[k][1], pc + d * 16 + Vector2(0, -4), GOLD if held.get(k) else Color(1, 1, 1, 0.7), 1, 1, false)
	var bs := btn_studs()
	draw_circle(bs, 18, Color(0.9, 0.3, 0.2, 0.7 if held.get("studs") else 0.45))
	draw_arc(bs, 18, 0, TAU, 32, Color(1, 1, 1, 0.5), 1)
	text("STUDS", bs + Vector2(0, -4), Color.WHITE, 1, 1, false)
	var bt := btn_trick()
	draw_circle(bt, 14, Color(0.2, 0.5, 0.95, 0.7 if held.get("trick") else 0.45))
	draw_arc(bt, 14, 0, TAU, 32, Color(1, 1, 1, 0.5), 1)
	text("TRICK", bt + Vector2(0, -4), Color.WHITE, 1, 1, false)
	var pr := btn_paus()
	draw_rect(pr, Color(0, 0, 0, 0.4))
	text("PAUS", pr.get_center() + Vector2(0, -4), Color.WHITE, 1, 1, false)


# ---------------------------------------------------------------- text och paneler
## Pixeltext. align: 0 vänster, 1 mitten, 2 höger. Gemener blir versaler.
func text(s: String, pos: Vector2, col := Color.WHITE, scale := 1, align := 0, shadow := true) -> void:
	s = s.to_upper()
	var w := s.length() * 6 * scale
	var x: float = pos.x - (w / 2.0 if align == 1 else (w if align == 2 else 0.0))
	x = floorf(x)
	if shadow:
		_glyphs(s, Vector2(x + scale, floorf(pos.y) + scale), Color(0, 0, 0, col.a * 0.8), scale)
	_glyphs(s, Vector2(x, floorf(pos.y)), col, scale)


func _glyphs(s: String, at: Vector2, col: Color, scale: int) -> void:
	for i in s.length():
		var g := font_order.find(s[i])
		if g < 0 or s[i] == " ":
			continue
		draw_texture_rect_region(font, Rect2(at + Vector2(i * 6 * scale, 0), Vector2(6, 8) * scale), Rect2(g * 6, 0, 6, 8), col)


func panel(r: Rect2, on := false) -> void:
	draw_rect(r.grow(1), Art.INK)
	draw_rect(r, PANEL if not on else Color(0.22, 0.16, 0.06, 0.92))
	draw_rect(r, GOLD if on else Color(1, 1, 1, 0.25), false, 1.0)
