extends RefCounted
## Spelets data: barnen, föräldrarna, tricken, replikerna och erfarenhetsnivåerna.

## De fem barnen. hair: frisyrens typ, col: jacka, byxor, hår, hy, extra (mössa/keps/glasögon).
const KIDS := [
	{"namn": "ELLA", "har": "flator", "jacka": Color("#e8423a"), "byxor": Color("#3a4fb8"), "harfarg": Color("#f2c84b"), "hy": Color("#f6d2b0"), "extra": Color("#ffffff"), "halsning": "TITTA PÅ MIG!"},
	{"namn": "LEO", "har": "keps", "jacka": Color("#2f7fe0"), "byxor": Color("#3b3b46"), "harfarg": Color("#6b3d1e"), "hy": Color("#e9b98f"), "extra": Color("#d8282e"), "halsning": "NU KÖR VI!"},
	{"namn": "MAJA", "har": "lockar", "jacka": Color("#3fae4a"), "byxor": Color("#6a3d8a"), "harfarg": Color("#7a4320"), "hy": Color("#c98e62"), "extra": Color("#1a1a1a"), "halsning": "JAG KAN FLYGA!"},
	{"namn": "HUGO", "har": "mossa", "jacka": Color("#f08a1c"), "byxor": Color("#2c5c3c"), "harfarg": Color("#d4a050"), "hy": Color("#f6d2b0"), "extra": Color("#2a6ad0"), "halsning": "KOLLA HÄR!"},
	{"namn": "NORA", "har": "svans", "jacka": Color("#8e44c8"), "byxor": Color("#22304a"), "harfarg": Color("#1c1414"), "hy": Color("#8a5a3c"), "extra": Color("#ff6aa8"), "halsning": "HÄR KOMMER JAG!"},
]

const PARENTS := [
	{"namn": "MAMMA", "har": Color("#8a4a24"), "trojan": Color("#c8304a"), "byxor": Color("#3a4a7a"), "hy": Color("#f2c8a4"), "gillar": ["stjarna", "volt_bak", "volt_fram", "snurr", "superman"]},
	{"namn": "PAPPA", "har": Color("#3a2a1e"), "trojan": Color("#2a7a5a"), "byxor": Color("#4a4a52"), "hy": Color("#e8b890"), "gillar": ["dubbelvolt", "trippelvolt", "helikopter", "kanonkula", "pannkaka"]},
]

## Tricken. niva: när det låses upp. kombo: hur man gör det (visas i trickboken).
## typ: "luft" (görs i luften, tar tid), "landning" (hur man landar), "kedja" (flera studsar i följd).
## tid: sekunder i luften; varv: hur många varv det roterar (volter och snurr).
const TRICKS := {
	"rakt": {"namn": "RAKA HOPPET", "niva": 1, "poang": 5, "typ": "luft", "kombo": "STUDSA BARA", "tid": 0.0},
	"stjarna": {"namn": "STJÄRNHOPP", "niva": 1, "poang": 30, "typ": "luft", "kombo": "TRICK", "tid": 0.45},
	"rumpa": {"namn": "RUMPSTUDS", "niva": 1, "poang": 20, "typ": "landning", "kombo": "HÅLL _ VID LANDNING"},
	"kna": {"namn": "KNÄSTUDS", "niva": 2, "poang": 25, "typ": "landning", "kombo": "HÅLL { VID LANDNING"},
	"mage": {"namn": "MAGSTUDS", "niva": 2, "poang": 35, "typ": "landning", "kombo": "HÅLL } VID LANDNING"},
	"volt_bak": {"namn": "VOLT BAKÅT", "niva": 3, "poang": 70, "typ": "luft", "kombo": "{ + TRICK", "tid": 0.62, "varv": 1},
	"snurr": {"namn": "SNURR 360", "niva": 3, "poang": 50, "typ": "luft", "kombo": "^ + TRICK", "tid": 0.5, "snurr": 1},
	"volt_fram": {"namn": "VOLT FRAMÅT", "niva": 4, "poang": 80, "typ": "luft", "kombo": "} + TRICK", "tid": 0.62, "varv": 1},
	"kanonkula": {"namn": "KANONKULAN", "niva": 4, "poang": 45, "typ": "luft", "kombo": "_ + TRICK", "tid": 0.5},
	"helikopter": {"namn": "HELIKOPTERN 720", "niva": 5, "poang": 120, "typ": "luft", "kombo": "SNURRA, SEN ^ + TRICK IGEN", "tid": 0.8, "snurr": 2},
	"dubbelvolt": {"namn": "DUBBELVOLT", "niva": 6, "poang": 180, "typ": "luft", "kombo": "VOLTA, SEN SAMMA VOLT IGEN", "tid": 1.0, "varv": 2},
	"superman": {"namn": "SUPERMANHOPPET", "niva": 6, "poang": 110, "typ": "luft", "kombo": "} } + TRICK", "tid": 0.6},
	"rygg": {"namn": "RYGGSTUDS", "niva": 7, "poang": 40, "typ": "landning", "kombo": "HÅLL ^ VID LANDNING"},
	"rmr": {"namn": "RUMPA-MAGE-RYGG", "niva": 7, "poang": 200, "typ": "kedja", "kombo": "RUMP-, MAG- OCH RYGGSTUDS I RAD"},
	"trippelvolt": {"namn": "TRIPPELVOLT", "niva": 8, "poang": 350, "typ": "luft", "kombo": "VOLTA TRE GÅNGER I SAMMA HOPP", "tid": 1.35, "varv": 3},
	"pannkaka": {"namn": "FLYGANDE PANNKAKAN", "niva": 8, "poang": 160, "typ": "luft", "kombo": "_ ^ + TRICK", "tid": 0.7},
}
## Ordningen i trickboken.
const BOK := ["rakt", "stjarna", "rumpa", "kna", "mage", "volt_bak", "snurr", "volt_fram", "kanonkula",
	"helikopter", "dubbelvolt", "superman", "rygg", "rmr", "trippelvolt", "pannkaka"]

## XP som krävs för varje nivå (nivå 1 från början).
const NIVA_XP := [0, 250, 700, 1400, 2400, 3800, 5600, 8000]

const REPLIKER := {
	"krasch": ["AJ! FÖRSIKTIGT!", "GICK DET BRA?!", "INTE PÅ HUVUDET!", "OJ OJ OJ, AJ!"],
	"lag": ["MJA...", "OKEJ...", "HOPPA LITE HÖGRE DÅ.", "HAR DU GJORT LÄXORNA?", "JAHA."],
	"mobil": ["MM, JÄTTEFINT.", "VAD SA DU, ÄLSKLING?", "JA JA, JAG TITTAR."],
	"mellan": ["SNYGGT!", "BRA JOBBAT!", "OJ, OJ!", "DUKTIGT!", "HÄFTIGT!"],
	"hog": ["WOW!", "VILKET HOPP!", "DET DÄR VAR HÄFTIGT!", "OJ OJ OJ!", "SÅ HÖGT!"],
	"tio": ["IMPONERANDE!", "VÄRLDSKLASS!", "JAG TAPPAR HAKAN!", "IMPONERANDE!!"],
	"rumpa": ["HAHA, RUMPAN!", "RUMPSTUDS IGEN?!", "VILKEN RUMPA!", "STUDSA PÅ RUMPAN!"],
	"MAMMA": ["SÅ GRACIÖST!", "AKTA SÅ DU INTE RAMLAR!", "MAMMA ÄR STOLT!"],
	"PAPPA": ["HÖGRE! HÖGRE!", "SÅ GJORDE JAG OCKSÅ!", "PAPPA ÄR STOLT!"],
	"storm": ["DET BÖRJAR BLÅSA!", "KOM IN SNART, DET ÅSKAR!", "HÅLL I MÖSSAN!"],
	"rutten": ["SAMMA IGEN?", "DET DÄR HAR JAG SETT.", "NÅGOT NYTT KANSKE?"],
}

## Omdöme efter en runda, efter snittet på poänglapparna.
const OMDOME := [[0.0, "FÖRÄLDERN SOMNADE..."], [3.0, "HELT OKEJ!"], [5.0, "RIKTIGT BRA STUDSAT!"],
	[7.0, "IMPONERANDE!"], [8.8, "VÄRLDENS BÄSTA STUDSARE!"]]

const VADER := ["sol", "moln", "regn", "sno", "storm"]
const VADER_NAMN := {"sol": "SOLIGT", "moln": "MOLNIGT", "regn": "REGN", "sno": "SNÖ", "storm": "STORM!"}
