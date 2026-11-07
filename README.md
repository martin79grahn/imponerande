# Imponerande!

Ett svenskt trampolinspel gjort i Godot 4.5. Du är ett barn som studsar på trampolinen i trädgården och gör trick för att imponera på mamma eller pappa. Föräldern sitter i trädgårdsstolen, tittar på och håller upp en poänglapp efter varje hopp. Men gör du samma trick för många gånger börjar de titta i mobilen i stället.

**Spela i webbläsaren:** <https://martin79grahn.github.io/imponerande/>, på datorn eller mobilen.
**Android:** ladda ner den senaste APK:n från [Releases](https://github.com/martin79grahn/imponerande/releases), öppna filen på telefonen och tillåt installation från den källan när Android frågar.

## Så spelar du

- Välj ett av fem barn, **Ella**, **Leo**, **Maja**, **Hugo** eller **Nora**, och vem som tittar: **mamma** eller **pappa**.
- Tryck **STUDS** precis när du landar i duken. Rätt takt ger högre hopp ("PERFEKT!"), fel takt gör hoppet lägre.
- Gör trick i luften med **riktning + TRICK**, och landa på olika sätt genom att hålla en riktning när du landar. Är du mitt i en volt när du landar kraschar du: "Aj! Försiktigt!".
- Varje runda är 60 sekunder. Föräldern ger 1–10 för varje trickhopp. Höjd, variation och trick som föräldern gillar ger mer: mamma gillar snygga trick, pappa vågade. Upprepar du samma trick blir föräldern uttråkad, utom med rumpstudsar, som bara blir roligare ju fler du gör i rad.
- Poängen blir erfarenhet (XP). Nya nivåer låser upp nya trick. Allt sparas till nästa gång.

### Trick

| Trick | Hur | Nivå |
| --- | --- | --- |
| Raka hoppet | studsa bara | 1 |
| Stjärnhopp | TRICK | 1 |
| Rumpstuds | håll ↓ när du landar (flera i rad ger en kedja). Barnet säger "Det är ETT trick!" varje gång | 1 |
| Knästuds | håll ← när du landar | 2 |
| Magstuds | håll → när du landar | 2 |
| Volt bakåt | ← + TRICK | 3 |
| Snurr 360 | ↑ + TRICK | 3 |
| Volt framåt | → + TRICK | 4 |
| Kanonkulan | ↓ + TRICK | 4 |
| Helikoptern 720 | snurra, sedan ↑ + TRICK igen | 5 |
| Dubbelvolt | volta, sedan samma volt igen | 6 |
| Supermanhoppet | → → + TRICK | 6 |
| Ryggstuds | håll ↑ när du landar | 7 |
| Rumpa-mage-rygg | rump-, mag- och ryggstuds i rad | 7 |
| Trippelvolt | volta tre gånger i samma hopp | 8 |
| Flygande pannkakan | ↓ ↑ + TRICK | 8 |

Flera olika trick i samma hopp ger kombobonus.

### Knappar

| | Tangentbord | Handkontroll | Pekskärm |
| --- | --- | --- | --- |
| Riktning | piltangenterna eller WASD | styrkorset eller spaken | styrkorset till vänster |
| Studs (och OK i menyer) | Mellanslag eller Enter | A | STUDS |
| Trick (och tillbaka i menyer) | X, Z eller Shift | B eller X | TRICK |
| Paus | Esc eller P | Start | PAUS |

M stänger av och på ljudet, F11 växlar helskärm och T visar knapparna för pekskärm på datorn. Menyerna går också att trycka eller klicka i.

## Grafik och ljud

- **Grafiken** är i pappersfigurstil, med platta färger, svarta konturer, stora runda huvuden och vantar, ritad i 320×180 pixlar så att den blir pixlig som ett gammalt 8-bitarsspel. Skärmen är 640×360, så runda former får lite finare pixlar medan text och detaljer behåller den grova stilen. Allt ritas i kod: barnen och föräldrarna (`art.gd`), en röd stuga med vita knutar, björk, staket, granar och en svensk flagga som fladdrar i vinden.
- **Bakgrunden lever** (`sky.gd`):
  - Dygnet går: soluppgång, dag, solnedgång och natt med stjärnor, måne och tända fönster.
  - Moln driver, fåglar flyger förbi i plogformation, och ibland syns ett flygplan.
  - Vädret är sol, molnigt, regn, snö eller storm, och det kan slå om mitt i en runda.
  - I storm blixtrar och åskar det och regnet faller snett. Barnens hår, flätor, hästsvansar och toppluvor fladdrar, och björken och flaggan slits i vinden.
- **Ljudet** är 8-bit och görs av `tools/make_sounds.py`: trampolinens "boing", rumpstuds, trick, krasch, applåder, åska, regn och vind, plus två musikslingor. I spelet går en egen låt i 80-talets new wave-stil. Barnets röst är talsyntes (espeak-ng) som krossats till 8-bit-ljud.
- **Typsnittet** är ett eget pixeltypsnitt med Å, Ä och Ö (`tools/make_font.py`).

## Filer

- `main.gd`: skärmarna (titel, val, spel, paus, resultat, trickbok), inmatning, ljud, sparning och ritning av menyerna.
- `game.gd`: studsen, tricken, landningarna, poängen och föräldern.
- `data.gd`: barnen, föräldrarna, tricken, replikerna och nivåerna.
- `art.gd`: barnen, föräldrarna, trampolinen och trädgården.
- `sky.gd`: himlen, dygnet, molnen, fåglarna och vädret.
- `tools/`: verktygen som gör typsnittet och ljuden (Python 3 med Pillow och NumPy).
- `docs/`: den färdiga webbversionen, som GitHub Pages visar.

## Bygga

Du behöver Godot 4.5.1 med exportmallarna.

```sh
python3 tools/make_font.py && python3 tools/make_sounds.py     # bara om typsnittet eller ljuden ändrats
godot --headless --import
godot --headless --export-release "Web" docs/index.html
```

För Android behövs Android SDK och Java, inställda i Godots editorinställningar, och en nyckel att signera med. Nyckeln ligger inte i repot:

```sh
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/.android/imponerande-release.keystore \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=imponerande \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... \
godot --headless --export-release "Android" export/Imponerande.apk
```
