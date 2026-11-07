extends Node2D
## Imponerande! – ett trampolinspel. Det här skriptet sköter skärmarna (titel, val, spel, resultat,
## trickbok), inmatningen (tangentbord, handkontroll och pekskärm), ljudet och sparningen, och
## ritar allt. Själva studsandet finns i game.gd, himlen i sky.gd och figurerna i art.gd.

const Data := preload("res://data.gd")
const Art := preload("res://art.gd")
const Game := preload("res://game.gd")
const SkyScript := preload("res://sky.gd")
const Rival := preload("res://rival.gd")

const W := 320.0
const H := 180.0
## Bakgrunden ritas i dubbla spelkoordinater (640 x 360) så att den blir pixlig med halvstora
## pixlar. Figurerna och texten ritas direkt i skärmens upplösning och blir släta.
const PX := 2.0
const SAVE := "user://save.cfg"
const RIVAL_X := 232.0          # grannens trampolin i duellen
const BROR_SIZE := 1.35
const BROR_AT := Vector2(298, 158)   # storebror står på Lisas tomt, bredvid hennes studsmatta
const GOLD := Color("#ffe14d")
const PANEL := Color(0.06, 0.05, 0.12, 0.86)

var font: Texture2D = preload("res://assets/font.png")
var font_order := ""

var state := "titel"            # titel | val | spel | paus | resultat | trickbok
var sel := 0                    # markerad rad i menyer
var kid := 0
var par := 0
var stjarnor := 0               # föräldrarnas betyg ihop; låser upp nivåer
var level := 1
var duell_vinster := 0
var duell_forluster := 0
var film_sett := false
var duel := false               # spelar vi duell mot grannen?
var rival                       # grannen i duellen
var duel_end_t := -1.0
var film_t := 0.0
var film_i := -1
var result_t := 0.0
var traffic: Array = []         # bilar och lastbilar på vägen bakom duellen
var traffic_t := 0.0
var final := [0, 0]             # duellens slutpoäng: [spelaren, grannen]
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

# bakgrunden och vädret ritas i låg upplösning i egna lager
var bg_layer: SubViewport
var fg_layer: SubViewport


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
	scale = Vector2(PX, PX)
	bg_layer = _make_layer(false, _draw_bg)
	fg_layer = _make_layer(true, _draw_fg)


## Ett lager i låg upplösning: en SubViewport med en nod som ritas av `painter`.
func _make_layer(transparent: bool, painter: Callable) -> SubViewport:
	var vp := SubViewport.new()
	vp.transparent_bg = transparent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.size = Vector2i(640, 360)
	add_child(vp)
	var n := Node2D.new()
	n.scale = Vector2(PX, PX)
	n.draw.connect(painter.bind(n))
	vp.add_child(n)
	return vp


# ================================================================ sparning
func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		if cf.has_section_key("spel", "stjarnor"):
			stjarnor = cf.get_value("spel", "stjarnor", 0)
		else:
			# gamla sparfiler hade XP: börja med stjärnorna för samma nivå
			var old: int = cf.get_value("spel", "xp", 0)
			var l := 1
			for i in Data.NIVA_XP.size():
				if old >= Data.NIVA_XP[i]:
					l = i + 1
			stjarnor = Data.NIVA_STJARNOR[l - 1]
		kid = clampi(cf.get_value("spel", "barn", 0), 0, 4)
		par = clampi(cf.get_value("spel", "foralder", 0), 0, 1)
		muted = cf.get_value("spel", "tyst", false)
		duell_vinster = cf.get_value("duell", "vinster", 0)
		duell_forluster = cf.get_value("duell", "forluster", 0)
		film_sett = cf.get_value("duell", "film_sett", false)
	level = level_for(stjarnor)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("spel", "stjarnor", stjarnor)
	cf.set_value("spel", "barn", kid)
	cf.set_value("spel", "foralder", par)
	cf.set_value("spel", "tyst", muted)
	cf.set_value("duell", "vinster", duell_vinster)
	cf.set_value("duell", "forluster", duell_forluster)
	cf.set_value("duell", "film_sett", film_sett)
	cf.save(SAVE)


func level_for(s: int) -> int:
	var l := 1
	for i in Data.NIVA_STJARNOR.size():
		if s >= Data.NIVA_STJARNOR[i]:
			l = i + 1
	return l


## Alla trick upplåsta: då finns duellen.
func all_tricks() -> bool:
	return level >= Data.NIVA_STJARNOR.size()


## Var spelarens trampolin står (i duellen står två bredvid varandra).
func kid_cx() -> float:
	return 88.0 if duel else Game.CX


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
	for n in ["studs", "rumpa", "trick", "land", "krasch", "applad", "oj", "aska", "regn", "vind", "niva", "meny", "valj", "lapp", "ett_trick", "musik_meny", "musik_spel"]:
		var s: AudioStreamWAV = load("res://assets/sfx/%s.wav" % n)
		if n in ["regn", "vind", "musik_meny", "musik_spel"]:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		sounds[n] = s
	# egen menymusik: lägg en MP3 som menymusik.mp3 i spelets användarmapp
	if FileAccess.file_exists("user://menymusik.mp3"):
		var own := AudioStreamMP3.load_from_file("user://menymusik.mp3")
		if own:
			own.loop = true
			sounds["musik_meny"] = own
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
			_touch_down(event.index, event.position / PX)
		else:
			fingers.erase(event.index)
	elif event is InputEventScreenDrag and fingers.has(event.index) and fingers[event.index].has("pad"):
		fingers[event.index] = _pad_dirs(event.position / PX)


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
## Skärmens storlek i spelets koordinater.
func vsize() -> Vector2:
	return get_viewport_rect().size / PX


func pad_center() -> Vector2:
	return Vector2(maxf(30.0, ox * 0.5 + 6.0), 142)


## STUDS och TRICK i en kolumn längst till höger, så att de inte täcker föräldern.
func btn_studs() -> Vector2:
	return Vector2(vsize().x - maxf(22.0, ox * 0.5 + 4.0), 152)


func btn_trick() -> Vector2:
	return btn_studs() + Vector2(0 if ox < 50 else -30, -36 if ox < 50 else -20)


func btn_paus() -> Rect2:
	return Rect2(vsize().x / 2 - 15, 3, 30, 12)


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
			for i in menu_ids().size():
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
		"resultat", "trickbok", "film":
			tap_pulse["studs"] = true


# ================================================================ huvudloopen
func _physics_process(dt: float) -> void:
	t += dt
	ox = (vsize().x - W) / 2.0
	_read_input()
	var time_speed := 0.35 if state != "spel" and state != "film" else 0.05
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
		"film": _film(dt)
		"resultat":
			result_t += dt
			if result_t < 0.8:
				pass            # så att ett STUDS-tryck från spelet inte hoppar förbi resultatet
			elif result.get("duel"):
				if pressed.get("studs"):
					_start_duel()
				elif pressed.get("trick") or pressed.get("paus"):
					_to_title()
			elif pressed.get("studs") or pressed.get("paus"):
				if result.get("unlock"):
					_start_film()
				else:
					_to_title()
		"trickbok":
			if pressed.get("studs") or pressed.get("paus") or pressed.get("trick"):
				state = "titel"
				play("meny")
	var size := Vector2i((vsize() * PX).round())
	for vp in [bg_layer, fg_layer]:
		if vp.size != size:
			vp.size = size
		vp.get_child(0).queue_redraw()
	queue_redraw()


func _to_title() -> void:
	state = "titel"
	duel = false
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
	var ids := menu_ids()
	sel = mini(sel, ids.size() - 1)
	if pressed.get("upp"):
		sel = posmod(sel - 1, ids.size())
		play("meny")
	if pressed.get("ned"):
		sel = posmod(sel + 1, ids.size())
		play("meny")
	if pressed.get("studs"):
		play("valj")
		match ids[sel]:
			"spela":
				state = "val"
				sel = 0
			"duell":
				if film_sett:
					_start_duel()
				else:
					_start_film()
			"bok":
				state = "trickbok"
			"ljud":
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


## Titelmenyns rader. DUELL finns när alla trick är upplåsta.
func menu_ids() -> Array:
	var ids := ["spela"]
	if all_tricks():
		ids.append("duell")
	ids.append_array(["bok", "ljud"])
	return ids


func _start_game() -> void:
	duel = false
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
	if duel:
		_update_traffic(dt)
		rival.update(dt)
		for s in rival.sounds:
			play(s)
		rival.sounds.clear()
		if duel_end_t < 0.0 and (game.poang >= Data.DUELL_MAL or rival.score >= Data.DUELL_MAL):
			duel_end_t = 1.6
			final = [game.poang, rival.score]        # poängen fryses när någon nått målet
		elif duel_end_t >= 0.0:
			duel_end_t -= dt
			if duel_end_t < 0.0:
				_finish_duel()
		return
	if game.phase == "slut":
		_finish()


func _finish() -> void:
	var before := level
	# föräldern sätter betyg på rundan: snittet av de åtta bästa lapparna, 0..10 stjärnor
	var best: Array = game.cards.duplicate()
	best.sort()
	best.reverse()
	var sum := 0
	for i in mini(8, best.size()):
		sum += best[i]
	var betyg := int(round(sum / 8.0))
	stjarnor += betyg
	level = level_for(stjarnor)
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
		"news": news, "levelup": level > before, "betyg": betyg,
		"unlock": all_tricks() and before < Data.NIVA_STJARNOR.size()}
	if level > before:
		play("niva")
	else:
		play("applad")
	_save()
	result_t = 0.0
	state = "resultat"


# ================================================================ duellen
## Filmen: grannen blir sur över allt beröm och utmanar till duell.
func _start_film() -> void:
	state = "film"
	film_t = 0.0
	film_i = -1
	duel = false
	sky.setup(17.0, "sol")
	play("applad")


func _film(dt: float) -> void:
	film_t += dt
	# barnet studsar tills grannen kommer
	if demo_y > 0.0 or film_t < 5.6:
		demo_v -= Game.G * dt
		demo_y += demo_v * dt
		if demo_y <= 0.0:
			demo_y = 0.0
			demo_v = sqrt(2.0 * Game.G * randf_range(40, 70)) if film_t < 5.6 else 0.0
			demo_pose = ["upp", "stjarna", "boll"].pick_random()
	if pressed.get("studs"):
		for l in Data.FILM:
			if l[0] > film_t:
				film_t = l[0]
				break
	var i := 0
	for k in Data.FILM.size():
		if film_t >= Data.FILM[k][0]:
			i = k
	if i != film_i:
		film_i = i
		var who: String = Data.FILM[i][1]
		if Data.FILM[i][2] == "FNYS!":
			play("lapp")
		elif who != "":
			play("meny")
	if pressed.get("trick") or pressed.get("paus") or film_t >= Data.FILM[-1][0]:
		film_sett = true
		_start_duel()


func _start_duel() -> void:
	play("valj")
	duel = true
	sky.setup(randf_range(8.0, 19.0), ["sol", "sol", "moln", "regn", "storm"].pick_random())
	game = Game.new()
	game.duel = true
	game.start(kid, par, level, sky.weather)
	game._say("")
	rival = Rival.new()
	traffic.clear()
	for i in 4:
		traffic_t = 0.0
		_update_traffic(0.0)
		traffic[-1].x = randf_range(0, W)
	rival.skill = mini(duell_vinster, 4) * 0.5
	duel_end_t = -1.0
	_save()
	state = "spel"
	_play_music("musik_spel")


## Trafiken på vägen: mest bilar, ibland en lastbil, åt båda hållen.
func _update_traffic(dt: float) -> void:
	traffic_t -= dt
	if traffic_t <= 0.0:
		traffic_t = randf_range(0.8, 3.0)
		var dir := 1.0 if randf() < 0.5 else -1.0
		var truck := randf() < 0.2
		var cols := [Color("#d84a3a"), Color("#3a6ad8"), Color("#f2f2f2"), Color("#2a2a30"), Color("#e8c43a"), Color("#4aa86a"), Color("#9aa0a8")]
		traffic.append({"x": -ox - 30.0 if dir > 0 else W + ox + 30.0, "dir": dir, "typ": "lastbil" if truck else "bil",
			"col": Color("#f0f0f0") if truck and randf() < 0.5 else cols.pick_random(),
			"speed": randf_range(20, 28) if truck else randf_range(30, 46)})
	for v in traffic:
		v.x += v.dir * v.speed * dt
	# en bil ska inte köra igenom bilen framför i samma fil
	for v in traffic:
		for w in traffic:
			var gap: float = (w.x - v.x) * v.dir
			if w != v and w.dir == v.dir and gap > 0.0 and gap < 26.0:
				v.x = w.x - v.dir * 26.0
				v.speed = minf(v.speed, w.speed)
	traffic = traffic.filter(func(v): return v.x > -ox - 60.0 and v.x < W + ox + 60.0)


func _finish_duel() -> void:
	var won: bool = final[0] >= final[1]
	if won:
		duell_vinster += 1
	else:
		duell_forluster += 1
	result = {"duel": true, "won": won, "me": final[0], "her": final[1]}
	play("niva" if won else "oj")
	_save()
	result_t = 0.0
	state = "resultat"


# ================================================================ ritning
func _draw() -> void:
	var vw := vsize().x
	var whole := Rect2(Vector2.ZERO, vsize())
	draw_texture_rect(bg_layer.get_texture(), whole, false)
	draw_set_transform(Vector2(ox, 0))
	_figures()
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(fg_layer.get_texture(), whole, false)
	draw_set_transform(Vector2(ox, 0))
	_shade()
	match state:
		"titel": _draw_title()
		"val": _draw_choose()
		"spel", "paus": _draw_hud()
		"film": _draw_film()
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


func _playing() -> bool:
	return state in ["spel", "paus", "resultat"] and game != null


## Barnets höjd över duken och hur mycket duken trycks ned: [ky, dip].
func _bounce() -> Array:
	if _playing():
		return [game.y, game.dip]
	if state == "titel" or state == "film":
		return [demo_y, maxf(0.0, 6.0 - demo_y) if demo_y < 6.0 else 0.0]
	return [0.0, 0.0]


## Pixliga bakgrunden: himlen, trädgården och trampolinerna.
func _draw_bg(c: Node2D) -> void:
	c.draw_set_transform(Vector2(ox, 0))
	c.draw_rect(Rect2(-ox, 0, vsize().x, H), Color("#1a1a2a"))
	sky.draw_back(c)
	if _playing() and duel:
		Art.duel_back(c, sky.wind, t, sky.night(), traffic)
	else:
		Art.garden_back(c, sky.wind, t, sky.night())
	Art.ground(c)
	var dip: float = _bounce()[1]
	Art.trampoline(c, kid_cx(), Game.MAT_Y, dip, 0.0)
	if _playing() and duel:
		Art.trampoline(c, RIVAL_X, Game.MAT_Y, rival.dip, 0.0, Color("#ff6ab4"))
		Art.side_fence(c, 160)


## Pixligt väder framför figurerna: regn, snö och blixtar.
func _draw_fg(c: Node2D) -> void:
	c.draw_set_transform(Vector2(ox, 0))
	sky.draw_front(c)


## Kvällsmörker och molnighet över allt, och lampor i fönstren.
func _shade() -> void:
	var nt: float = sky.night()
	var dark := clampf(nt * 0.42 + sky.gloom() * 0.15, 0.0, 0.55)
	if dark > 0.0:
		draw_rect(Rect2(-ox, 0, vsize().x, H), Color(0.04, 0.04, 0.16, dark))
	if not (_playing() and duel):
		Art.lights(self, nt)


## Figurerna i full upplösning: föräldern, barnet, grannen och storebror.
func _figures() -> void:
	var playing := _playing()
	var k: Dictionary = Data.KIDS[kid]
	var b := _bounce()
	var feet := Vector2(kid_cx(), Game.MAT_Y - b[0] + b[1])
	if playing and not duel:
		var pstate: String = game.react
		var card_at: Vector2 = Art.parent(self, Vector2(ox, 0), Data.PARENTS[par], Vector2(268, 150), pstate, feet + Vector2(0, -20), t, sky.wind)
		_draw_kid_in_game(k, feet)
		if game.card_t > 0.0 and card_at != Vector2.ZERO:
			_draw_card(card_at, game.card)
	elif playing:
		_duel_scene()
		_draw_kid_in_game(k, feet)
	elif state == "titel":
		var face := "oo" if demo_v < 0 else "glad"
		Art.kid(self, Vector2(ox, 0), k, feet, demo_pose if demo_y > 4 else "huka", 0.0, 1.0, sky.wind, -demo_v / 300.0, t, face)
	elif state == "film":
		_film_scene(k, feet)


## Storebror som dömer och grannen som studsar (trampolinerna och staketet finns i bakgrunden).
func _duel_scene() -> void:
	var bpose := "armkors"
	if game.card_t > 0.0 and rival.card_t > 0.0:
		bpose = "kortB"
	elif game.card_t > 0.0:
		bpose = "kortV"
	elif rival.card_t > 0.0:
		bpose = "kortH"
	var face := "glad" if game.card_t > 0.0 and game.card >= 9 else "rak"
	Art.kid(self, Vector2(ox, 0), Data.BROR, BROR_AT, bpose, 0.0, 1.0, sky.wind, 0.0, t, face, BROR_SIZE)
	if game.card_t > 0.0:
		_draw_card(BROR_AT + Vector2(-12, -37) * BROR_SIZE, game.card)
	if rival.card_t > 0.0:
		_draw_card(BROR_AT + Vector2(12, -37) * BROR_SIZE, rival.card)
	var rface := "oo" if rival.phase == "luft" and rival.hojd >= 3 else "flin"
	Art.kid(self, Vector2(ox, 0), Data.GRANNE, Vector2(RIVAL_X, Game.MAT_Y - rival.y + rival.dip), rival.pose, rival.rot, rival.sx,
		sky.wind, clampf(-rival.vy / 200.0, -1.0, 1.0), t, rface)


## Filmen: barnet studsar, föräldern jublar, grannen kommer in och fnyser, sen storebror.
func _film_scene(k: Dictionary, feet: Vector2) -> void:
	var pstate := "klappar" if film_t < 4.4 else ("gapar" if film_t > 9.8 and film_t < 12.0 else "tittar")
	Art.parent(self, Vector2(ox, 0), Data.PARENTS[par], Vector2(268, 150), pstate, feet + Vector2(0, -20), t, sky.wind)
	var kface := "glad" if film_t < 8.4 else "oo"
	var kpose := "sta" if film_t >= 6.0 and demo_y <= 0.0 else (demo_pose if demo_y > 4 else "huka")
	Art.kid(self, Vector2(ox, 0), k, feet, kpose, 0.0, 1.0, sky.wind, -demo_v / 300.0 if demo_y > 0.0 else 0.0, t, kface)
	# grannen går in från vänster och ställer sig vid trampolinen
	if film_t >= 4.4:
		var gx := lerpf(-ox - 20.0, 92.0, clampf((film_t - 4.4) / 3.0, 0, 1))
		var walking := film_t < 7.4
		var gpose := ("ga1" if fmod(t, 0.3) < 0.15 else "ga2") if walking else ("armkors" if film_t < 8.4 or film_t > 12.8 else "sta")
		if film_t >= 12.8 and film_t < 15.6:
			gpose = "upp"           # pekar ut utmaningen
		var gface := "fnys" if film_t >= 8.4 and film_t < 9.8 else ("flin" if film_t >= 9.8 else "arg")
		var gfeet := Vector2(gx, 152 - (absf(sin(t * 10.0)) * 1.5 if walking else 0.0))
		Art.kid(self, Vector2(ox, 0), Data.GRANNE, gfeet, gpose, 0.0, 1.0, sky.wind, 0.0, t, gface)
		if gface == "fnys":
			# fnysningen: två små moln från näsan
			var puff := fmod(film_t - 8.4, 0.7) / 0.7
			for s in [-1.0, 1.0]:
				draw_circle(gfeet + Vector2(s * (3 + puff * 8), -23 + puff * 2), 1.5 + puff * 2, Color(1, 1, 1, 1.0 - puff))
	# storebror kommer släntrande
	if film_t >= 17.0:
		var bx := lerpf(-ox - 24.0, 52.0, clampf((film_t - 17.0) / 2.4, 0, 1))
		var bwalk := film_t < 19.4
		var bpose := ("ga1" if fmod(t, 0.4) < 0.2 else "ga2") if bwalk else "armkors"
		Art.kid(self, Vector2(ox, 0), Data.BROR, Vector2(bx, 154), bpose, 0.0, 1.0, sky.wind, 0.0, t, "rak", BROR_SIZE)


## Var en figurs mun ungefär sitter i filmen (för pratbubblans svans).
func _film_mouth(who: String) -> Vector2:
	match who:
		"foralder": return Vector2(266, 112)
		"granne": return Vector2(92, 132)
		"bror": return Vector2(52, 124)
	return Vector2(160, 120)


func _draw_film() -> void:
	draw_rect(Rect2(-ox, 0, vsize().x, 14), Color.BLACK)
	draw_rect(Rect2(-ox, H - 14, vsize().x, 14), Color.BLACK)
	var l: Array = Data.FILM[maxi(film_i, 0)]
	if l[2] != "":
		say_bubble(l[2], _film_mouth(l[1]))
	text("STUDS: NÄSTA   TRICK: HOPPA ÖVER", Vector2(160, H - 11), Color(1, 1, 1, 0.6), 1, 1, false)


## En pratbubbla ovanför en mun. "|" i texten ger en ny rad.
## top: bubblans överkant (annars precis ovanför munnen).
func say_bubble(s: String, mouth: Vector2, top := -1.0) -> void:
	var lines := s.split("|")
	var w := 0
	for l in lines:
		w = maxi(w, l.length() * 6 + 8)
	var h := lines.size() * 9 + 4
	var x := clampf(mouth.x - w + 18, 2 - ox, W + ox - w - 2)
	var r := Rect2(x, mouth.y - 20 - h if top < 0.0 else top, w, h)
	Art.bubble(self, r, mouth + Vector2(0, -4))
	for i in lines.size():
		text(lines[i], r.position + Vector2(4, 3 + i * 9), Art.INK, 1, 0, false)


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
	var cx := kid_cx()
	if duel:
		var over := duel_end_t >= 0.0
		_score_panel(Rect2(2, 2, 116, 22), Data.KIDS[kid].namn, final[0] if over else g.poang, Color("#5ad86a"))
		_score_panel(Rect2(202, 2, 116, 22), Data.GRANNE.namn, final[1] if over else rival.score, Color("#ff6ab4"))
		if g.line_t > 0.0 and g.line != "":
			say_bubble(g.line, BROR_AT + Vector2(0, -30 * BROR_SIZE), 48)
		if rival.line_t > 0.0:
			say_bubble(rival.line, Vector2(RIVAL_X + 20, Game.MAT_Y - rival.y - 22))
		for p in rival.popups:
			var a := clampf(1.4 - p.t, 0, 1)
			text(p.text, Vector2(RIVAL_X, Game.MAT_Y - rival.y - 44 - p.t * 14 - p.n % 3 * 9), Color(p.col, a), 1, 1)
		if duel_end_t >= 0.0:
			var won: bool = final[0] >= final[1]
			text("DU VANN!" if won else Data.GRANNE.namn + " VANN!", Vector2(160, 30), GOLD if won else Color("#ff6ab4"), 2, 1)
	else:
		panel(Rect2(2, 2, 74, 22))
		text("TID %d" % ceili(g.time_left), Vector2(6, 5), Color.WHITE if g.time_left > 10 else Color("#ff6a5a"))
		text("POÄNG %d" % g.total, Vector2(6, 14), GOLD)
		panel(Rect2(244, 2, 74, 22))
		text("NIVÅ %d" % level, Vector2(248, 5))
		var lo: int = Data.NIVA_STJARNOR[level - 1]
		var hi: int = Data.NIVA_STJARNOR[mini(level, Data.NIVA_STJARNOR.size() - 1)]
		var frac := 1.0 if all_tricks() else clampf(float(stjarnor - lo) / (hi - lo), 0, 1)
		draw_rect(Rect2(248, 15, 66, 5), Color(1, 1, 1, 0.2))
		draw_rect(Rect2(248, 15, 66 * frac, 5), GOLD)
		# hur mycket föräldern tittar
		var parent_name: String = Data.PARENTS[par].namn
		text(parent_name, Vector2(268, 156), Color.WHITE, 1, 1)
		for i in 5:
			var on: bool = g.attention > i * 0.2 + 0.05
			text("~", Vector2(254 + i * 6, 166), Color("#ff4a6a") if on else Color(1, 1, 1, 0.25), 1, 0, false)
		if g.line_t > 0.0 and g.line != "":
			var w: int = g.line.length() * 6 + 8
			var r2 := Rect2(clampf(246 - w, 4 - ox, 300), 60, w, 13)
			Art.bubble(self, r2, Vector2(258, 96))
			text(g.line, r2.position + Vector2(4, 3), Art.INK, 1, 0, false)
	if g.phase == "sta":
		var hint: String = Data.KIDS[kid].halsning
		var r := Rect2(maxf(cx - 32, 2 - ox), 70, hint.length() * 6 + 8, 13)
		Art.bubble(self, r, Vector2(cx, 104))
		text(hint, r.position + Vector2(4, 3), Art.INK, 1, 0, false)
		if duel:
			text("FÖRST TILL %d POÄNG VINNER!" % Data.DUELL_MAL, Vector2(160, 30), GOLD, 1, 1)
		else:
			text("TRYCK STUDS I TAKT MED HOPPEN!", Vector2(160, 30), GOLD, 1, 1)
		text("RIKTNING + TRICK I LUFTEN", Vector2(160, 40), Color.WHITE, 1, 1)
	if g.kid_line_t > 0.0:
		var kw: int = g.kid_line.length() * 6 + 8
		var kr := Rect2(maxf(cx - 36 - kw, 2 - ox), 92, kw, 13)
		Art.bubble(self, kr, Vector2(cx - 8, 116))
		text(g.kid_line, kr.position + Vector2(4, 3), Art.INK, 1, 0, false)
	if g.perfect_t > 0.0:
		text("PERFEKT!", Vector2(cx, Game.MAT_Y + 14), Color("#7aff8a"), 1, 1)
	for p in g.popups:
		var a := clampf(1.4 - p.t, 0, 1)
		var y: float = Game.MAT_Y - g.y - 44 - p.t * 14 - p.n % 3 * 9
		text(p.text, Vector2(cx, y), Color(p.col, a), 1, 1)
	if g.time_left <= 0.0 and g.phase != "slut":
		text("TIDEN ÄR UTE!", Vector2(160, 50), GOLD, 2, 1)


## Poängen i duellen: namn, poäng av 50 och en stapel.
func _score_panel(r: Rect2, name: String, score: int, col: Color) -> void:
	panel(r)
	text("%s %d/%d" % [name, mini(score, Data.DUELL_MAL), Data.DUELL_MAL], r.position + Vector2(4, 3), Color.WHITE)
	draw_rect(Rect2(r.position + Vector2(4, 13), Vector2(r.size.x - 8, 5)), Color(1, 1, 1, 0.2))
	draw_rect(Rect2(r.position + Vector2(4, 13), Vector2((r.size.x - 8) * minf(1.0, float(score) / Data.DUELL_MAL), 5)), col)


func _draw_title() -> void:
	var title := "IMPONERANDE!"
	var x0 := 160.0 - title.length() * 9.0
	for i in title.length():
		var wob := sin(t * 4.0 + i * 0.6) * 2.0
		text(title[i], Vector2(x0 + i * 18 + 1, 14 + wob + 2), Art.INK, 3, 0, false)
		text(title[i], Vector2(x0 + i * 18, 14 + wob), GOLD.lerp(Color("#ff8a3a"), (sin(t * 3 + i) + 1) * 0.25), 3, 0, false)
	text("ETT STUDSANDE TRAMPOLINSPEL", Vector2(160, 42), Color.WHITE, 1, 1)
	var names := {"spela": "SPELA", "duell": "DUELL!", "bok": "TRICKBOK", "ljud": "LJUD: " + ("AV" if muted else "PÅ")}
	var ids := menu_ids()
	for i in ids.size():
		var r := title_item(i)
		panel(r, sel == i)
		var col := Color("#ff8ac8") if ids[i] == "duell" else Color.WHITE
		text(names[ids[i]], r.get_center() + Vector2(0, -3), GOLD if sel == i else col, 1, 1)
	panel(Rect2(4, 160, 92, 16))
	text("NIVÅ %d  * %d" % [level, stjarnor], Vector2(8, 165), Color.WHITE)


func title_item(i: int) -> Rect2:
	return Rect2(196, 58 + i * 19, 84, 16)


func kid_x(i: int) -> float:
	return 40.0 + i * 60.0


func parent_btn(i: int) -> Rect2:
	return Rect2(96 + i * 68, 112, 60, 16)


func start_btn() -> Rect2:
	return Rect2(120, 140, 80, 18)


func _draw_choose() -> void:
	draw_rect(Rect2(-ox, 0, vsize().x, H), Color(0, 0, 0, 0.45))
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
	draw_rect(Rect2(-ox, 0, vsize().x, H), Color(0, 0, 0, 0.5))
	panel(Rect2(40, 14, 240, 150))
	if result.get("duel"):
		_draw_duel_result()
		return
	text("RUNDAN ÄR SLUT!", Vector2(160, 22), GOLD, 2, 1)
	text(Data.PARENTS[par].namn + " SÄGER:", Vector2(160, 44), Color.WHITE, 1, 1)
	text(result.verdict, Vector2(160, 56), Color("#7aff8a"), 1, 1)
	text("POÄNG: %d" % result.total, Vector2(60, 74))
	text("SNITT PÅ LAPPARNA: %.1f" % result.avg, Vector2(60, 84))
	text("BÄSTA HOPP: %d" % result.best, Vector2(60, 94))
	text("BETYG %d/10: +%d *  (TOTALT %d)" % [result.betyg, result.betyg, stjarnor], Vector2(60, 104), GOLD)
	var y := 118.0
	if result.unlock:
		text("ALLA TRICK! NYTT LÄGE: DUELL!", Vector2(160, y), Color("#ff8ac8"), 1, 1)
		y += 10
	elif result.levelup:
		text("NY NIVÅ!", Vector2(160, y), Color("#ff8a3a"), 1, 1)
		y += 10
	elif not all_tricks():
		text("NÄSTA TRICK VID %d *" % Data.NIVA_STJARNOR[level], Vector2(160, y), Color(1, 1, 1, 0.7), 1, 1)
		y += 10
	for n in result.news:
		text("NYTT TRICK: " + n, Vector2(160, y), Color("#a8e8ff"), 1, 1)
		y += 9
	text("TRYCK STUDS", Vector2(160, 154), Color(1, 1, 1, 0.5 + 0.5 * sin(t * 5)), 1, 1)


func _draw_duel_result() -> void:
	var won: bool = result.won
	text("DU VANN!" if won else Data.GRANNE.namn + " VANN!", Vector2(160, 22), GOLD if won else Color("#ff6ab4"), 2, 1)
	text("STOREBROR SÄGER:", Vector2(160, 44), Color.WHITE, 1, 1)
	text("OKEJ, DU ÄR BÄST. DEN HÄR GÅNGEN." if won else "SORRY, MIN SYRRA ÄR BÄST.", Vector2(160, 56), Color("#7aff8a"), 1, 1)
	text("%s: %d POÄNG" % [Data.KIDS[kid].namn, result.me], Vector2(60, 76))
	text("%s: %d POÄNG" % [Data.GRANNE.namn, result.her], Vector2(60, 86))
	text("VINSTER %d  FÖRLUSTER %d" % [duell_vinster, duell_forluster], Vector2(60, 100), GOLD)
	text("LISA: " + ("NÄSTA GÅNG SÅ!" if won else "HAH! VAD VAR DET JAG SA?"), Vector2(160, 118), Color("#ff8ac8"), 1, 1)
	text("STUDS: REVANSCH   TRICK: MENYN", Vector2(160, 154), Color(1, 1, 1, 0.5 + 0.5 * sin(t * 5)), 1, 1)


func _draw_book() -> void:
	draw_rect(Rect2(-ox, 0, vsize().x, H), Color(0, 0, 0, 0.6))
	panel(Rect2(2, 2, 316, 176))
	text("TRICKBOK", Vector2(160, 6), GOLD, 1, 1)
	for i in Data.BOK.size():
		var id: String = Data.BOK[i]
		var tr: Dictionary = Data.TRICKS[id]
		var y := 17.0 + i * 9.6
		var open: bool = tr.niva <= level
		var c := Color.WHITE if open else Color(1, 1, 1, 0.4)
		text(tr.namn if open else "???", Vector2(6, y), GOLD if open else c)
		text(tr.kombo if open else "LÅSES UPP VID %d *" % Data.NIVA_STJARNOR[tr.niva - 1], Vector2(116, y), c)
		text(str(tr.poang), Vector2(314, y), c, 1, 2)


func _draw_touch() -> void:
	var vw := vsize().x
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
